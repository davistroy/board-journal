import 'dart:io';

/// Configuration for AI services.
///
/// Reads API keys from environment variables or a config file.
/// For development, create a `.env` file in the project root:
/// ```
/// ANTHROPIC_API_KEY=your-api-key-here
/// ```
class AIConfig {
  /// Anthropic API key for Claude.
  final String anthropicApiKey;

  const AIConfig({
    required this.anthropicApiKey,
  });

  /// Whether the config is valid (has required keys).
  bool get isValid => anthropicApiKey.isNotEmpty;

  /// Loads config from environment variables.
  ///
  /// Checks in order:
  /// 1. ANTHROPIC_API_KEY environment variable
  /// 2. Falls back to empty string (service will fail gracefully)
  factory AIConfig.fromEnvironment() {
    return AIConfig(
      anthropicApiKey: Platform.environment['ANTHROPIC_API_KEY'] ?? '',
    );
  }

  /// Creates a config with the given API key.
  factory AIConfig.withKey(String apiKey) {
    return AIConfig(anthropicApiKey: apiKey);
  }

  /// Creates a mock config for testing.
  factory AIConfig.mock() {
    return const AIConfig(anthropicApiKey: 'mock-api-key');
  }
}
