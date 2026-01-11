import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/governance_session_type.dart';
import 'base_repository.dart';

/// Repository for managing governance sessions.
///
/// Per PRD Section 4.3-4.5:
/// - Quick Version: 5 questions, 15 minutes
/// - Setup: Portfolio + Board + Personas
/// - Quarterly: Full report with board interrogation
///
/// Sessions are implemented as finite state machines with:
/// - One-question-at-a-time enforcement
/// - Vagueness gating (max 2 skips per session)
/// - Abstraction mode for privacy
class GovernanceSessionRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Maximum vagueness skips allowed per session.
  static const maxVaguenessSkips = 2;

  GovernanceSessionRepository(this._db);

  /// Creates a new governance session.
  Future<String> create({
    required GovernanceSessionType sessionType,
    required String initialState,
    bool abstractionMode = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.governanceSessions).insert(
          GovernanceSessionsCompanion.insert(
            id: id,
            sessionType: sessionType.name,
            currentState: initialState,
            abstractionMode: Value(abstractionMode),
            startedAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves a session by ID.
  Future<GovernanceSession?> getById(String id) async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.id.equals(id) & s.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves all sessions, ordered by start date (newest first).
  Future<List<GovernanceSession>> getAll({int? limit, int? offset}) async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAtUtc)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Gets sessions by type.
  Future<List<GovernanceSession>> getByType(GovernanceSessionType type) async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull() & s.sessionType.equals(type.name))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAtUtc)]);

    return query.get();
  }

  /// Gets completed sessions.
  Future<List<GovernanceSession>> getCompleted() async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull() & s.isCompleted.equals(true))
      ..orderBy([(s) => OrderingTerm.desc(s.completedAtUtc)]);

    return query.get();
  }

  /// Gets the most recent completed session of a specific type.
  Future<GovernanceSession?> getMostRecentCompleted(GovernanceSessionType type) async {
    final query = _db.select(_db.governanceSessions)
      ..where(
        (s) => s.deletedAtUtc.isNull() & s.isCompleted.equals(true) & s.sessionType.equals(type.name),
      )
      ..orderBy([
        (s) => OrderingTerm.desc(s.completedAtUtc),
        (s) => OrderingTerm.desc(s.startedAtUtc),
      ])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Gets any in-progress session.
  Future<GovernanceSession?> getInProgress() async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull() & s.isCompleted.equals(false))
      ..orderBy([(s) => OrderingTerm.desc(s.startedAtUtc)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Gets session count for a time period (for rate limiting visibility).
  ///
  /// Per PRD Section 3A.1: Soft limits shown to user.
  Future<int> getSessionCountForPeriod(
    GovernanceSessionType type,
    DateRange range,
  ) async {
    final result = await (_db.select(_db.governanceSessions)
          ..where(
            (s) =>
                s.deletedAtUtc.isNull() &
                s.sessionType.equals(type.name) &
                s.startedAtUtc.isBiggerOrEqualValue(range.start) &
                s.startedAtUtc.isSmallerOrEqualValue(range.end),
          ))
        .get();

    return result.length;
  }

  /// Checks if a quarterly report was generated within the last 30 days.
  ///
  /// Per PRD Section 4.5: Warning if <30 days since last report.
  Future<bool> hasRecentQuarterlyReport() async {
    final thirtyDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 30));

    final result = await (_db.select(_db.governanceSessions)
          ..where(
            (s) =>
                s.deletedAtUtc.isNull() &
                s.isCompleted.equals(true) &
                s.sessionType.equals(GovernanceSessionType.quarterly.name) &
                s.completedAtUtc.isBiggerOrEqualValue(thirtyDaysAgo),
          )
          ..limit(1))
        .get();

    return result.isNotEmpty;
  }

  /// Updates the current state in the state machine.
  Future<void> updateState(String id, String newState) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        currentState: Value(newState),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Appends a Q&A entry to the transcript.
  Future<void> appendToTranscript(String id, String transcriptJson) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        transcriptJson: Value(transcriptJson),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Increments the vagueness skip count.
  ///
  /// Returns false if max skips reached.
  Future<bool> incrementVaguenessSkip(String id) async {
    final session = await getById(id);
    if (session == null) return false;

    if (session.vaguenessSkipCount >= maxVaguenessSkips) {
      return false;
    }

    final now = DateTime.now().toUtc();

    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        vaguenessSkipCount: Value(session.vaguenessSkipCount + 1),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    return true;
  }

  /// Gets remaining vagueness skips for a session.
  Future<int> getRemainingSkips(String id) async {
    final session = await getById(id);
    if (session == null) return 0;
    return maxVaguenessSkips - session.vaguenessSkipCount;
  }

  /// Completes a session with final output.
  Future<void> complete(
    String id, {
    required String outputMarkdown,
    String? createdPortfolioVersionId,
    String? evaluatedBetId,
    String? createdBetId,
  }) async {
    final now = DateTime.now().toUtc();
    final session = await getById(id);
    final duration = session != null ? now.difference(session.startedAtUtc).inSeconds : null;

    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        isCompleted: const Value(true),
        outputMarkdown: Value(outputMarkdown),
        createdPortfolioVersionId:
            createdPortfolioVersionId != null ? Value(createdPortfolioVersionId) : const Value.absent(),
        evaluatedBetId: evaluatedBetId != null ? Value(evaluatedBetId) : const Value.absent(),
        createdBetId: createdBetId != null ? Value(createdBetId) : const Value.absent(),
        durationSeconds: duration != null ? Value(duration) : const Value.absent(),
        completedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Abandons an in-progress session (soft delete).
  Future<void> abandon(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Gets sessions with pending sync status.
  Future<List<GovernanceSession>> getPendingSync() async {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.syncStatus.equals('pending'))
      ..orderBy([(s) => OrderingTerm.asc(s.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a session.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(id))).write(
      GovernanceSessionsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all sessions (for reactive UI updates).
  Stream<List<GovernanceSession>> watchAll() {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.startedAtUtc)]);

    return query.watch();
  }

  /// Watches completed sessions.
  Stream<List<GovernanceSession>> watchCompleted() {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.deletedAtUtc.isNull() & s.isCompleted.equals(true))
      ..orderBy([(s) => OrderingTerm.desc(s.completedAtUtc)]);

    return query.watch();
  }

  /// Watches a specific session by ID.
  Stream<GovernanceSession?> watchById(String id) {
    final query = _db.select(_db.governanceSessions)
      ..where((s) => s.id.equals(id) & s.deletedAtUtc.isNull());

    return query.watchSingleOrNull();
  }
}
