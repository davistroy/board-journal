import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:board_journal/data/data.dart';
import 'package:board_journal/services/services.dart';

@GenerateMocks([
  GovernanceSessionRepository,
  BetRepository,
  UserPreferencesRepository,
  VaguenessDetectionService,
  QuickVersionAIService,
])
import 'quick_version_service_test.mocks.dart';

void main() {
  group('QuickVersionState', () {
    test('state machine progression', () {
      // Initial -> SensitivityGate -> Q1 -> Q2 -> Q3 -> Q4 -> Q5 -> GenerateOutput -> Finalized
      expect(QuickVersionState.initial.nextState, QuickVersionState.sensitivityGate);
      expect(QuickVersionState.sensitivityGate.nextState, QuickVersionState.q1RoleContext);
      expect(QuickVersionState.q1RoleContext.nextState, QuickVersionState.q2PaidProblems);
      expect(QuickVersionState.q2PaidProblems.nextState, QuickVersionState.q3DirectionLoop);
      expect(QuickVersionState.q3DirectionLoop.nextState, QuickVersionState.q4AvoidedDecision);
      expect(QuickVersionState.q4AvoidedDecision.nextState, QuickVersionState.q5ComfortWork);
      expect(QuickVersionState.q5ComfortWork.nextState, QuickVersionState.generateOutput);
      expect(QuickVersionState.generateOutput.nextState, QuickVersionState.finalized);
    });

    test('clarify states return to parent question next state', () {
      expect(QuickVersionState.q1Clarify.nextState, QuickVersionState.q2PaidProblems);
      expect(QuickVersionState.q2Clarify.nextState, QuickVersionState.q3DirectionLoop);
      expect(QuickVersionState.q3Clarify.nextState, QuickVersionState.q4AvoidedDecision);
      expect(QuickVersionState.q4Clarify.nextState, QuickVersionState.q5ComfortWork);
      expect(QuickVersionState.q5Clarify.nextState, QuickVersionState.generateOutput);
    });

    test('question states have correct question numbers', () {
      expect(QuickVersionState.q1RoleContext.questionNumber, 1);
      expect(QuickVersionState.q2PaidProblems.questionNumber, 2);
      expect(QuickVersionState.q3DirectionLoop.questionNumber, 3);
      expect(QuickVersionState.q4AvoidedDecision.questionNumber, 4);
      expect(QuickVersionState.q5ComfortWork.questionNumber, 5);
    });

    test('clarify states have same question number as parent', () {
      expect(QuickVersionState.q1Clarify.questionNumber, 1);
      expect(QuickVersionState.q2Clarify.questionNumber, 2);
      expect(QuickVersionState.q3Clarify.questionNumber, 3);
      expect(QuickVersionState.q4Clarify.questionNumber, 4);
      expect(QuickVersionState.q5Clarify.questionNumber, 5);
    });

    test('progress increases through states', () {
      expect(QuickVersionState.initial.progressPercent, 0);
      expect(QuickVersionState.sensitivityGate.progressPercent, 5);
      expect(QuickVersionState.q1RoleContext.progressPercent, lessThan(QuickVersionState.q2PaidProblems.progressPercent));
      expect(QuickVersionState.q2PaidProblems.progressPercent, lessThan(QuickVersionState.q3DirectionLoop.progressPercent));
      expect(QuickVersionState.finalized.progressPercent, 100);
    });

    test('isQuestion identifies question states', () {
      expect(QuickVersionState.q1RoleContext.isQuestion, true);
      expect(QuickVersionState.q2PaidProblems.isQuestion, true);
      expect(QuickVersionState.q3DirectionLoop.isQuestion, true);
      expect(QuickVersionState.q4AvoidedDecision.isQuestion, true);
      expect(QuickVersionState.q5ComfortWork.isQuestion, true);
      expect(QuickVersionState.sensitivityGate.isQuestion, false);
      expect(QuickVersionState.generateOutput.isQuestion, false);
    });

    test('isClarify identifies clarify states', () {
      expect(QuickVersionState.q1Clarify.isClarify, true);
      expect(QuickVersionState.q2Clarify.isClarify, true);
      expect(QuickVersionState.q1RoleContext.isClarify, false);
      expect(QuickVersionState.sensitivityGate.isClarify, false);
    });
  });

  group('QuickVersionSessionData', () {
    test('canSkip returns true when under limit', () {
      const data = QuickVersionSessionData(vaguenessSkipCount: 0);
      expect(data.canSkip, true);

      const data1 = QuickVersionSessionData(vaguenessSkipCount: 1);
      expect(data1.canSkip, true);
    });

    test('canSkip returns false at limit', () {
      const data = QuickVersionSessionData(vaguenessSkipCount: 2);
      expect(data.canSkip, false);
    });

    test('allProblemsEvaluated checks all problems', () {
      const dataEmpty = QuickVersionSessionData(problems: []);
      expect(dataEmpty.allProblemsEvaluated, false);

      final dataPartial = QuickVersionSessionData(
        problems: [
          const IdentifiedProblem(
            name: 'Problem 1',
            aiCheaper: 'No',
            errorCost: 'High',
            trustRequired: 'Yes',
            direction: ProblemDirection.appreciating,
          ),
          const IdentifiedProblem(name: 'Problem 2'),
        ],
      );
      expect(dataPartial.allProblemsEvaluated, false);

      final dataComplete = QuickVersionSessionData(
        problems: [
          const IdentifiedProblem(
            name: 'Problem 1',
            aiCheaper: 'No',
            errorCost: 'High',
            trustRequired: 'Yes',
            direction: ProblemDirection.appreciating,
          ),
          const IdentifiedProblem(
            name: 'Problem 2',
            aiCheaper: 'Yes',
            errorCost: 'Low',
            trustRequired: 'No',
            direction: ProblemDirection.depreciating,
          ),
        ],
      );
      expect(dataComplete.allProblemsEvaluated, true);
    });

    test('serialization round trip', () {
      final data = QuickVersionSessionData(
        currentState: QuickVersionState.q2PaidProblems,
        abstractionMode: true,
        vaguenessSkipCount: 1,
        roleContext: 'Senior Engineer at TechCo',
        problems: [
          const IdentifiedProblem(
            name: 'System Design',
            aiCheaper: 'Not yet',
            direction: ProblemDirection.appreciating,
          ),
        ],
        transcript: [
          const QuickVersionQA(
            question: 'What is your role?',
            answer: 'Senior Engineer',
            state: QuickVersionState.q1RoleContext,
          ),
        ],
      );

      final json = data.toJson();
      final restored = QuickVersionSessionData.fromJson(json);

      expect(restored.currentState, data.currentState);
      expect(restored.abstractionMode, data.abstractionMode);
      expect(restored.vaguenessSkipCount, data.vaguenessSkipCount);
      expect(restored.roleContext, data.roleContext);
      expect(restored.problems.length, data.problems.length);
      expect(restored.problems[0].name, data.problems[0].name);
      expect(restored.transcript.length, data.transcript.length);
    });
  });

  group('IdentifiedProblem', () {
    test('hasDirection returns false when incomplete', () {
      const problem = IdentifiedProblem(name: 'Test');
      expect(problem.hasDirection, false);

      const partial = IdentifiedProblem(
        name: 'Test',
        aiCheaper: 'No',
        errorCost: 'High',
      );
      expect(partial.hasDirection, false);
    });

    test('hasDirection returns true when complete', () {
      const complete = IdentifiedProblem(
        name: 'Test',
        aiCheaper: 'No',
        errorCost: 'High',
        trustRequired: 'Yes',
        direction: ProblemDirection.appreciating,
      );
      expect(complete.hasDirection, true);
    });
  });

  group('QuickVersionService', () {
    late MockGovernanceSessionRepository mockSessionRepo;
    late MockBetRepository mockBetRepo;
    late MockUserPreferencesRepository mockPrefsRepo;
    late MockVaguenessDetectionService mockVaguenessService;
    late MockQuickVersionAIService mockAIService;
    late QuickVersionService service;

    setUp(() {
      mockSessionRepo = MockGovernanceSessionRepository();
      mockBetRepo = MockBetRepository();
      mockPrefsRepo = MockUserPreferencesRepository();
      mockVaguenessService = MockVaguenessDetectionService();
      mockAIService = MockQuickVersionAIService();

      service = QuickVersionService(
        sessionRepository: mockSessionRepo,
        betRepository: mockBetRepo,
        preferencesRepository: mockPrefsRepo,
        vaguenessService: mockVaguenessService,
        aiService: mockAIService,
      );
    });

    test('getQuestionText returns correct questions', () {
      const data = QuickVersionSessionData(
        currentState: QuickVersionState.q1RoleContext,
      );
      expect(service.getQuestionText(data), contains('role'));

      const data2 = QuickVersionSessionData(
        currentState: QuickVersionState.q2PaidProblems,
      );
      expect(service.getQuestionText(data2), contains('3 problems'));

      const data4 = QuickVersionSessionData(
        currentState: QuickVersionState.q4AvoidedDecision,
      );
      expect(service.getQuestionText(data4).toLowerCase(), contains('avoiding'));

      const data5 = QuickVersionSessionData(
        currentState: QuickVersionState.q5ComfortWork,
      );
      expect(service.getQuestionText(data5).toLowerCase(), contains('comfort work'));
    });

    test('getQuestionText for Q3 includes problem name', () {
      final data = QuickVersionSessionData(
        currentState: QuickVersionState.q3DirectionLoop,
        problems: [
          const IdentifiedProblem(name: 'Strategic Planning'),
        ],
        currentProblemIndex: 0,
        currentDirectionSubQuestion: 0,
      );

      final question = service.getQuestionText(data);
      expect(question, contains('Strategic Planning'));
      expect(question.toLowerCase(), contains('ai'));
    });

    test('getQuestionText for clarify states asks for example', () {
      const data = QuickVersionSessionData(
        currentState: QuickVersionState.q1Clarify,
      );
      expect(service.getQuestionText(data).toLowerCase(), contains('concrete example'));
    });
  });

  group('ProblemDirection', () {
    test('displayName returns correct strings', () {
      expect(ProblemDirection.appreciating.displayName, 'Appreciating');
      expect(ProblemDirection.depreciating.displayName, 'Depreciating');
      expect(ProblemDirection.stable.displayName, 'Stable');
    });
  });
}
