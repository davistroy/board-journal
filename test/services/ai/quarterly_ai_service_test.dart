import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/data/enums/board_role_type.dart';
import 'package:boardroom_journal/data/enums/evidence_type.dart';
import 'package:boardroom_journal/services/ai/claude_client.dart';
import 'package:boardroom_journal/services/ai/quarterly_ai_service.dart';
import 'package:boardroom_journal/services/governance/quarterly_state.dart';

@GenerateMocks([ClaudeClient])
import 'quarterly_ai_service_test.mocks.dart';

void main() {
  group('QuarterlyAIService', () {
    late MockClaudeClient mockClient;
    late QuarterlyAIService service;

    setUp(() {
      mockClient = MockClaudeClient();
      service = QuarterlyAIService(mockClient);
    });

    group('generateTrendDescription', () {
      test('generates description for improving portfolio', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content:
                  'Your portfolio is strengthening with a 10% shift toward appreciating skills.',
            ));

        final result = await service.generateTrendDescription(
          previousAppreciating: 30,
          currentAppreciating: 40,
          previousDepreciating: 50,
          currentDepreciating: 40,
        );

        expect(result, contains('strengthening'));
        verify(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: 128,
        )).called(1);
      });

      test('handles API error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        expect(
          () => service.generateTrendDescription(
            previousAppreciating: 30,
            currentAppreciating: 40,
            previousDepreciating: 50,
            currentDepreciating: 40,
          ),
          throwsA(isA<QuarterlyAIError>()),
        );
      });
    });

    group('generateBoardQuestion', () {
      test('generates question for accountability role', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content:
                  'What specific evidence can you show for your claim about the Q1 deliverable?',
            ));

        final result = await service.generateBoardQuestion(
          roleType: BoardRoleType.accountability,
          personaName: 'Maya Chen',
          anchoredDemand: 'Show me the receipts',
          sessionContext: const QuarterlySessionData(),
        );

        expect(result, contains('evidence'));
        verify(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: 128,
        )).called(1);
      });

      test('falls back to signature question on error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        final result = await service.generateBoardQuestion(
          roleType: BoardRoleType.accountability,
          personaName: 'Maya Chen',
          anchoredDemand: 'Show me the receipts for your commitments',
          sessionContext: const QuarterlySessionData(),
        );

        expect(result, 'Show me the receipts for your commitments');
      });

      test('removes quotes from response', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '"What evidence do you have?"',
            ));

        final result = await service.generateBoardQuestion(
          roleType: BoardRoleType.accountability,
          personaName: 'Maya Chen',
          sessionContext: const QuarterlySessionData(),
        );

        expect(result, 'What evidence do you have?');
        expect(result.startsWith('"'), false);
        expect(result.endsWith('"'), false);
      });
    });

    group('generateReport', () {
      test('generates comprehensive report', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '''
# Quarterly Report

## Executive Summary
This quarter showed strong progress in key areas.

## Bet Evaluation
Previous bet was marked CORRECT.

## Action Items
- Item 1
- Item 2
''',
            ));

        final result = await service.generateReport(
          sessionData: QuarterlySessionData(
            currentState: QuarterlyState.generateReport,
            betEvaluation: BetEvaluation(
              betId: 'bet-1',
              prediction: 'Will be promoted',
              wrongIf: 'Same role by Q2',
              status: BetStatus.correct,
            ),
            newBet: const NewBet(
              prediction: 'Next quarter goal',
              wrongIf: 'Did not achieve',
            ),
          ),
        );

        expect(result, contains('# Quarterly Report'));
        expect(result, contains('Executive Summary'));
        verify(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: 2048,
        )).called(1);
      });

      test('handles API error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        expect(
          () => service.generateReport(
            sessionData: const QuarterlySessionData(),
          ),
          throwsA(isA<QuarterlyAIError>()),
        );
      });
    });

    group('extractEvidence', () {
      test('extracts evidence from text', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '''
[
  {
    "description": "Sent promotion request email",
    "type": "decision",
    "strength": "strong"
  },
  {
    "description": "Manager confirmed in 1:1",
    "type": "proxy",
    "strength": "medium"
  }
]
''',
            ));

        final result = await service.extractEvidence(
          'I sent the promotion request email to my manager. He confirmed it in our 1:1 meeting.',
        );

        expect(result.length, 2);
        expect(result[0].type, EvidenceType.decision);
        expect(result[0].strength, EvidenceStrength.strong);
        expect(result[1].type, EvidenceType.proxy);
        expect(result[1].strength, EvidenceStrength.medium);
      });

      test('returns empty list when no evidence found', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(content: '[]'));

        final result = await service.extractEvidence(
          'I think I might do something eventually.',
        );

        expect(result, isEmpty);
      });

      test('handles markdown code blocks in response', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '''
```json
[
  {
    "description": "Created project document",
    "type": "artifact",
    "strength": "strong"
  }
]
```
''',
            ));

        final result = await service.extractEvidence(
          'I created the project document.',
        );

        expect(result.length, 1);
        expect(result[0].type, EvidenceType.artifact);
      });

      test('returns empty list on API error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        final result = await service.extractEvidence('Some text');

        expect(result, isEmpty);
      });
    });

    group('evaluateEvidenceStrength', () {
      test('returns correct strength for each type', () {
        expect(
          service.evaluateEvidenceStrength(EvidenceType.decision),
          EvidenceStrength.strong,
        );
        expect(
          service.evaluateEvidenceStrength(EvidenceType.artifact),
          EvidenceStrength.strong,
        );
        expect(
          service.evaluateEvidenceStrength(EvidenceType.proxy),
          EvidenceStrength.medium,
        );
        expect(
          service.evaluateEvidenceStrength(EvidenceType.calendar),
          EvidenceStrength.medium,
        );
        expect(
          service.evaluateEvidenceStrength(EvidenceType.none),
          EvidenceStrength.none,
        );
      });
    });
  });

  group('QuarterlyAIError', () {
    test('toString returns formatted message', () {
      const error = QuarterlyAIError('Test error message', isRetryable: true);
      expect(error.toString(), 'QuarterlyAIError: Test error message');
    });

    test('isRetryable defaults to false', () {
      const error = QuarterlyAIError('Test error');
      expect(error.isRetryable, false);
    });
  });
}
