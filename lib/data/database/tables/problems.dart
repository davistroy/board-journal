import 'package:drift/drift.dart';

/// Career problems table.
///
/// Per PRD Section 4.4 (Setup):
/// Each problem requires:
/// - Name
/// - What breaks if not solved
/// - Scarcity signals (pick 2 OR Unknown + why)
/// - Direction evidence (AI cheaper?, Error cost?, Trust required?)
/// - Classification + one-sentence rationale
/// - Time allocation (percentage of work week)
///
/// Per PRD Section 3.3.4:
/// - Problems are anchored to board roles
/// - Multiple roles can anchor to same problem
/// - Portfolio must have 3-5 problems
@DataClassName('Problem')
class Problems extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Problem name/title.
  TextColumn get name => text()();

  /// Description of what breaks if this problem isn't solved.
  TextColumn get whatBreaks => text()();

  /// Scarcity signals (JSON array of 2 items, or "unknown" with reason).
  /// Format: ["signal1", "signal2"] or {"unknown": true, "reason": "..."}
  TextColumn get scarcitySignalsJson => text()();

  /// Direction classification: 'appreciating', 'depreciating', 'stable'.
  TextColumn get direction => text()();

  /// One-sentence rationale for direction classification.
  TextColumn get directionRationale => text()();

  /// Direction evidence: Is AI getting cheaper/better at this?
  /// User's quoted response.
  TextColumn get evidenceAiCheaper => text()();

  /// Direction evidence: What is the cost of errors?
  /// User's quoted response.
  TextColumn get evidenceErrorCost => text()();

  /// Direction evidence: Is trust/access required?
  /// User's quoted response.
  TextColumn get evidenceTrustRequired => text()();

  /// Time allocation as percentage of work week (0-100).
  /// Per PRD: Must sum to 95-105% across all problems.
  IntColumn get timeAllocationPercent => integer()();

  /// Display order within portfolio (0-indexed).
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  /// UTC timestamp when problem was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// UTC timestamp when problem was last modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Soft delete timestamp.
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
