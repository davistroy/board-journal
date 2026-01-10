import 'package:drift/drift.dart';

/// Evidence items ("receipts") table.
///
/// Per PRD Section 3.2:
/// "Receipts" in MVP = Evidence statements (not files)
/// - type: Decision, Artifact, Calendar, Proxy, None
/// - text: The evidence statement
/// - strengthFlag: Strong, Medium, Weak, None
///
/// Evidence is collected during governance sessions when
/// users claim progress on commitments.
@DataClassName('EvidenceItem')
class EvidenceItems extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// ID of governance session where this evidence was collected.
  TextColumn get sessionId => text()();

  /// ID of problem this evidence relates to (if applicable).
  TextColumn get problemId => text().nullable()();

  /// Evidence type: 'decision', 'artifact', 'calendar', 'proxy', 'none'.
  /// Maps to EvidenceType enum.
  TextColumn get evidenceType => text()();

  /// The evidence statement text.
  TextColumn get statementText => text()();

  /// Evidence strength: 'strong', 'medium', 'weak', 'none'.
  /// Maps to EvidenceStrength enum.
  TextColumn get strengthFlag => text()();

  /// Context for why this evidence was collected (the claim being supported).
  TextColumn get context => text().nullable()();

  /// UTC timestamp when evidence was recorded.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
