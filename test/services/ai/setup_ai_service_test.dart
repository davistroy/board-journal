import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:board_journal/data/enums/board_role_type.dart';
import 'package:board_journal/data/enums/problem_direction.dart';
import 'package:board_journal/services/ai/claude_client.dart';
import 'package:board_journal/services/ai/setup_ai_service.dart';
import 'package:board_journal/services/governance/setup_state.dart';

@GenerateMocks([ClaudeClient])
import 'setup_ai_service_test.mocks.dart';

void main() {
  group('SetupAIService', () {
    late MockClaudeClient mockClient;
    late SetupAIService service;

    setUp(() {
      mockClient = MockClaudeClient();
      service = SetupAIService(mockClient);
    });

    group('generateHealthStatements', () {
      test('parses valid JSON response', () async {
        const responseJson = '''
{
  "riskStatement": "You are most exposed in depreciating technical skills that may be automated.",
  "opportunityStatement": "Consider investing more in your appreciating strategic planning abilities."
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

        final problems = [
          SetupProblem(
            name: 'Strategic Planning',
            direction: ProblemDirection.appreciating,
            timeAllocationPercent: 40,
          ),
          SetupProblem(
            name: 'Technical Implementation',
            direction: ProblemDirection.depreciating,
            timeAllocationPercent: 60,
          ),
        ];

        final result = await service.generateHealthStatements(
          problems: problems,
          appreciatingPercent: 40,
          depreciatingPercent: 60,
          stablePercent: 0,
        );

        expect(result.riskStatement, contains('exposed'));
        expect(result.opportunityStatement, contains('investing'));
      });

      test('parses JSON with markdown code blocks', () async {
        const responseJson = '''
```json
{
  "riskStatement": "Risk statement here.",
  "opportunityStatement": "Opportunity statement here."
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

        final result = await service.generateHealthStatements(
          problems: [],
          appreciatingPercent: 0,
          depreciatingPercent: 0,
          stablePercent: 100,
        );

        expect(result.riskStatement, isNotEmpty);
        expect(result.opportunityStatement, isNotEmpty);
      });

      test('throws SetupAIError on invalid JSON', () async {
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
          () => service.generateHealthStatements(
            problems: [],
            appreciatingPercent: 0,
            depreciatingPercent: 0,
            stablePercent: 100,
          ),
          throwsA(isA<SetupAIError>()),
        );
      });

      test('throws SetupAIError on API error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenThrow(ClaudeError('API error', isRetryable: true));

        expect(
          () => service.generateHealthStatements(
            problems: [],
            appreciatingPercent: 0,
            depreciatingPercent: 0,
            stablePercent: 100,
          ),
          throwsA(isA<SetupAIError>()),
        );
      });
    });

    group('generateBoardAnchoring', () {
      test('parses valid JSON array response', () async {
        const responseJson = '''
[
  {
    "roleType": "accountability",
    "problemIndex": 0,
    "demand": "What evidence do you have for your strategic planning decisions?"
  },
  {
    "roleType": "marketReality",
    "problemIndex": 1,
    "demand": "How do you validate your technical direction against market trends?"
  }
]
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 100,
            ));

        final problems = [
          const SetupProblem(name: 'Strategic Planning'),
          const SetupProblem(name: 'Technical Leadership'),
        ];

        final result = await service.generateBoardAnchoring(
          problems: problems,
          roles: [BoardRoleType.accountability, BoardRoleType.marketReality],
        );

        expect(result.length, 2);
        expect(result[0].roleType, BoardRoleType.accountability);
        expect(result[0].problemIndex, 0);
        expect(result[0].demand, contains('evidence'));
        expect(result[1].roleType, BoardRoleType.marketReality);
        expect(result[1].problemIndex, 1);
      });

      test('returns fallback anchoring on parse error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: 'Not valid JSON',
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.generateBoardAnchoring(
          problems: [const SetupProblem(name: 'Test')],
          roles: [BoardRoleType.accountability],
        );

        expect(result.length, 1);
        expect(result[0].roleType, BoardRoleType.accountability);
        expect(result[0].problemIndex, 0);
        expect(result[0].demand, isNotEmpty); // Should use signature question
      });
    });

    group('generatePersona', () {
      test('parses valid JSON response', () async {
        const responseJson = '''
{
  "name": "Maya Chen",
  "background": "Former executive coach with 15 years experience in leadership development.",
  "communicationStyle": "Direct and evidence-focused. Always asks for proof.",
  "signaturePhrase": "Show me the receipts."
}
''';

        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: responseJson,
              inputTokens: 100,
              outputTokens: 100,
            ));

        final result = await service.generatePersona(
          roleType: BoardRoleType.accountability,
        );

        expect(result.name, 'Maya Chen');
        expect(result.background, contains('executive coach'));
        expect(result.communicationStyle, contains('Direct'));
        expect(result.signaturePhrase, contains('receipts'));
      });

      test('returns default persona on parse error', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: 'Invalid JSON here',
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.generatePersona(
          roleType: BoardRoleType.accountability,
        );

        // Should return default persona
        expect(result.name, isNotEmpty);
        expect(result.background, isNotEmpty);
        expect(result.communicationStyle, isNotEmpty);
      });

      test('generates persona for each role type', () async {
        for (final roleType in BoardRoleType.values) {
          final defaultName = _getDefaultName(roleType);

          when(mockClient.sendMessage(
            systemPrompt: anyNamed('systemPrompt'),
            userMessage: anyNamed('userMessage'),
            maxTokens: anyNamed('maxTokens'),
          )).thenAnswer((_) async => ClaudeResponse(
                content: 'Invalid', // Force default
                inputTokens: 100,
                outputTokens: 50,
              ));

          final result = await service.generatePersona(roleType: roleType);

          expect(result.name, defaultName,
              reason: 'Role $roleType should have default name');
          expect(result.background, isNotEmpty,
              reason: 'Role $roleType should have background');
          expect(result.communicationStyle, isNotEmpty,
              reason: 'Role $roleType should have communication style');
        }
      });
    });

    group('evaluateDirection', () {
      test('parses valid JSON response', () async {
        const responseJson = '''
{
  "direction": "appreciating",
  "rationale": "AI cannot easily replicate strategic judgment.",
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

        expect(result.direction, 'appreciating');
        expect(result.rationale, contains('AI'));
        expect(result.confidence, 'high');
      });

      test('normalizes direction values', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '''
{
  "direction": "APPRECIATING",
  "rationale": "Test",
  "confidence": "medium"
}
''',
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Test',
          aiCheaper: 'No',
          errorCost: 'High',
          trustRequired: 'Yes',
        );

        expect(result.direction, 'appreciating');
      });

      test('defaults to stable for unknown direction', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: '''
{
  "direction": "unknown_value",
  "rationale": "Test",
  "confidence": "low"
}
''',
              inputTokens: 100,
              outputTokens: 50,
            ));

        final result = await service.evaluateDirection(
          problemName: 'Test',
          aiCheaper: 'Maybe',
          errorCost: 'Medium',
          trustRequired: 'Sometimes',
        );

        expect(result.direction, 'stable');
      });

      test('throws SetupAIError on invalid JSON', () async {
        when(mockClient.sendMessage(
          systemPrompt: anyNamed('systemPrompt'),
          userMessage: anyNamed('userMessage'),
          maxTokens: anyNamed('maxTokens'),
        )).thenAnswer((_) async => ClaudeResponse(
              content: 'Not JSON',
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
          throwsA(isA<SetupAIError>()),
        );
      });
    });
  });

  group('SetupAIError', () {
    test('toString includes message', () {
      const error = SetupAIError('Test error message');
      expect(error.toString(), contains('Test error message'));
    });

    test('isRetryable defaults to false', () {
      const error = SetupAIError('Test');
      expect(error.isRetryable, false);
    });

    test('isRetryable can be set', () {
      const error = SetupAIError('Test', isRetryable: true);
      expect(error.isRetryable, true);
    });
  });

  group('HealthStatements', () {
    test('stores risk and opportunity statements', () {
      const statements = HealthStatements(
        riskStatement: 'You are exposed in X area',
        opportunityStatement: 'Consider investing in Y',
      );

      expect(statements.riskStatement, 'You are exposed in X area');
      expect(statements.opportunityStatement, 'Consider investing in Y');
    });
  });

  group('RoleAnchoring', () {
    test('stores anchoring data', () {
      const anchoring = RoleAnchoring(
        roleType: BoardRoleType.accountability,
        problemIndex: 0,
        demand: 'Show me the evidence',
      );

      expect(anchoring.roleType, BoardRoleType.accountability);
      expect(anchoring.problemIndex, 0);
      expect(anchoring.demand, 'Show me the evidence');
    });

    test('problemIndex can be null', () {
      const anchoring = RoleAnchoring(
        roleType: BoardRoleType.accountability,
        problemIndex: null,
        demand: 'General demand',
      );

      expect(anchoring.problemIndex, null);
    });
  });

  group('GeneratedPersona', () {
    test('stores all persona fields', () {
      const persona = GeneratedPersona(
        name: 'Maya Chen',
        background: 'Executive coach',
        communicationStyle: 'Direct',
        signaturePhrase: 'Show me the receipts',
      );

      expect(persona.name, 'Maya Chen');
      expect(persona.background, 'Executive coach');
      expect(persona.communicationStyle, 'Direct');
      expect(persona.signaturePhrase, 'Show me the receipts');
    });

    test('signaturePhrase can be null', () {
      const persona = GeneratedPersona(
        name: 'Test Name',
        background: 'Test background',
        communicationStyle: 'Test style',
        signaturePhrase: null,
      );

      expect(persona.signaturePhrase, null);
    });
  });

  group('DirectionEvaluation', () {
    test('stores direction evaluation data', () {
      const eval_ = DirectionEvaluation(
        direction: 'appreciating',
        rationale: 'Because AI cannot do this',
        confidence: 'high',
      );

      expect(eval_.direction, 'appreciating');
      expect(eval_.rationale, 'Because AI cannot do this');
      expect(eval_.confidence, 'high');
    });
  });
}

String _getDefaultName(BoardRoleType roleType) {
  switch (roleType) {
    case BoardRoleType.accountability:
      return 'Maya Chen';
    case BoardRoleType.marketReality:
      return 'Marcus Webb';
    case BoardRoleType.avoidance:
      return 'Sarah Blackwell';
    case BoardRoleType.longTermPositioning:
      return 'David Park';
    case BoardRoleType.devilsAdvocate:
      return 'Alexandra Reyes';
    case BoardRoleType.portfolioDefender:
      return 'James Morrison';
    case BoardRoleType.opportunityScout:
      return 'Priya Sharma';
  }
}
