import 'dart:io';

/// Application configuration loaded from environment variables.
///
/// All sensitive values should be provided via environment variables,
/// not hardcoded. Use .env file for local development (never commit to git).
class Config {
  /// Singleton instance.
  static Config? _instance;

  /// Get the configuration instance.
  static Config get instance {
    _instance ??= Config._load();
    return _instance!;
  }

  /// Reset instance (for testing).
  static void reset() {
    _instance = null;
  }

  // Server configuration
  final String host;
  final int port;
  final String environment;

  // Database configuration
  final String databaseHost;
  final int databasePort;
  final String databaseName;
  final String databaseUser;
  final String databasePassword;
  final int databasePoolSize;

  // JWT configuration
  final String jwtSecret;
  final Duration jwtAccessTokenExpiry;
  final Duration jwtRefreshTokenExpiry;

  // OAuth providers
  final String? appleClientId;
  final String? appleTeamId;
  final String? appleKeyId;
  final String? applePrivateKey;

  final String? googleClientId;
  final String? googleClientSecret;

  // AI services
  final String? claudeApiKey;
  final String? deepgramApiKey;

  // Rate limiting
  final int rateLimitAccountCreationPerHour;
  final int rateLimitAuthAttemptsBeforeLockout;
  final Duration rateLimitAuthLockoutDuration;

  // Request limits
  final int maxRequestBodySize;

  Config._({
    required this.host,
    required this.port,
    required this.environment,
    required this.databaseHost,
    required this.databasePort,
    required this.databaseName,
    required this.databaseUser,
    required this.databasePassword,
    required this.databasePoolSize,
    required this.jwtSecret,
    required this.jwtAccessTokenExpiry,
    required this.jwtRefreshTokenExpiry,
    this.appleClientId,
    this.appleTeamId,
    this.appleKeyId,
    this.applePrivateKey,
    this.googleClientId,
    this.googleClientSecret,
    this.claudeApiKey,
    this.deepgramApiKey,
    required this.rateLimitAccountCreationPerHour,
    required this.rateLimitAuthAttemptsBeforeLockout,
    required this.rateLimitAuthLockoutDuration,
    required this.maxRequestBodySize,
  });

  /// Load configuration from environment variables.
  factory Config._load() {
    return Config._(
      // Server
      host: _getEnv('HOST', '0.0.0.0'),
      port: int.parse(_getEnv('PORT', '8080')),
      environment: _getEnv('ENVIRONMENT', 'development'),

      // Database
      databaseHost: _getEnv('DATABASE_HOST', 'localhost'),
      databasePort: int.parse(_getEnv('DATABASE_PORT', '5432')),
      databaseName: _getEnv('DATABASE_NAME', 'boardroom_journal'),
      databaseUser: _getEnv('DATABASE_USER', 'postgres'),
      databasePassword: _getEnvRequired('DATABASE_PASSWORD'),
      databasePoolSize: int.parse(_getEnv('DATABASE_POOL_SIZE', '10')),

      // JWT
      jwtSecret: _getEnvRequired('JWT_SECRET'),
      jwtAccessTokenExpiry: Duration(
        minutes: int.parse(_getEnv('JWT_ACCESS_TOKEN_EXPIRY_MINUTES', '15')),
      ),
      jwtRefreshTokenExpiry: Duration(
        days: int.parse(_getEnv('JWT_REFRESH_TOKEN_EXPIRY_DAYS', '30')),
      ),

      // Apple OAuth
      appleClientId: _getEnvOptional('APPLE_CLIENT_ID'),
      appleTeamId: _getEnvOptional('APPLE_TEAM_ID'),
      appleKeyId: _getEnvOptional('APPLE_KEY_ID'),
      applePrivateKey: _getEnvOptional('APPLE_PRIVATE_KEY'),

      // Google OAuth
      googleClientId: _getEnvOptional('GOOGLE_CLIENT_ID'),
      googleClientSecret: _getEnvOptional('GOOGLE_CLIENT_SECRET'),

      // AI services
      claudeApiKey: _getEnvOptional('CLAUDE_API_KEY'),
      deepgramApiKey: _getEnvOptional('DEEPGRAM_API_KEY'),

      // Rate limiting (per PRD Section 3D)
      rateLimitAccountCreationPerHour: int.parse(
        _getEnv('RATE_LIMIT_ACCOUNT_CREATION_PER_HOUR', '3'),
      ),
      rateLimitAuthAttemptsBeforeLockout: int.parse(
        _getEnv('RATE_LIMIT_AUTH_ATTEMPTS_BEFORE_LOCKOUT', '5'),
      ),
      rateLimitAuthLockoutDuration: Duration(
        minutes: int.parse(
          _getEnv('RATE_LIMIT_AUTH_LOCKOUT_MINUTES', '15'),
        ),
      ),

      // Request limits
      maxRequestBodySize: int.parse(
        _getEnv('MAX_REQUEST_BODY_SIZE', '10485760'), // 10MB default
      ),
    );
  }

