import 'package:drift/drift.dart';

/// Governance sessions table.
///
/// Per PRD Section 3.1:
/// - type: Quick, Setup, or Quarterly
/// - transcriptQandA: Full Q&A transcript
/// - outputMarkdown: Generated output/report
/// - abstractionMode: Whether names/companies were replaced with placeholders
///
/// Per PRD Section 4.3-4.5:
/// - Quick Version: 5 questions, 15 minutes
/// - Setup: Portfolio + Board + Personas
/// - Quarterly: Full report with board interrogation
@DataClassName('GovernanceSession')
class GovernanceSessions extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Session type: 'quick', 'setup', 'quarterly'.
  /// Maps to GovernanceSessionType enum.
  TextColumn get sessionType => text()();

  /// Current state in the session state machine.
  /// e.g., 'sensitivity_gate', 'q1_role_context', 'generate_output', etc.
  TextColumn get currentState => text()();

  /// Whether the session has been completed.
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Whether abstraction mode was enabled.
  /// Per PRD: Replaces names/companies with placeholders.
  BoolColumn get abstractionMode => boolean().withDefault(const Constant(false))();

  /// Number of vagueness gates skipped (max 2 per session).
  IntColumn get vaguenessSkipCount => integer().withDefault(const Constant(0))();

  /// Full Q&A transcript as JSON array.
  /// Format: [{"question": "...", "answer": "...", "isVague": false, ...}, ...]
  TextColumn get transcriptJson => text().withDefault(const Constant('[]'))();

  /// Generated output markdown (audit summary, report, etc.).
  TextColumn get outputMarkdown => text().nullable()();

  /// For Setup sessions: snapshot of created portfolio version ID.
  TextColumn get createdPortfolioVersionId => text().nullable()();

  /// For Quarterly sessions: ID of bet that was evaluated.
  TextColumn get evaluatedBetId => text().nullable()();

  /// For Quick/Quarterly: ID of new bet created.
  TextColumn get createdBetId => text().nullable()();

  /// Session duration in seconds.
  IntColumn get durationSeconds => integer().nullable()();

  /// UTC timestamp when session was started.
  DateTimeColumn get startedAtUtc => dateTime()();

  /// UTC timestamp when session was completed (null if in progress).
  DateTimeColumn get completedAtUtc => dateTime().nullable()();

  /// UTC timestamp when last modified.
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
