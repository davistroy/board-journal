import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Configuration for the Claude API client.
class ClaudeConfig {
  /// API key for authentication.
  final String apiKey;

  /// Base URL for the Claude API.
  final String baseUrl;

  /// Default model to use for requests.
  final String defaultModel;

  /// Request timeout duration.
  final Duration timeout;

  /// Maximum retry attempts for transient failures.
  final int maxRetries;

  const ClaudeConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.defaultModel = 'claude-sonnet-4-5-20250514',
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 3,
  });

  /// Creates a config for Sonnet (daily operations).
  /// Per PRD Section 3A.1: Claude Sonnet 4.5 for daily operations.
  factory ClaudeConfig.sonnet({required String apiKey}) {
    return ClaudeConfig(
      apiKey: apiKey,
      defaultModel: 'claude-sonnet-4-5-20250514',
    );
  }

  /// Creates a config for Opus (governance).
  /// Per PRD Section 3A.1: Claude Opus 4.5 for governance.
  factory ClaudeConfig.opus({required String apiKey}) {
    return ClaudeConfig(
      apiKey: apiKey,
      defaultModel: 'claude-opus-4-5-20250514',
    );
  }
}

/// Response from the Claude API.
class ClaudeResponse {
  /// The generated text content.
  final String content;

  /// Model used for generation.
  final String model;

  /// Input tokens used.
  final int inputTokens;

  /// Output tokens generated.
  final int outputTokens;

  /// Stop reason (end_turn, max_tokens, etc.)
  final String? stopReason;

  const ClaudeResponse({
    required this.content,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.stopReason,
  });

  factory ClaudeResponse.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as List<dynamic>;
    final textContent = content
        .whereType<Map<String, dynamic>>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('');

    final usage = json['usage'] as Map<String, dynamic>? ?? {};

    return ClaudeResponse(
      content: textContent,
      model: json['model'] as String? ?? '',
      inputTokens: usage['input_tokens'] as int? ?? 0,
      outputTokens: usage['output_tokens'] as int? ?? 0,
      stopReason: json['stop_reason'] as String?,
    );
  }
}

/// Error from the Claude API.
class ClaudeError implements Exception {
  final String message;
  final String? type;
  final int? statusCode;
  final bool isRetryable;

  const ClaudeError({
    required this.message,
    this.type,
    this.statusCode,
    this.isRetryable = false,
  });

  factory ClaudeError.fromResponse(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>? ?? {};

      return ClaudeError(
        message: error['message'] as String? ?? 'Unknown error',
        type: error['type'] as String?,
        statusCode: statusCode,
        isRetryable: _isRetryableStatus(statusCode),
      );
    } catch (_) {
      return ClaudeError(
        message: body,
        statusCode: statusCode,
        isRetryable: _isRetryableStatus(statusCode),
      );
    }
  }

  static bool _isRetryableStatus(int statusCode) {
    // Retry on rate limits (429) and server errors (5xx)
    return statusCode == 429 || (statusCode >= 500 && statusCode < 600);
  }

  @override
  String toString() => 'ClaudeError: $message (type: $type, status: $statusCode)';
}

/// Client for interacting with the Claude API.
///
/// Handles authentication, retries, and response parsing.
class ClaudeClient {
  final ClaudeConfig config;
  final http.Client _httpClient;

  ClaudeClient({
    required this.config,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Sends a message to Claude and returns the response.
  ///
  /// [systemPrompt] - The system instructions for Claude.
  /// [userMessage] - The user's message.
  /// [model] - Optional model override.
  /// [maxTokens] - Maximum tokens in response (default 4096).
  Future<ClaudeResponse> sendMessage({
    required String systemPrompt,
    required String userMessage,
    String? model,
    int maxTokens = 4096,
  }) async {
    return _sendWithRetry(
      systemPrompt: systemPrompt,
      userMessage: userMessage,
      model: model ?? config.defaultModel,
      maxTokens: maxTokens,
    );
  }

  Future<ClaudeResponse> _sendWithRetry({
    required String systemPrompt,
    required String userMessage,
    required String model,
    required int maxTokens,
    int attempt = 0,
  }) async {
    try {
      return await _sendRequest(
        systemPrompt: systemPrompt,
        userMessage: userMessage,
        model: model,
        maxTokens: maxTokens,
      );
    } on ClaudeError catch (e) {
      if (e.isRetryable && attempt < config.maxRetries) {
        // Exponential backoff: 1s, 2s, 4s per PRD Section 3E.2
        final delay = Duration(seconds: 1 << attempt);
        await Future.delayed(delay);
        return _sendWithRetry(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
          model: model,
          maxTokens: maxTokens,
          attempt: attempt + 1,
        );
      }
      rethrow;
    }
  }

  Future<ClaudeResponse> _sendRequest({
    required String systemPrompt,
    required String userMessage,
    required String model,
    required int maxTokens,
  }) async {
    final url = Uri.parse('${config.baseUrl}/messages');

    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': userMessage,
        },
      ],
    });

    final response = await _httpClient
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': config.apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: body,
        )
        .timeout(config.timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ClaudeResponse.fromJson(json);
    }

    throw ClaudeError.fromResponse(response.statusCode, response.body);
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
  }
}
