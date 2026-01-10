import 'package:drift/drift.dart';

/// Re-setup triggers table.
///
/// Per PRD Section 3.3.7:
/// The system tracks conditions that should trigger a portfolio refresh:
/// - Role change (promotion, new job, new team) → Full re-setup
/// - Scope change (major project ends, new responsibility) → Full re-setup
/// - Direction shift (problem reclassified in 2+ quarterly reviews) → Update problem
/// - Time drift (20%+ shift in allocation vs setup) → Review portfolio health
/// - Annual (12 months since last setup) → Full re-setup (mandatory)
@DataClassName('ReSetupTrigger')
class ReSetupTriggers extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Trigger type: 'role_change', 'scope_change', 'direction_shift', 'time_drift', 'annual'.
  TextColumn get triggerType => text()();

  /// Human-readable description of the trigger condition.
  TextColumn get description => text()();

  /// Specific condition to check (e.g., "Time allocation shifts 20%+ from setup").
  TextColumn get condition => text()();

  /// Recommended action when triggered: 'full_resetup', 'update_problem', 'review_health'.
  TextColumn get recommendedAction => text()();

  /// Whether this trigger has been met.
  BoolColumn get isMet => boolean().withDefault(const Constant(false))();

  /// Timestamp when trigger was met (null if not met).
  DateTimeColumn get metAtUtc => dateTime().nullable()();

  /// For annual triggers: the due date.
  DateTimeColumn get dueAtUtc => dateTime().nullable()();

  /// UTC timestamp when trigger was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// UTC timestamp when last checked/modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
