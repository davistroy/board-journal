import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/bet_status.dart';
import 'base_repository.dart';

/// Repository for managing bets (predictions).
///
/// Per PRD Section 4.6 (Bet Tracking):
/// - 90-day duration, auto-expire without grace period
/// - Status: OPEN, CORRECT, WRONG, EXPIRED
/// - No "partially correct" - forces clear accountability
/// - Retroactive evaluation allowed for expired bets
class BetRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Default bet duration in days.
  static const betDurationDays = 90;

  BetRepository(this._db);

  /// Creates a new bet with automatic due date.
  Future<String> create({
    required String prediction,
    required String wrongIf,
    String? sourceSessionId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final dueDate = now.add(const Duration(days: betDurationDays));

    await _db.into(_db.bets).insert(
          BetsCompanion.insert(
            id: id,
            prediction: prediction,
            wrongIf: wrongIf,
            sourceSessionId: Value(sourceSessionId),
            createdAtUtc: now,
            dueAtUtc: dueDate,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves a bet by ID.
  Future<Bet?> getById(String id) async {
    final query = _db.select(_db.bets)
      ..where((b) => b.id.equals(id) & b.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves all non-deleted bets, ordered by due date (soonest first).
  Future<List<Bet>> getAll({int? limit, int? offset}) async {
    final query = _db.select(_db.bets)
      ..where((b) => b.deletedAtUtc.isNull())
      ..orderBy([(b) => OrderingTerm.asc(b.dueAtUtc)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Gets bets by status.
  Future<List<Bet>> getByStatus(BetStatus status) async {
    final query = _db.select(_db.bets)
      ..where((b) => b.deletedAtUtc.isNull() & b.status.equals(status.name))
      ..orderBy([(b) => OrderingTerm.asc(b.dueAtUtc)]);

    return query.get();
  }

  /// Gets open bets (active, not yet due).
  Future<List<Bet>> getOpen() async {
    return getByStatus(BetStatus.open);
  }

  /// Gets bets that need evaluation (expired or approaching due date).
  ///
  /// Per PRD: Expired bets appear in "Needs Evaluation" section.
  Future<List<Bet>> getNeedingEvaluation() async {
    final now = DateTime.now().toUtc();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    final query = _db.select(_db.bets)
      ..where(
        (b) =>
            b.deletedAtUtc.isNull() &
            (b.status.equals(BetStatus.expired.name) |
                (b.status.equals(BetStatus.open.name) & b.dueAtUtc.isSmallerOrEqualValue(sevenDaysFromNow))),
      )
      ..orderBy([(b) => OrderingTerm.asc(b.dueAtUtc)]);

    return query.get();
  }

  /// Gets the most recent open bet.
  Future<Bet?> getMostRecentOpen() async {
    final query = _db.select(_db.bets)
      ..where((b) => b.deletedAtUtc.isNull() & b.status.equals(BetStatus.open.name))
      ..orderBy([(b) => OrderingTerm.desc(b.createdAtUtc)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Gets the bet to be evaluated in a quarterly review.
  ///
  /// Returns the oldest open or expired bet.
  Future<Bet?> getBetForQuarterlyReview() async {
    final query = _db.select(_db.bets)
      ..where(
        (b) =>
            b.deletedAtUtc.isNull() &
            (b.status.equals(BetStatus.open.name) | b.status.equals(BetStatus.expired.name)),
      )
      ..orderBy([(b) => OrderingTerm.asc(b.createdAtUtc)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Evaluates a bet as correct or wrong.
  ///
  /// Per PRD Section 4.6: Transition rules enforced.
  Future<bool> evaluate(
    String id, {
    required BetStatus newStatus,
    String? evaluationNotes,
    String? evaluationSessionId,
  }) async {
    if (newStatus != BetStatus.correct && newStatus != BetStatus.wrong) {
      return false; // Can only evaluate to correct or wrong
    }

    final bet = await getById(id);
    if (bet == null) return false;

    final currentStatus = BetStatus.values.firstWhere(
      (s) => s.name == bet.status,
      orElse: () => BetStatus.open,
    );

    if (!currentStatus.canTransitionTo(newStatus)) {
      return false;
    }

    final now = DateTime.now().toUtc();

    await (_db.update(_db.bets)..where((b) => b.id.equals(id))).write(
      BetsCompanion(
        status: Value(newStatus.name),
        evaluationNotes: evaluationNotes != null ? Value(evaluationNotes) : const Value.absent(),
        evaluationSessionId: evaluationSessionId != null ? Value(evaluationSessionId) : const Value.absent(),
        evaluatedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    return true;
  }

  /// Expires overdue open bets.
  ///
  /// Per PRD: Auto-transition to EXPIRED at midnight on due date.
  /// Should be called on app launch and periodically.
  Future<int> expireOverdueBets() async {
    final now = DateTime.now().toUtc();

    final overdue = await (_db.select(_db.bets)
          ..where(
            (b) => b.deletedAtUtc.isNull() & b.status.equals(BetStatus.open.name) & b.dueAtUtc.isSmallerThanValue(now),
          ))
        .get();

    for (final bet in overdue) {
      await (_db.update(_db.bets)..where((b) => b.id.equals(bet.id))).write(
        BetsCompanion(
          status: Value(BetStatus.expired.name),
          updatedAtUtc: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    }

    return overdue.length;
  }

  /// Gets evaluation rate statistics.
  Future<Map<String, int>> getEvaluationStats() async {
    final bets = await getAll();

    final stats = <String, int>{
      'total': bets.length,
      'open': 0,
      'correct': 0,
      'wrong': 0,
      'expired': 0,
    };

    for (final bet in bets) {
      final status = bet.status;
      if (stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }
    }

    return stats;
  }

  /// Soft deletes a bet.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.bets)..where((b) => b.id.equals(id))).write(
      BetsCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Gets bets with pending sync status.
  Future<List<Bet>> getPendingSync() async {
    final query = _db.select(_db.bets)
      ..where((b) => b.syncStatus.equals('pending'))
      ..orderBy([(b) => OrderingTerm.asc(b.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a bet.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.bets)..where((b) => b.id.equals(id))).write(
      BetsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all bets (for reactive UI updates).
  Stream<List<Bet>> watchAll() {
    final query = _db.select(_db.bets)
      ..where((b) => b.deletedAtUtc.isNull())
      ..orderBy([(b) => OrderingTerm.asc(b.dueAtUtc)]);

    return query.watch();
  }

  /// Watches open bets.
  Stream<List<Bet>> watchOpen() {
    final query = _db.select(_db.bets)
      ..where((b) => b.deletedAtUtc.isNull() & b.status.equals(BetStatus.open.name))
      ..orderBy([(b) => OrderingTerm.asc(b.dueAtUtc)]);

    return query.watch();
  }

  /// Watches a specific bet by ID.
  Stream<Bet?> watchById(String id) {
    final query = _db.select(_db.bets)
      ..where((b) => b.id.equals(id) & b.deletedAtUtc.isNull());

    return query.watchSingleOrNull();
  }
}
