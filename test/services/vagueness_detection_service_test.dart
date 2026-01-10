import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:board_journal/services/ai/claude_client.dart';
import 'package:board_journal/services/ai/vagueness_detection_service.dart';

@GenerateMocks([ClaudeClient])
import 'vagueness_detection_service_test.mocks.dart';

void main() {
  group('VaguenessDetectionService', () {
    late MockClaudeClient mockClient;
    late VaguenessDetectionService service;

    setUp(() {
      mockClient = MockClaudeClient();
      service = VaguenessDetectionService(mockClient);
    });

    group('heuristic detection', () {
      test('very short answers are vague', () async {
        final result = await service.checkVagueness(
          question: 'What is your role?',
          answer: 'ok',
        );
        expect(result.isVague, true);
      });

      test('"none" is not vague for avoided decision', () async {
        final result = await service.checkVagueness(
          question: 'What decision have you been avoiding?',
          answer: 'none',
        );
        expect(result.isVague, false);
      });

      test('"n/a" is not vague', () async {
        final result = await service.checkVagueness(
          question: 'Where are you doing comfort work?',
          answer: 'n/a',
        );
        expect(result.isVague, false);
      });

      test('answers with dates are concrete', () async {
        final result = await service.checkVagueness(
          question: 'What wins did you have this week?',
          answer: 'I shipped the feature on Monday',
        );
        expect(result.isVague, false);
      });

      test('answers with specific verbs are concrete', () async {
        final result = await service.checkVagueness(
          question: 'What did you accomplish?',
          answer: 'Delivered the quarterly report to finance',
        );
        expect(result.isVague, false);
      });

      test('answers with numbers/metrics are concrete', () async {
        final result = await service.checkVagueness(
          question: 'What was the impact?',
          answer: 'Reduced load time by 40% and improved conversion',
        );
        expect(result.isVague, false);
      });

      test('answers with vague words trigger detection', () async {
        // This tests the heuristic - should detect vague words
        final result = await service.checkVagueness(
          question: 'What did you work on?',
          answer: 'Worked on various stuff and things',
        );
        expect(result.isVague, true);
      });

      test('answers with "helped" and no specifics are vague', () async {
        final result = await service.checkVagueness(
          question: 'What did you accomplish?',
          answer: 'Helped the team with some issues',
        );
        expect(result.isVague, true);
      });

      test('answers with "a lot" and no specifics are vague', () async {
        final result = await service.checkVagueness(
          question: 'What blocked you?',
          answer: 'There were a lot of meetings and stuff',
        );
        expect(result.isVague, true);
      });
    });

    group('AI-assisted detection', () {
      test('calls AI for ambiguous cases', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => const ClaudeResponse(
          content: '{"isVague": false, "reason": "Contains specifics", "missingElements": []}',
          model: 'claude-opus-4-5-20250514',
          inputTokens: 100,
          outputTokens: 50,
        ));

        // An answer that's not clearly vague or concrete by heuristics
        final result = await service.checkVagueness(
          question: 'What is your strategy?',
          answer: 'Focus on building relationships with stakeholders',
        );

        // Should have called AI since heuristics are inconclusive
        verify(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).called(1);
      });

      test('handles AI errors gracefully', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(const ClaudeError(
          message: 'API error',
          statusCode: 500,
          isRetryable: true,
        ));

        // Should return concrete (not vague) on error to not block user
        final result = await service.checkVagueness(
          question: 'What is your strategy?',
          answer: 'Focus on building relationships with stakeholders',
        );

        expect(result.isVague, false);
        expect(result.reason, contains('error'));
      });

      test('parses AI response correctly', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => const ClaudeResponse(
          content: '''
{
  "isVague": true,
  "reason": "No specific project or timeline mentioned",
  "missingElements": ["project name", "timeline", "stakeholder"]
}
''',
          model: 'claude-opus-4-5-20250514',
          inputTokens: 100,
          outputTokens: 50,
        ));

        final result = await service.checkVagueness(
          question: 'What are you working on?',
          answer: 'Just doing some strategy work',
        );

        expect(result.isVague, true);
        expect(result.reason, contains('No specific'));
        expect(result.missingElements, contains('project name'));
      });

      test('handles markdown code blocks in response', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => const ClaudeResponse(
          content: '''```json
{"isVague": false, "reason": "Contains specifics", "missingElements": []}
```''',
          model: 'claude-opus-4-5-20250514',
          inputTokens: 100,
          outputTokens: 50,
        ));

        final result = await service.checkVagueness(
          question: 'What did you do?',
          answer: 'Met with Sarah on Tuesday about Q1 planning',
        );

        expect(result.isVague, false);
      });
    });
  });

  group('VaguenessResult', () {
    test('toString includes all fields', () {
      const result = VaguenessResult(
        isVague: true,
        reason: 'Too generic',
        missingElements: ['project', 'timeline'],
      );

      final str = result.toString();
      expect(str, contains('isVague: true'));
      expect(str, contains('Too generic'));
    });
  });
}