  /// Create configuration for testing.
  factory Config.forTesting({
    String host = 'localhost',
    int port = 8080,
    String environment = 'test',
    String databaseHost = 'localhost',
    int databasePort = 5432,
    String databaseName = 'boardroom_journal_test',
    String databaseUser = 'postgres',
    String databasePassword = 'test_password',
    int databasePoolSize = 5,
    String jwtSecret = 'test_jwt_secret_key_for_testing_only',
    Duration jwtAccessTokenExpiry = const Duration(minutes: 15),
    Duration jwtRefreshTokenExpiry = const Duration(days: 30),
    String? appleClientId,
    String? appleTeamId,
    String? appleKeyId,
    String? applePrivateKey,
    String? googleClientId,
    String? googleClientSecret,
    String? claudeApiKey,
    String? deepgramApiKey,
    int rateLimitAccountCreationPerHour = 3,
    int rateLimitAuthAttemptsBeforeLockout = 5,
    Duration rateLimitAuthLockoutDuration = const Duration(minutes: 15),
    int maxRequestBodySize = 10485760,
  }) {
    final config = Config._(
      host: host,
      port: port,
      environment: environment,
      databaseHost: databaseHost,
      databasePort: databasePort,
      databaseName: databaseName,
      databaseUser: databaseUser,
      databasePassword: databasePassword,
      databasePoolSize: databasePoolSize,
      jwtSecret: jwtSecret,
      jwtAccessTokenExpiry: jwtAccessTokenExpiry,
      jwtRefreshTokenExpiry: jwtRefreshTokenExpiry,
      appleClientId: appleClientId,
      appleTeamId: appleTeamId,
      appleKeyId: appleKeyId,
      applePrivateKey: applePrivateKey,
      googleClientId: googleClientId,
      googleClientSecret: googleClientSecret,
      claudeApiKey: claudeApiKey,
      deepgramApiKey: deepgramApiKey,
      rateLimitAccountCreationPerHour: rateLimitAccountCreationPerHour,
      rateLimitAuthAttemptsBeforeLockout: rateLimitAuthAttemptsBeforeLockout,
      rateLimitAuthLockoutDuration: rateLimitAuthLockoutDuration,
      maxRequestBodySize: maxRequestBodySize,
    );
    _instance = config;
    return config;
  }

  /// Whether the application is running in production mode.
  bool get isProduction => environment == 'production';

  /// Whether the application is running in development mode.
  bool get isDevelopment => environment == 'development';

  /// Whether the application is running in test mode.
  bool get isTest => environment == 'test';

  /// Database connection string.
  String get databaseUrl =>
      'postgres://$databaseUser:$databasePassword@$databaseHost:$databasePort/$databaseName';

  static String _getEnv(String key, String defaultValue) {
    return Platform.environment[key] ?? defaultValue;
  }

  static String _getEnvRequired(String key) {
    final value = Platform.environment[key];
    if (value == null || value.isEmpty) {
      throw ConfigurationError('Required environment variable $key is not set');
    }
    return value;
  }

  static String? _getEnvOptional(String key) {
    final value = Platform.environment[key];
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// Error thrown when configuration is invalid.
class ConfigurationError implements Exception {
  final String message;

  ConfigurationError(this.message);

  @override
  String toString() => 'ConfigurationError: $message';
}
