import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'base_repository.dart';

/// Repository for managing user preferences.
///
/// This is a singleton table (one row per local database).
///
/// Per PRD various sections:
/// - Abstraction mode defaults (per session type)
/// - Analytics opt-out
/// - Board micro-review collapse preference
/// - Onboarding state
/// - Setup prompt tracking
class UserPreferencesRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  UserPreferencesRepository(this._db);

  /// Gets the current user preferences.
  ///
  /// Creates default preferences if none exist.
  Future<UserPreference> get() async {
    final query = _db.select(_db.userPreferences)..limit(1);
    final existing = await query.getSingleOrNull();

    if (existing != null) {
      return existing;
    }

    // Create default preferences
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.userPreferences).insert(
          UserPreferencesCompanion.insert(
            id: id,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return (await query.getSingle());
  }

  /// Gets the preferences ID (creating if necessary).
  Future<String> _getOrCreateId() async {
    final prefs = await get();
    return prefs.id;
  }

  /// Updates abstraction mode defaults.
  Future<void> updateAbstractionDefaults({
    bool? quick,
    bool? setup,
    bool? quarterly,
    bool? rememberChoice,
  }) async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        abstractionModeQuick: quick != null ? Value(quick) : const Value.absent(),
        abstractionModeSetup: setup != null ? Value(setup) : const Value.absent(),
        abstractionModeQuarterly: quarterly != null ? Value(quarterly) : const Value.absent(),
        rememberAbstractionChoice: rememberChoice != null ? Value(rememberChoice) : const Value.absent(),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates analytics enabled setting.
  ///
  /// Per PRD: ON by default with clear opt-out.
  Future<void> setAnalyticsEnabled(bool enabled) async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        analyticsEnabled: Value(enabled),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates micro-review collapsed preference.
  Future<void> setMicroReviewCollapsed(bool collapsed) async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        microReviewCollapsed: Value(collapsed),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        onboardingCompleted: const Value(true),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Checks if onboarding is completed.
  Future<bool> isOnboardingCompleted() async {
    final prefs = await get();
    return prefs.onboardingCompleted;
  }

  /// Dismisses the setup prompt.
  Future<void> dismissSetupPrompt() async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        setupPromptDismissed: const Value(true),
        setupPromptLastShownUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Records that setup prompt was shown.
  Future<void> recordSetupPromptShown() async {
    final id = await _getOrCreateId();
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        setupPromptLastShownUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Checks if setup prompt should be shown.
  ///
  /// Per PRD Section 5.0: Setup CTA shown after 3-5 entries,
  /// re-shows weekly until completed.
  Future<bool> shouldShowSetupPrompt() async {
    final prefs = await get();

    // Don't show if dismissed
    if (prefs.setupPromptDismissed) {
      // But re-show weekly
      final lastShown = prefs.setupPromptLastShownUtc;
      if (lastShown == null) return true;

      final weekAgo = DateTime.now().toUtc().subtract(const Duration(days: 7));
      if (lastShown.isBefore(weekAgo)) {
        return true;
      }
      return false;
    }

    // Show if enough entries (3-5)
    return prefs.totalEntryCount >= 3;
  }

  /// Increments total entry count.
  ///
  /// Per PRD: Setup prompt trigger after 3-5 entries.
  Future<void> incrementEntryCount() async {
    final prefs = await get();
    final id = prefs.id;
    final now = DateTime.now().toUtc();

    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        totalEntryCount: Value(prefs.totalEntryCount + 1),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Gets total entry count.
  Future<int> getTotalEntryCount() async {
    final prefs = await get();
    return prefs.totalEntryCount;
  }

  /// Gets preferences with pending sync status.
  Future<List<UserPreference>> getPendingSync() async {
    final query = _db.select(_db.userPreferences)
      ..where((p) => p.syncStatus.equals('pending'));

    return query.get();
  }

  /// Updates sync status for preferences.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.userPreferences)..where((p) => p.id.equals(id))).write(
      UserPreferencesCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches the current preferences.
  Stream<UserPreference?> watch() {
    final query = _db.select(_db.userPreferences)..limit(1);
    return query.watchSingleOrNull();
  }
}
