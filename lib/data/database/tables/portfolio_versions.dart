import 'package:drift/drift.dart';

/// Portfolio version snapshots table.
///
/// Per PRD Section 3.1 and 4.4:
/// - Each Setup/re-setup completion snapshots the portfolio
/// - Stores: problems, directions, allocations, health, board anchoring
/// - Version number increments, timestamp recorded
/// - Access via Settings → Portfolio → "Version History"
/// - View any past version (read-only)
/// - Compare two versions side-by-side
@DataClassName('PortfolioVersion')
class PortfolioVersions extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Version number (1, 2, 3, ...).
  IntColumn get versionNumber => integer()();

  /// Complete snapshot of problems at this version.
  /// JSON array of problem objects with all fields.
  TextColumn get problemsSnapshotJson => text()();

  /// Portfolio health metrics at this version.
  /// JSON object with appreciating/depreciating/stable percentages.
  TextColumn get healthSnapshotJson => text()();

  /// Board anchoring at this version.
  /// JSON object mapping role types to problem IDs and demands.
  TextColumn get boardAnchoringSnapshotJson => text()();

  /// Re-setup triggers defined at this version.
  /// JSON array of trigger conditions.
  TextColumn get triggersSnapshotJson => text()();

  /// What triggered this version (initial setup, re-setup, problem deletion, etc.).
  TextColumn get triggerReason => text()();

  /// UTC timestamp when this version was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
