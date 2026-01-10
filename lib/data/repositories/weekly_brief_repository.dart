import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'base_repository.dart';

/// Repository for managing weekly briefs.
///
/// Per PRD Section 4.2 (Weekly Brief Generation):
/// - Auto-generates Sunday 8pm local time
/// - Target ~600 words, max 800 words
/// - Max 5 regenerations per brief
/// - Zero-entry weeks get reflection brief (~100 words)
class WeeklyBriefRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Maximum allowed regenerations per brief.
  static const maxRegenerations = 5;

  WeeklyBriefRepository(this._db);

  /// Creates a new weekly brief.
  Future<String> create({
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
    required String weekTimezone,
    required String briefMarkdown,
    String? boardMicroReviewMarkdown,
    int entryCount = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.weeklyBriefs).insert(
          WeeklyBriefsCompanion.insert(
            id: id,
            weekStartUtc: weekStartUtc,
            weekEndUtc: weekEndUtc,
            weekTimezone: weekTimezone,
            briefMarkdown: briefMarkdown,
            boardMicroReviewMarkdown: Value(boardMicroReviewMarkdown),
            entryCount: Value(entryCount),
            generatedAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves a brief by ID.
  Future<WeeklyBrief?> getById(String id) async {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.id.equals(id) & b.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves the brief for a specific week.
  ///
  /// Returns null if no brief exists for that week.
  Future<WeeklyBrief?> getByWeek(DateTime anyDayInWeek) async {
    final range = DateRange.forWeek(anyDayInWeek);

    final query = _db.select(_db.weeklyBriefs)
      ..where(
        (b) =>
            b.deletedAtUtc.isNull() &
            b.weekStartUtc.isBiggerOrEqualValue(range.start) &
            b.weekStartUtc.isSmallerOrEqualValue(range.end),
      );

    return query.getSingleOrNull();
  }

  /// Retrieves all briefs, ordered by week (newest first).
  Future<List<WeeklyBrief>> getAll({int? limit, int? offset}) async {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.deletedAtUtc.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.weekStartUtc)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Gets the most recent brief.
  Future<WeeklyBrief?> getMostRecent() async {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.deletedAtUtc.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.weekStartUtc)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Updates the brief content.
  Future<void> updateBrief(String id, String briefMarkdown) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        briefMarkdown: Value(briefMarkdown),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates the board micro-review.
  Future<void> updateMicroReview(String id, String microReviewMarkdown) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        boardMicroReviewMarkdown: Value(microReviewMarkdown),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Increments the regeneration count and optionally updates options.
  ///
  /// Returns false if max regenerations reached.
  Future<bool> incrementRegenCount(String id, {String? regenOptionsJson}) async {
    final brief = await getById(id);
    if (brief == null) return false;

    if (brief.regenCount >= maxRegenerations) {
      return false;
    }

    final now = DateTime.now().toUtc();

    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        regenCount: Value(brief.regenCount + 1),
        regenOptionsJson: regenOptionsJson != null ? Value(regenOptionsJson) : const Value.absent(),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    return true;
  }

  /// Gets remaining regenerations for a brief.
  Future<int> getRemainingRegenerations(String id) async {
    final brief = await getById(id);
    if (brief == null) return 0;
    return maxRegenerations - brief.regenCount;
  }

  /// Updates micro-review collapsed state.
  Future<void> setMicroReviewCollapsed(String id, bool collapsed) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        microReviewCollapsed: Value(collapsed),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Soft deletes a brief.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Gets briefs with pending sync status.
  Future<List<WeeklyBrief>> getPendingSync() async {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.syncStatus.equals('pending'))
      ..orderBy([(b) => OrderingTerm.asc(b.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a brief.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(id))).write(
      WeeklyBriefsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all briefs (for reactive UI updates).
  Stream<List<WeeklyBrief>> watchAll() {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.deletedAtUtc.isNull())
      ..orderBy([(b) => OrderingTerm.desc(b.weekStartUtc)]);

    return query.watch();
  }

  /// Watches a specific brief by ID.
  Stream<WeeklyBrief?> watchById(String id) {
    final query = _db.select(_db.weeklyBriefs)
      ..where((b) => b.id.equals(id) & b.deletedAtUtc.isNull());

    return query.watchSingleOrNull();
  }
}
