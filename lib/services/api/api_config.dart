/// API configuration for Boardroom Journal backend.
///
/// Contains base URL, timeout settings, and endpoint paths.
library;

/// Configuration for the API client.
///
/// Per PRD Section 3B.2: Backend sync API configuration.
class ApiConfig {
  /// Base URL for the API.
  ///
  /// Defaults to localhost for development.
  /// Override with environment variable or build config for production.
  final String baseUrl;

  /// Default request timeout in seconds.
  ///
  /// 30 seconds as per requirements.
  final int timeoutSeconds;

  /// Maximum retry attempts for transient failures.
  final int maxRetries;

  /// Delay between retries in milliseconds.
  ///
  /// Uses exponential backoff: delay * 2^attemptNumber.
  final int retryDelayMs;

  /// Debounce duration for sync after local changes in milliseconds.
  ///
  /// 2 seconds as per requirements.
  final int syncDebounceMs;

  /// Periodic sync interval while foregrounded in minutes.
  ///
  /// 5 minutes as per requirements.
  final int periodicSyncMinutes;

  const ApiConfig({
    this.baseUrl = 'https://api.boardroomjournal.app',
    this.timeoutSeconds = 30,
    this.maxRetries = 3,
    this.retryDelayMs = 1000,
    this.syncDebounceMs = 2000,
    this.periodicSyncMinutes = 5,
  });

  /// Development configuration with localhost.
  factory ApiConfig.development() {
    return const ApiConfig(
      baseUrl: 'http://localhost:8080',
      timeoutSeconds: 30,
      maxRetries: 3,
      retryDelayMs: 500,
      syncDebounceMs: 2000,
      periodicSyncMinutes: 5,
    );
  }

  /// Staging configuration.
  factory ApiConfig.staging() {
    return const ApiConfig(
      baseUrl: 'https://staging-api.boardroomjournal.app',
      timeoutSeconds: 30,
      maxRetries: 3,
      retryDelayMs: 1000,
      syncDebounceMs: 2000,
      periodicSyncMinutes: 5,
    );
  }

  /// Production configuration.
  factory ApiConfig.production() {
    return const ApiConfig(
      baseUrl: 'https://api.boardroomjournal.app',
      timeoutSeconds: 30,
      maxRetries: 3,
      retryDelayMs: 1000,
      syncDebounceMs: 2000,
      periodicSyncMinutes: 5,
    );
  }

  /// Request timeout as Duration.
  Duration get timeout => Duration(seconds: timeoutSeconds);

  /// Sync debounce duration.
  Duration get syncDebounce => Duration(milliseconds: syncDebounceMs);

  /// Periodic sync interval.
  Duration get periodicSyncInterval => Duration(minutes: periodicSyncMinutes);

  /// Calculates retry delay with exponential backoff.
  Duration retryDelay(int attemptNumber) {
    final delayMs = retryDelayMs * (1 << attemptNumber); // 2^n
    return Duration(milliseconds: delayMs.clamp(0, 30000)); // Max 30 seconds
  }
}

/// API endpoint paths.
abstract class ApiEndpoints {
  /// Authentication endpoints.
  static const String authRefresh = '/auth/refresh';
  static const String authRevoke = '/auth/revoke';

  /// Sync endpoints.
  static const String syncPull = '/sync/pull';
  static const String syncPush = '/sync/push';
  static const String syncFull = '/sync/full';
  static const String syncStatus = '/sync/status';

  /// Daily entries endpoints.
  static const String entriesBase = '/entries';
  static String entryById(String id) => '/entries/$id';

  /// Weekly briefs endpoints.
  static const String briefsBase = '/briefs';
  static String briefById(String id) => '/briefs/$id';

  /// Problems endpoints.
  static const String problemsBase = '/problems';
  static String problemById(String id) => '/problems/$id';

  /// Board members endpoints.
  static const String boardMembersBase = '/board-members';
  static String boardMemberById(String id) => '/board-members/$id';

  /// Bets endpoints.
  static const String betsBase = '/bets';
  static String betById(String id) => '/bets/$id';

  /// Governance sessions endpoints.
  static const String governanceSessionsBase = '/governance-sessions';
  static String governanceSessionById(String id) => '/governance-sessions/$id';

  /// AI processing endpoints.
  static const String transcribe = '/ai/transcribe';
  static const String extractSignals = '/ai/extract-signals';
  static const String generateBrief = '/ai/generate-brief';
}
