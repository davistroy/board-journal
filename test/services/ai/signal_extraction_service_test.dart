import 'package:boardroom_journal/data/enums/signal_type.dart';
import 'package:boardroom_journal/services/ai/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SignalExtractionService', () {
    late MockClient mockHttpClient;
    late ClaudeClient claudeClient;
    late SignalExtractionService service;

    setUp(() {
      // Default mock that returns a valid response
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "{\\"wins\\": [\\"Completed the project\\"], \\"blockers\\": [\\"Waiting on approval\\"], \\"actions\\": [\\"Follow up tomorrow\\"]}"
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50
  }
}
''',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockHttpClient,
      );

      service = SignalExtractionService(claudeClient);
    });

    test('extracts signals from entry text', () async {
      final signals = await service.extractSignals(
        'Today I completed the project. Still waiting on approval. Will follow up tomorrow.',
      );

      expect(signals.isNotEmpty, isTrue);
      expect(signals.countByType(SignalType.wins), 1);
      expect(signals.countByType(SignalType.blockers), 1);
      expect(signals.countByType(SignalType.actions), 1);
    });

    test('returns empty signals for empty text', () async {
      final signals = await service.extractSignals('');

      expect(signals.isEmpty, isTrue);
    });

    test('returns empty signals for very short text', () async {
      final signals = await service.extractSignals('Hi');

      expect(signals.isEmpty, isTrue);
    });

    test('handles JSON wrapped in markdown code blocks', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "\`\`\`json\\n{\\"wins\\": [\\"Success!\\"]}\\n\`\`\`"
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 100, "output_tokens": 50}
}
''',
          200,
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockHttpClient,
      );
      service = SignalExtractionService(claudeClient);

      final signals = await service.extractSignals(
        'Today I had a great success at work and finished everything.',
      );

      expect(signals.countByType(SignalType.wins), 1);
    });

    test('throws SignalExtractionError on API error', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '{"error": {"type": "invalid_request", "message": "Bad request"}}',
          400,
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key', maxRetries: 0),
        httpClient: mockHttpClient,
      );
      service = SignalExtractionService(claudeClient);

      expect(
        () => service.extractSignals('Some entry text that is long enough'),
        throwsA(isA<SignalExtractionError>()),
      );
    });

    test('throws SignalExtractionError on invalid JSON response', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "This is not valid JSON at all"
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 100, "output_tokens": 50}
}
''',
          200,
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockHttpClient,
      );
      service = SignalExtractionService(claudeClient);

      expect(
        () => service.extractSignals('Some entry text that is long enough'),
        throwsA(isA<SignalExtractionError>()),
      );
    });

    test('handles response with empty signal arrays', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "{\\"wins\\": [], \\"blockers\\": [], \\"risks\\": [], \\"avoidedDecision\\": [], \\"comfortWork\\": [], \\"actions\\": [], \\"learnings\\": []}"
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 100, "output_tokens": 50}
}
''',
          200,
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockHttpClient,
      );
      service = SignalExtractionService(claudeClient);

      final signals = await service.extractSignals(
        'Today was just a regular day with nothing special happening at all.',
      );

      expect(signals.isEmpty, isTrue);
    });

    test('handles all 7 signal types', () async {
      mockHttpClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "{\\"wins\\": [\\"Completed feature\\"], \\"blockers\\": [\\"Waiting on review\\"], \\"risks\\": [\\"Deadline risk\\"], \\"avoidedDecision\\": [\\"Tech choice\\"], \\"comfortWork\\": [\\"Refactoring\\"], \\"actions\\": [\\"Schedule meeting\\"], \\"learnings\\": [\\"New pattern\\"]}"
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 100, "output_tokens": 50}
}
''',
          200,
        );
      });

      claudeClient = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockHttpClient,
      );
      service = SignalExtractionService(claudeClient);

      final signals = await service.extractSignals(
        'Long enough entry text with various content.',
      );

      expect(signals.totalCount, 7);
      expect(signals.countByType(SignalType.wins), 1);
      expect(signals.countByType(SignalType.blockers), 1);
      expect(signals.countByType(SignalType.risks), 1);
      expect(signals.countByType(SignalType.avoidedDecision), 1);
      expect(signals.countByType(SignalType.comfortWork), 1);
      expect(signals.countByType(SignalType.actions), 1);
      expect(signals.countByType(SignalType.learnings), 1);
    });
  });

  group('ClaudeClient', () {
    test('creates Sonnet config', () {
      final config = ClaudeConfig.sonnet(apiKey: 'test-key');

      expect(config.apiKey, 'test-key');
      expect(config.defaultModel, contains('sonnet'));
    });

    test('creates Opus config', () {
      final config = ClaudeConfig.opus(apiKey: 'test-key');

      expect(config.apiKey, 'test-key');
      expect(config.defaultModel, contains('opus'));
    });

    test('retries on rate limit', () async {
      var attempts = 0;
      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts < 2) {
          return http.Response(
            '{"error": {"type": "rate_limit", "message": "Too many requests"}}',
            429,
          );
        }
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "Hello"}],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 10, "output_tokens": 5}
}
''',
          200,
        );
      });

      final client = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key', maxRetries: 3),
        httpClient: mockClient,
      );

      final response = await client.sendMessage(
        systemPrompt: 'You are helpful',
        userMessage: 'Hi',
      );

      expect(attempts, 2);
      expect(response.content, 'Hello');
    });

    test('throws after max retries', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"error": {"type": "rate_limit", "message": "Too many requests"}}',
          429,
        );
      });

      final client = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key', maxRetries: 2),
        httpClient: mockClient,
      );

      expect(
        () => client.sendMessage(
          systemPrompt: 'You are helpful',
          userMessage: 'Hi',
        ),
        throwsA(isA<ClaudeError>()),
      );
    });

    test('parses successful response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '''
{
  "id": "msg_123",
  "type": "message",
  "role": "assistant",
  "content": [{"type": "text", "text": "Hello, how can I help?"}],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {"input_tokens": 15, "output_tokens": 8}
}
''',
          200,
        );
      });

      final client = ClaudeClient(
        config: const ClaudeConfig(apiKey: 'test-key'),
        httpClient: mockClient,
      );

      final response = await client.sendMessage(
        systemPrompt: 'You are helpful',
        userMessage: 'Hi',
      );

      expect(response.content, 'Hello, how can I help?');
      expect(response.model, 'claude-sonnet-4-5-20250514');
      expect(response.inputTokens, 15);
      expect(response.outputTokens, 8);
      expect(response.stopReason, 'end_turn');
    });
  });
}
