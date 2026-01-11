import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/ai/claude_client.dart';

void main() {
  group('ClaudeConfig', () {
    group('constructor', () {
      test('creates with required apiKey', () {
        const config = ClaudeConfig(apiKey: 'test-key');

        expect(config.apiKey, 'test-key');
      });

      test('has correct default values', () {
        const config = ClaudeConfig(apiKey: 'key');

        expect(config.baseUrl, 'https://api.anthropic.com/v1');
        expect(config.defaultModel, 'claude-sonnet-4-5-20250514');
        expect(config.timeout, const Duration(seconds: 60));
        expect(config.maxRetries, 3);
      });

      test('allows custom values', () {
        const config = ClaudeConfig(
          apiKey: 'custom-key',
          baseUrl: 'https://custom.api.com',
          defaultModel: 'custom-model',
          timeout: Duration(seconds: 120),
          maxRetries: 5,
        );

        expect(config.baseUrl, 'https://custom.api.com');
        expect(config.defaultModel, 'custom-model');
        expect(config.timeout, const Duration(seconds: 120));
        expect(config.maxRetries, 5);
      });
    });

    group('sonnet factory', () {
      test('creates config with Sonnet model', () {
        final config = ClaudeConfig.sonnet(apiKey: 'sonnet-key');

        expect(config.apiKey, 'sonnet-key');
        expect(config.defaultModel, 'claude-sonnet-4-5-20250514');
      });

      test('uses default baseUrl and timeout', () {
        final config = ClaudeConfig.sonnet(apiKey: 'key');

        expect(config.baseUrl, 'https://api.anthropic.com/v1');
        expect(config.timeout, const Duration(seconds: 60));
      });
    });

    group('opus factory', () {
      test('creates config with Opus model', () {
        final config = ClaudeConfig.opus(apiKey: 'opus-key');

        expect(config.apiKey, 'opus-key');
        expect(config.defaultModel, 'claude-opus-4-5-20250514');
      });

      test('uses default baseUrl and timeout', () {
        final config = ClaudeConfig.opus(apiKey: 'key');

        expect(config.baseUrl, 'https://api.anthropic.com/v1');
        expect(config.timeout, const Duration(seconds: 60));
      });
    });
  });

  group('ClaudeResponse', () {
    test('creates with required fields', () {
      const response = ClaudeResponse(
        content: 'Hello, world!',
        model: 'claude-sonnet-4-5-20250514',
        inputTokens: 10,
        outputTokens: 5,
      );

      expect(response.content, 'Hello, world!');
      expect(response.model, 'claude-sonnet-4-5-20250514');
      expect(response.inputTokens, 10);
      expect(response.outputTokens, 5);
      expect(response.stopReason, isNull);
    });

    test('creates with stopReason', () {
      const response = ClaudeResponse(
        content: 'Response',
        model: 'model',
        inputTokens: 5,
        outputTokens: 10,
        stopReason: 'end_turn',
      );

      expect(response.stopReason, 'end_turn');
    });

    group('fromJson', () {
      test('parses valid response', () {
        final json = {
          'content': [
            {'type': 'text', 'text': 'Hello from Claude!'},
          ],
          'model': 'claude-sonnet-4-5-20250514',
          'usage': {
            'input_tokens': 100,
            'output_tokens': 50,
          },
          'stop_reason': 'end_turn',
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.content, 'Hello from Claude!');
        expect(response.model, 'claude-sonnet-4-5-20250514');
        expect(response.inputTokens, 100);
        expect(response.outputTokens, 50);
        expect(response.stopReason, 'end_turn');
      });

      test('concatenates multiple text blocks', () {
        final json = {
          'content': [
            {'type': 'text', 'text': 'First part. '},
            {'type': 'text', 'text': 'Second part.'},
          ],
          'model': 'model',
          'usage': {'input_tokens': 10, 'output_tokens': 20},
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.content, 'First part. Second part.');
      });

      test('ignores non-text content blocks', () {
        final json = {
          'content': [
            {'type': 'text', 'text': 'Text content'},
            {'type': 'image', 'data': 'base64...'},
          ],
          'model': 'model',
          'usage': {'input_tokens': 10, 'output_tokens': 20},
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.content, 'Text content');
      });

      test('handles missing usage', () {
        final json = {
          'content': [
            {'type': 'text', 'text': 'Text'},
          ],
          'model': 'model',
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.inputTokens, 0);
        expect(response.outputTokens, 0);
      });

      test('handles missing model', () {
        final json = {
          'content': [
            {'type': 'text', 'text': 'Text'},
          ],
          'usage': {'input_tokens': 10, 'output_tokens': 20},
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.model, '');
      });

      test('handles empty content array', () {
        final json = {
          'content': <dynamic>[],
          'model': 'model',
          'usage': {'input_tokens': 0, 'output_tokens': 0},
        };

        final response = ClaudeResponse.fromJson(json);

        expect(response.content, '');
      });
    });
  });

  group('ClaudeError', () {
    test('creates with required message', () {
      const error = ClaudeError(message: 'Something went wrong');

      expect(error.message, 'Something went wrong');
      expect(error.type, isNull);
      expect(error.statusCode, isNull);
      expect(error.isRetryable, isFalse);
    });

    test('creates with all fields', () {
      const error = ClaudeError(
        message: 'Rate limited',
        type: 'rate_limit_error',
        statusCode: 429,
        isRetryable: true,
      );

      expect(error.message, 'Rate limited');
      expect(error.type, 'rate_limit_error');
      expect(error.statusCode, 429);
      expect(error.isRetryable, isTrue);
    });

    test('implements Exception', () {
      const error = ClaudeError(message: 'Error');

      expect(error, isA<Exception>());
    });

    test('toString formats correctly', () {
      const error = ClaudeError(
        message: 'Test error',
        type: 'test_type',
        statusCode: 400,
      );

      expect(error.toString(), 'ClaudeError: Test error (type: test_type, status: 400)');
    });

    group('fromResponse', () {
      test('parses JSON error response', () {
        final body = jsonEncode({
          'error': {
            'message': 'Invalid API key',
            'type': 'authentication_error',
          },
        });

        final error = ClaudeError.fromResponse(401, body);

        expect(error.message, 'Invalid API key');
        expect(error.type, 'authentication_error');
        expect(error.statusCode, 401);
        expect(error.isRetryable, isFalse);
      });

      test('handles non-JSON response', () {
        const body = 'Internal Server Error';

        final error = ClaudeError.fromResponse(500, body);

        expect(error.message, 'Internal Server Error');
        expect(error.type, isNull);
        expect(error.statusCode, 500);
        expect(error.isRetryable, isTrue);
      });

      test('handles malformed JSON', () {
        const body = '{invalid json}';

        final error = ClaudeError.fromResponse(400, body);

        expect(error.message, '{invalid json}');
        expect(error.statusCode, 400);
      });

      test('handles missing error field in JSON', () {
        final body = jsonEncode({'status': 'error'});

        final error = ClaudeError.fromResponse(400, body);

        expect(error.message, 'Unknown error');
      });
    });

    group('isRetryable status codes', () {
      test('429 is retryable', () {
        final error = ClaudeError.fromResponse(429, '{}');

        expect(error.isRetryable, isTrue);
      });

      test('500 is retryable', () {
        final error = ClaudeError.fromResponse(500, '{}');

        expect(error.isRetryable, isTrue);
      });

      test('502 is retryable', () {
        final error = ClaudeError.fromResponse(502, '{}');

        expect(error.isRetryable, isTrue);
      });

      test('503 is retryable', () {
        final error = ClaudeError.fromResponse(503, '{}');

        expect(error.isRetryable, isTrue);
      });

      test('400 is not retryable', () {
        final error = ClaudeError.fromResponse(400, '{}');

        expect(error.isRetryable, isFalse);
      });

      test('401 is not retryable', () {
        final error = ClaudeError.fromResponse(401, '{}');

        expect(error.isRetryable, isFalse);
      });

      test('403 is not retryable', () {
        final error = ClaudeError.fromResponse(403, '{}');

        expect(error.isRetryable, isFalse);
      });

      test('404 is not retryable', () {
        final error = ClaudeError.fromResponse(404, '{}');

        expect(error.isRetryable, isFalse);
      });
    });
  });

  group('ClaudeClient', () {
    test('creates with config', () {
      const config = ClaudeConfig(apiKey: 'test-key');
      final client = ClaudeClient(config: config);

      expect(client.config, config);
    });

    test('close does not throw', () {
      const config = ClaudeConfig(apiKey: 'test-key');
      final client = ClaudeClient(config: config);

      expect(() => client.close(), returnsNormally);
    });

    // Note: sendMessage tests would require mocking http.Client
    // which is covered in signal_extraction_service_test.dart
  });
}
