import '../../data/repositories/user_preferences_repository.dart';

/// Service for managing privacy settings.
///
/// Per PRD Section 5.9:
/// - Abstraction mode: Replace names with placeholders
/// - Analytics: Help improve the app (ON by default with clear opt-out)
class PrivacyService {
  final UserPreferencesRepository _prefsRepository;

  PrivacyService(this._prefsRepository);

  // ==================
  // Abstraction Mode
  // ==================

  /// Gets whether abstraction mode is enabled for Quick Version sessions.
  Future<bool> getAbstractionModeQuick() async {
    final prefs = await _prefsRepository.get();
    return prefs.abstractionModeQuick;
  }

  /// Gets whether abstraction mode is enabled for Setup sessions.
  Future<bool> getAbstractionModeSetup() async {
    final prefs = await _prefsRepository.get();
    return prefs.abstractionModeSetup;
  }

  /// Gets whether abstraction mode is enabled for Quarterly sessions.
  Future<bool> getAbstractionModeQuarterly() async {
    final prefs = await _prefsRepository.get();
    return prefs.abstractionModeQuarterly;
  }

  /// Gets the global abstraction mode setting.
  ///
  /// Returns true if abstraction mode is enabled for any session type.
  Future<bool> getAbstractionMode() async {
    final prefs = await _prefsRepository.get();
    return prefs.abstractionModeQuick ||
        prefs.abstractionModeSetup ||
        prefs.abstractionModeQuarterly;
  }

  /// Sets abstraction mode for all session types.
  Future<void> setAbstractionMode(bool enabled) async {
    await _prefsRepository.updateAbstractionDefaults(
      quick: enabled,
      setup: enabled,
      quarterly: enabled,
    );
  }

  /// Sets abstraction mode for a specific session type.
  Future<void> setAbstractionModeForSession({
    bool? quick,
    bool? setup,
    bool? quarterly,
  }) async {
    await _prefsRepository.updateAbstractionDefaults(
      quick: quick,
      setup: setup,
      quarterly: quarterly,
    );
  }

  /// Gets whether to remember abstraction mode choice.
  Future<bool> getRememberAbstractionChoice() async {
    final prefs = await _prefsRepository.get();
    return prefs.rememberAbstractionChoice;
  }

  /// Sets whether to remember abstraction mode choice.
  Future<void> setRememberAbstractionChoice(bool remember) async {
    await _prefsRepository.updateAbstractionDefaults(
      rememberChoice: remember,
    );
  }

  // ==================
  // Analytics
  // ==================

  /// Gets whether analytics is enabled.
  ///
  /// Per PRD: ON by default with clear opt-out.
  Future<bool> getAnalyticsEnabled() async {
    final prefs = await _prefsRepository.get();
    return prefs.analyticsEnabled;
  }

  /// Sets whether analytics is enabled.
  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _prefsRepository.setAnalyticsEnabled(enabled);
  }

  // ==================
  // Utility Methods
  // ==================

  /// Resets all privacy settings to defaults.
  ///
  /// Defaults:
  /// - Abstraction mode: OFF for all session types
  /// - Remember choice: OFF
  /// - Analytics: ON
  Future<void> resetToDefaults() async {
    await _prefsRepository.updateAbstractionDefaults(
      quick: false,
      setup: false,
      quarterly: false,
      rememberChoice: false,
    );
    await _prefsRepository.setAnalyticsEnabled(true);
  }
}
