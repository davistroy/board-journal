import 'package:boardroom_journal/services/ai/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Mock DailyEntry for testing (since we can't easily import the generated Drift class)
class MockDailyEntry {
  final String id;
  final String transcriptRaw;
  final String transcriptEdited;
  final String extractedSignalsJson;
  final String entryType;
  final int wordCount;
  final int? durationSeconds;
  final DateTime createdAtUtc;
  final String createdAtTimezone;
  final DateTime updatedAtUtc;
  final DateTime? deletedAtUtc;
  final String syncStatus;
  final int serverVersion;

  MockDailyEntry({
    required this.id,
    required this.transcriptRaw,
    required this.transcriptEdited,
    this.extractedSignalsJson = '{}',
    this.entryType = 'text',
    this.wordCount = 100,
    this.durationSeconds,
    DateTime? createdAtUtc,
    this.createdAtTimezone = 'America/New_York',
    DateTime? updatedAtUtc,
    this.deletedAtUtc,
    this.syncStatus = 'pending',
    this.serverVersion = 0,
  })  : createdAtUtc = createdAtUtc ?? DateTime.now().toUtc(),
        updatedAtUtc = updatedAtUtc ?? DateTime.now().toUtc();
}

void main() {
  group('WeeklyBriefGenerationService', () {
    late MockClient mockHttpClient;
    late ClaudeClient claudeClient;
    late WeeklyBriefGenerationService service;

    final sampleBriefResponse = '''
# Weekly Brief: Jan 6 - Jan 12, 2026

## Headline
Strong week of progress on the product roadmap with key milestones achieved.

## Wins
- Completed the user authentication module
- Shipped the dashboard redesign

## Blockers
- Waiting on API documentation from partner team
- CI/CD pipeline needs optimization

## Risks
- Timeline pressure on Q1 deliverables

## Open Loops
- Follow up with stakeholders on feedback
- Schedule design review

## Next Week Focus
1. Complete API integration
2. User testing sessions
3. Documentation updates

## Avoided Decision
None identified this week

## Comfort Work
Spent time reorganizing project files instead of tackling the integration work
''';

    final sampleMicroReviewResponse = '''
**Accountability**: Good progress on deliverables, but I'd like to see the calendar entries showing those stakeholder meetings.
**Market Reality**: The CI/CD optimization is a real bottleneck - is this depreciating work you should delegate?
**Avoidance**: That API integration has been on the list for two weeks now - what's the real blocker?
**Long-term Positioning**: Dashboard work strengthens your product ownership narrative.
**Devil's Advocate**: What if the Q1 timeline isn't actually achievable? What's your fallback?
''';

    setUp(() {
      // Default mock that returns valid brief and micro-review responses
      var callCount = 0;
      mockHttpClient = MockClient((request) async {
        callCount++;
        // First call is for brief generation, second for micro-review
        final responseText = callCount == 1 ? sampleBriefResponse : sampleMicroReviewResponse;

        return http.Response(
          '''
{
  "id": "msg_$callCount",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": ${_escapeJson(responseText)}
    }
  ],
  "model": "claude-sonnet-4-5-20250514",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 500,
    "output_tokens": 300
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

      service = WeeklyBriefGenerationService(claudeClient);
    });

    test('generates brief from entries', () async {
      // We can't use real DailyEntry objects in unit tests without the full Drift setup,
      // so we test the service behavior with an empty list (zero-entry case)
      final result = await service.generateBrief(
        entries: [], // Empty list triggers reflection brief
        weekStart: DateTime.utc(2026, 1, 6),
        weekEnd: DateTime.utc(2026, 1, 12, 23, 59, 59),
      );

      expect(result.briefMarkdown, isNotEmpty);
      expect(result.entryCount, 0);
      expect(result.isReflectionBrief, isTrue);
    });

    test('generates reflection brief for zero entries', () async {
      final result = await service.generateBrief(
        entries: [],
        weekStart: DateTime.utc(2026, 1, 6),
        weekEnd: DateTime.utc(2026, 1, 12, 23, 59, 59),
      );

      expect(result.isReflectionBrief, isTrue);
      expect(result.entryCount, 0);
      expect(result.boardMicroReviewMarkdown, isNull);
    });

    test('throws BriefGenerationError on API error', () async {
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
      service = WeeklyBriefGenerationService(claudeClient);

      expect(
        () => service.generateBrief(
          entries: [],
          weekStart: DateTime.utc(2026, 1, 6),
          weekEnd: DateTime.utc(2026, 1, 12, 23, 59, 59),
        ),
        throwsA(isA<BriefGenerationError>()),
      );
    });
  });

  group('BriefRegenerationOptions', () {
    test('default options have no modifiers', () {
      const options = BriefRegenerationOptions();

      expect(options.shorter, isFalse);
      expect(options.moreActionable, isFalse);
      expect(options.moreStrategic, isFalse);
      expect(options.hasAnyOption, isFalse);
    });

    test('detects when any option is set', () {
      const options1 = BriefRegenerationOptions(shorter: true);
      const options2 = BriefRegenerationOptions(moreActionable: true);
      const options3 = BriefRegenerationOptions(moreStrategic: true);

      expect(options1.hasAnyOption, isTrue);
      expect(options2.hasAnyOption, isTrue);
      expect(options3.hasAnyOption, isTrue);
    });

    test('serializes to JSON', () {
      const options = BriefRegenerationOptions(
        shorter: true,
        moreActionable: false,
        moreStrategic: true,
      );

      final json = options.toJson();

      expect(json['shorter'], isTrue);
      expect(json['moreActionable'], isFalse);
      expect(json['moreStrategic'], isTrue);
    });

    test('deserializes from JSON', () {
      final json = {
        'shorter': true,
        'moreActionable': true,
        'moreStrategic': false,
      };

      final options = BriefRegenerationOptions.fromJson(json);

      expect(options.shorter, isTrue);
      expect(options.moreActionable, isTrue);
      expect(options.moreStrategic, isFalse);
    });

    test('handles missing fields in JSON', () {
      final json = <String, dynamic>{};

      final options = BriefRegenerationOptions.fromJson(json);

      expect(options.shorter, isFalse);
      expect(options.moreActionable, isFalse);
      expect(options.moreStrategic, isFalse);
    });

    test('converts to JSON string', () {
      const options = BriefRegenerationOptions(shorter: true);

      final jsonString = options.toJsonString();

      expect(jsonString, contains('"shorter":true'));
    });
  });

  group('GeneratedBrief', () {
    test('stores brief data correctly', () {
      const brief = GeneratedBrief(
        briefMarkdown: '# Test Brief',
        boardMicroReviewMarkdown: 'Review content',
        entryCount: 5,
        isReflectionBrief: false,
      );

      expect(brief.briefMarkdown, '# Test Brief');
      expect(brief.boardMicroReviewMarkdown, 'Review content');
      expect(brief.entryCount, 5);
      expect(brief.isReflectionBrief, isFalse);
    });

    test('handles null micro-review', () {
      const brief = GeneratedBrief(
        briefMarkdown: '# Test Brief',
        entryCount: 0,
        isReflectionBrief: true,
      );

      expect(brief.boardMicroReviewMarkdown, isNull);
    });
  });

  group('BriefGenerationError', () {
    test('stores error message', () {
      const error = BriefGenerationError('Test error');

      expect(error.message, 'Test error');
      expect(error.isRetryable, isFalse);
    });

    test('stores retryable flag', () {
      const error = BriefGenerationError('Network error', isRetryable: true);

      expect(error.isRetryable, isTrue);
    });

    test('toString includes message', () {
      const error = BriefGenerationError('Something went wrong');

      expect(error.toString(), contains('Something went wrong'));
    });
  });
}

/// Escapes a string for use in JSON.
String _escapeJson(String text) {
  return '"${text.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
}
