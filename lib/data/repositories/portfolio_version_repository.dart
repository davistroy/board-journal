import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'base_repository.dart';

/// Repository for managing portfolio version snapshots.
///
/// Per PRD Section 3.1 and 4.4:
/// - Each Setup/re-setup completion snapshots the portfolio
/// - Stores: problems, directions, allocations, health, board anchoring
/// - Version number increments, timestamp recorded
/// - View any past version (read-only)
/// - Compare two versions side-by-side
class PortfolioVersionRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PortfolioVersionRepository(this._db);

  /// Creates a new portfolio version snapshot.
  Future<String> create({
    required int versionNumber,
    required String problemsSnapshotJson,
    required String healthSnapshotJson,
    required String boardAnchoringSnapshotJson,
    required String triggersSnapshotJson,
    required String triggerReason,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.portfolioVersions).insert(
          PortfolioVersionsCompanion.insert(
            id: id,
            versionNumber: versionNumber,
            problemsSnapshotJson: problemsSnapshotJson,
            healthSnapshotJson: healthSnapshotJson,
            boardAnchoringSnapshotJson: boardAnchoringSnapshotJson,
            triggersSnapshotJson: triggersSnapshotJson,
            triggerReason: triggerReason,
            createdAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves a version by ID.
  Future<PortfolioVersion?> getById(String id) async {
    final query = _db.select(_db.portfolioVersions)
      ..where((v) => v.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Retrieves a version by version number.
  Future<PortfolioVersion?> getByNumber(int versionNumber) async {
    final query = _db.select(_db.portfolioVersions)
      ..where((v) => v.versionNumber.equals(versionNumber));
    return query.getSingleOrNull();
  }

  /// Gets all versions, ordered by version number (newest first).
  Future<List<PortfolioVersion>> getAll() async {
    final query = _db.select(_db.portfolioVersions)
      ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)]);

    return query.get();
  }

  /// Gets the current (latest) version.
  Future<PortfolioVersion?> getCurrent() async {
    final query = _db.select(_db.portfolioVersions)
      ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Gets the current version number.
  Future<int> getCurrentVersionNumber() async {
    final current = await getCurrent();
    return current?.versionNumber ?? 0;
  }

  /// Gets the next version number.
  Future<int> getNextVersionNumber() async {
    final current = await getCurrentVersionNumber();
    return current + 1;
  }

  /// Checks if a portfolio exists (has at least one version).
  Future<bool> hasPortfolio() async {
    final current = await getCurrent();
    return current != null;
  }

  /// Gets versions for comparison (returns two versions).
  Future<List<PortfolioVersion>> getForComparison(int version1, int version2) async {
    final v1 = await getByNumber(version1);
    final v2 = await getByNumber(version2);

    final result = <PortfolioVersion>[];
    if (v1 != null) result.add(v1);
    if (v2 != null) result.add(v2);

    return result;
  }

  /// Gets versions with pending sync status.
  Future<List<PortfolioVersion>> getPendingSync() async {
    final query = _db.select(_db.portfolioVersions)
      ..where((v) => v.syncStatus.equals('pending'))
      ..orderBy([(v) => OrderingTerm.asc(v.createdAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a version.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.portfolioVersions)..where((v) => v.id.equals(id))).write(
      PortfolioVersionsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all versions (for reactive UI updates).
  Stream<List<PortfolioVersion>> watchAll() {
    final query = _db.select(_db.portfolioVersions)
      ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)]);

    return query.watch();
  }

  /// Watches the current version.
  Stream<PortfolioVersion?> watchCurrent() {
    final query = _db.select(_db.portfolioVersions)
      ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
      ..limit(1);

    return query.watchSingleOrNull();
  }
}
