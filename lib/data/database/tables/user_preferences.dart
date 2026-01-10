import 'package:drift/drift.dart';

/// User preferences table.
///
/// Stores user settings and preferences.
/// This is a singleton table (one row per local database).
///
/// Per PRD various sections:
/// - Abstraction mode defaults (per session type)
/// - Audio retention preference
/// - Analytics opt-out
/// - Board micro-review collapse preference
/// - Remembered sensitivity gate choices
@DataClassName('UserPreference')
class UserPreferences extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  // ==================
  // Privacy Settings
  // ==================

  /// Default abstraction mode for Quick Version sessions.
  BoolColumn get abstractionModeQuick => boolean().withDefault(const Constant(false))();

  /// Default abstraction mode for Setup sessions.
  BoolColumn get abstractionModeSetup => boolean().withDefault(const Constant(false))();

  /// Default abstraction mode for Quarterly sessions.
  BoolColumn get abstractionModeQuarterly => boolean().withDefault(const Constant(false))();

  /// Remember abstraction mode choice (don't ask again).
  BoolColumn get rememberAbstractionChoice => boolean().withDefault(const Constant(false))();

  /// Analytics enabled (ON by default per PRD).
  BoolColumn get analyticsEnabled => boolean().withDefault(const Constant(true))();

  // ==================
  // UI Preferences
  // ==================

  /// Board micro-review collapsed in weekly brief viewer.
  BoolColumn get microReviewCollapsed => boolean().withDefault(const Constant(false))();

  // ==================
  // Onboarding State
  // ==================

  /// Whether onboarding has been completed.
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();

  /// Whether setup prompt has been dismissed.
  BoolColumn get setupPromptDismissed => boolean().withDefault(const Constant(false))();

  /// Last time setup prompt was shown (for weekly re-show).
  DateTimeColumn get setupPromptLastShownUtc => dateTime().nullable()();

  /// Count of entries made (for setup prompt trigger after 3-5 entries).
  IntColumn get totalEntryCount => integer().withDefault(const Constant(0))();

  // ==================
  // Metadata
  // ==================

  /// UTC timestamp when preferences were created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// UTC timestamp when last modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
