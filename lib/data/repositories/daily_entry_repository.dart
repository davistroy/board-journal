import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/entry_type.dart';
import 'base_repository.dart';

/// Repository for managing daily journal entries.
///
/// Per PRD Section 4.1 (Daily Journal Entry):
/// - Max 15 minutes per recording (~2500 words)
/// - Max 7500 words per entry including follow-ups
/// - Entries editable indefinitely (no time-based locking)
class DailyEntryRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DailyEntryRepository(this._db);

  /// Creates a new daily entry.
  ///
  /// Returns the created entry's ID.
  Future<String> create({
    required String transcriptRaw,
    required String transcriptEdited,
    required EntryType entryType,
    required String timezone,
    String extractedSignalsJson = '{}',
    int? durationSeconds,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    final wordCount = _countWords(transcriptEdited);

    await _db.into(_db.dailyEntries).insert(
          DailyEntriesCompanion.insert(
            id: id,
            transcriptRaw: transcriptRaw,
            transcriptEdited: transcriptEdited,
            extractedSignalsJson: Value(extractedSignalsJson),
            entryType: entryType.name,
            wordCount: Value(wordCount),
            durationSeconds: Value(durationSeconds),
            createdAtUtc: now,
            createdAtTimezone: timezone,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves an entry by ID.
  ///
  /// Returns null if not found or soft-deleted.
  Future<DailyEntry?> getById(String id) async {
    final query = _db.select(_db.dailyEntries)
      ..where((e) => e.id.equals(id) & e.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves all non-deleted entries, ordered by creation date (newest first).
  Future<List<DailyEntry>> getAll({int? limit, int? offset}) async {
    final query = _db.select(_db.dailyEntries)
      ..where((e) => e.deletedAtUtc.isNull())
      ..orderBy([
        (e) => OrderingTerm.desc(e.createdAtUtc),
        (e) => OrderingTerm.desc(e.updatedAtUtc),
      ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Retrieves entries within a date range.
  Future<List<DailyEntry>> getByDateRange(DateRange range) async {
    final query = _db.select(_db.dailyEntries)
      ..where(
        (e) =>
            e.deletedAtUtc.isNull() &
            e.createdAtUtc.isBiggerOrEqualValue(range.start) &
            e.createdAtUtc.isSmallerOrEqualValue(range.end),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.get();
  }

  /// Retrieves entries for a specific week (for weekly brief generation).
  Future<List<DailyEntry>> getEntriesForWeek(DateTime anyDayInWeek) async {
    final range = DateRange.forWeek(anyDayInWeek);
    return getByDateRange(range);
  }

  /// Gets the count of entries for a specific day.
  ///
  /// Per PRD: Soft cap 10/day with usage visibility.
  Future<int> getEntryCountForDay(DateTime day) async {
    final startOfDay = DateTime.utc(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    final result = await (_db.select(_db.dailyEntries)
          ..where(
            (e) =>
                e.deletedAtUtc.isNull() &
                e.createdAtUtc.isBiggerOrEqualValue(startOfDay) &
                e.createdAtUtc.isSmallerOrEqualValue(endOfDay),
          ))
        .get();

    return result.length;
  }

  /// Gets the total entry count (for setup prompt trigger).
  ///
  /// Per PRD: Setup prompt appears after 3-5 entries.
  Future<int> getTotalEntryCount() async {
    final result = await (_db.select(_db.dailyEntries)
          ..where((e) => e.deletedAtUtc.isNull()))
        .get();
    return result.length;
  }

  /// Updates the edited transcript.
  Future<void> updateTranscript(String id, String transcriptEdited) async {
    final wordCount = _countWords(transcriptEdited);
    final now = DateTime.now().toUtc();

    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(id))).write(
      DailyEntriesCompanion(
        transcriptEdited: Value(transcriptEdited),
        wordCount: Value(wordCount),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates the extracted signals JSON.
  Future<void> updateExtractedSignals(String id, String signalsJson) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(id))).write(
      DailyEntriesCompanion(
        extractedSignalsJson: Value(signalsJson),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Soft deletes an entry.
  ///
  /// Per PRD Section 3C.3: Hard delete within 30 days.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(id))).write(
      DailyEntriesCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Restores a soft-deleted entry.
  Future<void> restore(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(id))).write(
      DailyEntriesCompanion(
        deletedAtUtc: const Value(null),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Hard deletes entries that have been soft-deleted for more than 30 days.
  Future<int> purgeOldDeletedEntries() async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));

    return (_db.delete(_db.dailyEntries)
          ..where(
            (e) => e.deletedAtUtc.isNotNull() & e.deletedAtUtc.isSmallerOrEqualValue(cutoff),
          ))
        .go();
  }

  /// Gets entries with pending sync status.
  Future<List<DailyEntry>> getPendingSync() async {
    final query = _db.select(_db.dailyEntries)
      ..where((e) => e.syncStatus.equals('pending'))
      ..orderBy([(e) => OrderingTerm.asc(e.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for an entry.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(id))).write(
      DailyEntriesCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all non-deleted entries (for reactive UI updates).
  Stream<List<DailyEntry>> watchAll() {
    final query = _db.select(_db.dailyEntries)
      ..where((e) => e.deletedAtUtc.isNull())
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.watch();
  }

  /// Watches entries for a specific date range.
  Stream<List<DailyEntry>> watchByDateRange(DateRange range) {
    final query = _db.select(_db.dailyEntries)
      ..where(
        (e) =>
            e.deletedAtUtc.isNull() &
            e.createdAtUtc.isBiggerOrEqualValue(range.start) &
            e.createdAtUtc.isSmallerOrEqualValue(range.end),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.watch();
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
