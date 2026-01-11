import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/services/ai/claude_client.dart';
import 'package:boardroom_journal/services/ai/quick_version_ai_service.dart';
import 'package:boardroom_journal/services/governance/quick_version_state.dart';

@GenerateMocks([ClaudeClient])
import 'quick_version_ai_service_test.mocks.dart';

void main() {
  late MockClaudeClient mockClient;
  late QuickVersionAIService service;

  setUp(() {
    mockClient = MockClaudeClient();
    service = QuickVersionAIService(mockClient);
  });

  group('QuickVersionAIService', () {
    group('evaluateDirection', () {
      test('parses valid appreciating direction response', () async {
        const responseJson = '''
{
  "direction": "appreciating",
  "rationale": "Based on your answer that AI cannot easily replicate strategic judgment.",
  "confidence": "high"
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Strategic Planning',
          aiCheaper: 'No, requires human judgment',
          errorCost: 'Very high - impacts entire organization',
          trustRequired: 'Yes, executive access needed',
        );

        expect(result.direction, ProblemDirection.appreciating);
        expect(result.rationale, contains('AI cannot'));
        expect(result.confidence, 'high');
      });

      test('parses valid depreciating direction response', () async {
        const responseJson = '''
{
  "direction": "depreciating",
  "rationale": "AI tools are increasingly capable of this task.",
  "confidence": "medium"
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Data Entry',
          aiCheaper: 'Yes, AI is very good at this',
          errorCost: 'Low - easily correctable',
          trustRequired: 'No special access',
        );

        expect(result.direction, ProblemDirection.depreciating);
        expect(result.confidence, 'medium');
      });

      test('parses stable direction for mixed signals', () async {
        const responseJson = '''
{
  "direction": "stable",
  "rationale": "Mixed signals warrant re-evaluation next quarter.",
  "confidence": "low"
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Project Management',
          aiCheaper: 'Maybe in some areas',
          errorCost: 'Medium',
          trustRequired: 'Sometimes',
        );

        expect(result.direction, ProblemDirection.stable);
        expect(result.confidence, 'low');
      });

      test('handles markdown code blocks in response', () async {
        const responseJson = '''
```json
{
  "direction": "appreciating",
  "rationale": "Test rationale.",
  "confidence": "high"
}
```
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Test',
          aiCheaper: 'No',
          errorCost: 'High',
          trustRequired: 'Yes',
        );

        expect(result.direction, ProblemDirection.appreciating);
      });

      test('defaults to stable for unknown direction value', () async {
        const responseJson = '''
{
  "direction": "unknown_value",
  "rationale": "Test",
  "confidence": "low"
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Test',
          aiCheaper: 'Maybe',
          errorCost: 'Medium',
          trustRequired: 'Sometimes',
        );

        expect(result.direction, ProblemDirection.stable);
      });

      test('throws QuickVersionAIError on invalid JSON', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: 'Not valid JSON',
              inputTokens: 100,
              outputTokens: 50,
            ));

        expect(
          () => service.evaluateDirection(
            problemName: 'Test',
            aiCheaper: 'No',
            errorCost: 'High',
            trustRequired: 'Yes',
          ),
          throwsA(isA<QuickVersionAIError>()),
        );
      });

      test('throws QuickVersionAIError on API error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        expect(
          () => service.evaluateDirection(
            problemName: 'Test',
            aiCheaper: 'No',
            errorCost: 'High',
            trustRequired: 'Yes',
          ),
          throwsA(isA<QuickVersionAIError>()),
        );
      });
    });

    group('generateOutput', () {
      test('parses valid output response', () async {
        const responseJson = '''
{
  "directionTableMarkdown": "| Problem | Direction |\\n|---|---|\\n| Test | Appreciating |",
  "assessment": "You are focused on high-value work. Keep investing in strategic capabilities.",
  "avoidedDecision": "Hiring a deputy",
  "avoidedDecisionCost": "Burnout risk and bottleneck creation",
  "betPrediction": "In 90 days, I will have delegated 3 key responsibilities.",
  "betWrongIf": "Wrong if still handling all strategic decisions alone.",
  "fullOutputMarkdown": "# Quick Audit Results\\n\\nComplete output here."
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 200,
              outputTokens: 300,
            ));

        final sessionData = QuickVersionSessionData(
          currentState: QuickVersionState.generatingOutput,
          roleContext: 'Senior Engineer',
          problems: [
            QuickVersionProblem(name: 'Strategy', timePercent: 50),
          ],
          avoidedDecision: 'Hiring',
          comfortWork: 'Meetings',
        );

        final result = await service.generateOutput(sessionData: sessionData);

        expect(result.assessment, contains('high-value'));
        expect(result.avoidedDecision, 'Hiring a deputy');
        expect(result.betPrediction, contains('90 days'));
        expect(result.betWrongIf, contains('Wrong if'));
      });

      test('throws QuickVersionAIError on API failure', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('Network error', isRetryable: true));

        final sessionData = QuickVersionSessionData(
          currentState: QuickVersionState.generatingOutput,
          roleContext: 'Manager',
          problems: [],
        );

        expect(
          () => service.generateOutput(sessionData: sessionData),
          throwsA(isA<QuickVersionAIError>()),
        );
      });
    });
  });

  group('QuickVersionAIError', () {
    test('toString includes message', () {
      const error = QuickVersionAIError('Test error message');
      expect(error.toString(), contains('Test error message'));
    });

    test('isRetryable defaults to false', () {
      const error = QuickVersionAIError('Test');
      expect(error.isRetryable, false);
    });

    test('isRetryable can be set', () {
      const error = QuickVersionAIError('Test', isRetryable: true);
      expect(error.isRetryable, true);
    });
  });

  group('DirectionEvaluation', () {
    test('stores evaluation data correctly', () {
      const evaluation = DirectionEvaluation(
        direction: ProblemDirection.appreciating,
        rationale: 'AI cannot do this',
        confidence: 'high',
      );

      expect(evaluation.direction, ProblemDirection.appreciating);
      expect(evaluation.rationale, 'AI cannot do this');
      expect(evaluation.confidence, 'high');
    });
  });

  group('QuickVersionOutput', () {
    test('stores output data correctly', () {
      const output = QuickVersionOutput(
        directionTableMarkdown: '| Test |',
        assessment: 'Good progress.',
        avoidedDecision: 'Delegation',
        avoidedDecisionCost: 'Burnout',
        betPrediction: 'Will delegate',
        betWrongIf: 'Still doing everything',
        fullOutputMarkdown: '# Report',
      );

      expect(output.directionTableMarkdown, '| Test |');
      expect(output.assessment, 'Good progress.');
      expect(output.avoidedDecision, 'Delegation');
      expect(output.betPrediction, 'Will delegate');
      expect(output.fullOutputMarkdown, '# Report');
    });
  });
}
