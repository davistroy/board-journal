import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/enums/problem_direction.dart';
import 'package:boardroom_journal/services/governance/quick_version_state.dart';

void main() {
  group('QuickVersionState', () {
    group('enum values', () {
      test('has all expected states', () {
        expect(QuickVersionState.values, contains(QuickVersionState.initial));
        expect(QuickVersionState.values, contains(QuickVersionState.sensitivityGate));
        expect(QuickVersionState.values, contains(QuickVersionState.q1RoleContext));
        expect(QuickVersionState.values, contains(QuickVersionState.q2PaidProblems));
        expect(QuickVersionState.values, contains(QuickVersionState.q3DirectionLoop));
        expect(QuickVersionState.values, contains(QuickVersionState.q4AvoidedDecision));
        expect(QuickVersionState.values, contains(QuickVersionState.q5ComfortWork));
        expect(QuickVersionState.values, contains(QuickVersionState.generateOutput));
        expect(QuickVersionState.values, contains(QuickVersionState.finalized));
        expect(QuickVersionState.values, contains(QuickVersionState.abandoned));
      });

      test('has clarify states for each question', () {
        expect(QuickVersionState.values, contains(QuickVersionState.q1Clarify));
        expect(QuickVersionState.values, contains(QuickVersionState.q2Clarify));
        expect(QuickVersionState.values, contains(QuickVersionState.q3Clarify));
        expect(QuickVersionState.values, contains(QuickVersionState.q4Clarify));
        expect(QuickVersionState.values, contains(QuickVersionState.q5Clarify));
      });
    });

    group('isQuestion extension', () {
      test('returns true for question states', () {
        expect(QuickVersionState.q1RoleContext.isQuestion, isTrue);
        expect(QuickVersionState.q2PaidProblems.isQuestion, isTrue);
        expect(QuickVersionState.q3DirectionLoop.isQuestion, isTrue);
        expect(QuickVersionState.q4AvoidedDecision.isQuestion, isTrue);
        expect(QuickVersionState.q5ComfortWork.isQuestion, isTrue);
      });

      test('returns false for non-question states', () {
        expect(QuickVersionState.initial.isQuestion, isFalse);
        expect(QuickVersionState.sensitivityGate.isQuestion, isFalse);
        expect(QuickVersionState.q1Clarify.isQuestion, isFalse);
        expect(QuickVersionState.generateOutput.isQuestion, isFalse);
        expect(QuickVersionState.finalized.isQuestion, isFalse);
      });
    });

    group('isClarify extension', () {
      test('returns true for clarify states', () {
        expect(QuickVersionState.q1Clarify.isClarify, isTrue);
        expect(QuickVersionState.q2Clarify.isClarify, isTrue);
        expect(QuickVersionState.q3Clarify.isClarify, isTrue);
        expect(QuickVersionState.q4Clarify.isClarify, isTrue);
        expect(QuickVersionState.q5Clarify.isClarify, isTrue);
      });

      test('returns false for non-clarify states', () {
        expect(QuickVersionState.initial.isClarify, isFalse);
        expect(QuickVersionState.q1RoleContext.isClarify, isFalse);
        expect(QuickVersionState.finalized.isClarify, isFalse);
      });
    });

    group('clarifyState extension', () {
      test('returns correct clarify state for each question', () {
        expect(QuickVersionState.q1RoleContext.clarifyState, QuickVersionState.q1Clarify);
        expect(QuickVersionState.q2PaidProblems.clarifyState, QuickVersionState.q2Clarify);
        expect(QuickVersionState.q3DirectionLoop.clarifyState, QuickVersionState.q3Clarify);
        expect(QuickVersionState.q4AvoidedDecision.clarifyState, QuickVersionState.q4Clarify);
        expect(QuickVersionState.q5ComfortWork.clarifyState, QuickVersionState.q5Clarify);
      });

      test('returns null for non-question states', () {
        expect(QuickVersionState.initial.clarifyState, isNull);
        expect(QuickVersionState.sensitivityGate.clarifyState, isNull);
        expect(QuickVersionState.q1Clarify.clarifyState, isNull);
        expect(QuickVersionState.finalized.clarifyState, isNull);
      });
    });

    group('parentQuestionState extension', () {
      test('returns correct parent for each clarify state', () {
        expect(QuickVersionState.q1Clarify.parentQuestionState, QuickVersionState.q1RoleContext);
        expect(QuickVersionState.q2Clarify.parentQuestionState, QuickVersionState.q2PaidProblems);
        expect(QuickVersionState.q3Clarify.parentQuestionState, QuickVersionState.q3DirectionLoop);
        expect(QuickVersionState.q4Clarify.parentQuestionState, QuickVersionState.q4AvoidedDecision);
        expect(QuickVersionState.q5Clarify.parentQuestionState, QuickVersionState.q5ComfortWork);
      });

      test('returns null for non-clarify states', () {
        expect(QuickVersionState.initial.parentQuestionState, isNull);
        expect(QuickVersionState.q1RoleContext.parentQuestionState, isNull);
        expect(QuickVersionState.finalized.parentQuestionState, isNull);
      });
    });

    group('nextState extension', () {
      test('follows correct flow from initial to finalized', () {
        expect(QuickVersionState.initial.nextState, QuickVersionState.sensitivityGate);
        expect(QuickVersionState.sensitivityGate.nextState, QuickVersionState.q1RoleContext);
        expect(QuickVersionState.q1RoleContext.nextState, QuickVersionState.q2PaidProblems);
        expect(QuickVersionState.q2PaidProblems.nextState, QuickVersionState.q3DirectionLoop);
        expect(QuickVersionState.q3DirectionLoop.nextState, QuickVersionState.q4AvoidedDecision);
        expect(QuickVersionState.q4AvoidedDecision.nextState, QuickVersionState.q5ComfortWork);
        expect(QuickVersionState.q5ComfortWork.nextState, QuickVersionState.generateOutput);
        expect(QuickVersionState.generateOutput.nextState, QuickVersionState.finalized);
      });

      test('clarify states return same next state as their parent', () {
        expect(QuickVersionState.q1Clarify.nextState, QuickVersionState.q2PaidProblems);
        expect(QuickVersionState.q2Clarify.nextState, QuickVersionState.q3DirectionLoop);
        expect(QuickVersionState.q3Clarify.nextState, QuickVersionState.q4AvoidedDecision);
        expect(QuickVersionState.q4Clarify.nextState, QuickVersionState.q5ComfortWork);
        expect(QuickVersionState.q5Clarify.nextState, QuickVersionState.generateOutput);
      });

      test('terminal states return themselves', () {
        expect(QuickVersionState.finalized.nextState, QuickVersionState.finalized);
        expect(QuickVersionState.abandoned.nextState, QuickVersionState.abandoned);
      });
    });

    group('displayName extension', () {
      test('returns correct display names', () {
        expect(QuickVersionState.initial.displayName, 'Starting');
        expect(QuickVersionState.sensitivityGate.displayName, 'Privacy Settings');
        expect(QuickVersionState.q1RoleContext.displayName, 'Role Context');
        expect(QuickVersionState.q2PaidProblems.displayName, 'Paid Problems');
        expect(QuickVersionState.q3DirectionLoop.displayName, 'Problem Directions');
        expect(QuickVersionState.q4AvoidedDecision.displayName, 'Avoided Decision');
        expect(QuickVersionState.q5ComfortWork.displayName, 'Comfort Work');
        expect(QuickVersionState.generateOutput.displayName, 'Generating Output');
        expect(QuickVersionState.finalized.displayName, 'Complete');
        expect(QuickVersionState.abandoned.displayName, 'Abandoned');
      });

      test('clarify states share display name with parent', () {
        expect(QuickVersionState.q1Clarify.displayName, 'Role Context');
        expect(QuickVersionState.q2Clarify.displayName, 'Paid Problems');
        expect(QuickVersionState.q3Clarify.displayName, 'Problem Directions');
        expect(QuickVersionState.q4Clarify.displayName, 'Avoided Decision');
        expect(QuickVersionState.q5Clarify.displayName, 'Comfort Work');
      });
    });

    group('questionNumber extension', () {
      test('returns correct question numbers', () {
        expect(QuickVersionState.q1RoleContext.questionNumber, 1);
        expect(QuickVersionState.q2PaidProblems.questionNumber, 2);
        expect(QuickVersionState.q3DirectionLoop.questionNumber, 3);
        expect(QuickVersionState.q4AvoidedDecision.questionNumber, 4);
        expect(QuickVersionState.q5ComfortWork.questionNumber, 5);
      });

      test('clarify states return same question number as parent', () {
        expect(QuickVersionState.q1Clarify.questionNumber, 1);
        expect(QuickVersionState.q2Clarify.questionNumber, 2);
        expect(QuickVersionState.q3Clarify.questionNumber, 3);
        expect(QuickVersionState.q4Clarify.questionNumber, 4);
        expect(QuickVersionState.q5Clarify.questionNumber, 5);
      });

      test('returns 0 for non-question states', () {
        expect(QuickVersionState.initial.questionNumber, 0);
        expect(QuickVersionState.sensitivityGate.questionNumber, 0);
        expect(QuickVersionState.generateOutput.questionNumber, 0);
        expect(QuickVersionState.finalized.questionNumber, 0);
      });
    });

    group('progressPercent extension', () {
      test('starts at 0 and ends at 100', () {
        expect(QuickVersionState.initial.progressPercent, 0);
        expect(QuickVersionState.finalized.progressPercent, 100);
      });

      test('abandoned returns 0', () {
        expect(QuickVersionState.abandoned.progressPercent, 0);
      });

      test('progress increases through flow', () {
        expect(QuickVersionState.sensitivityGate.progressPercent, 5);
        expect(QuickVersionState.q1RoleContext.progressPercent, 15);
        expect(QuickVersionState.q2PaidProblems.progressPercent, 30);
        expect(QuickVersionState.q3DirectionLoop.progressPercent, 50);
        expect(QuickVersionState.q4AvoidedDecision.progressPercent, 70);
        expect(QuickVersionState.q5ComfortWork.progressPercent, 85);
        expect(QuickVersionState.generateOutput.progressPercent, 95);
      });
    });
  });

  group('QuickVersionQA', () {
    test('creates with required fields', () {
      final qa = QuickVersionQA(
        question: 'What is your role?',
        answer: 'I am a software engineer',
        state: QuickVersionState.q1RoleContext,
      );

      expect(qa.question, 'What is your role?');
      expect(qa.answer, 'I am a software engineer');
      expect(qa.state, QuickVersionState.q1RoleContext);
      expect(qa.wasVague, isFalse);
      expect(qa.concreteExample, isNull);
      expect(qa.skipped, isFalse);
      expect(qa.problemIndex, isNull);
    });

    test('creates with optional fields', () {
      final qa = QuickVersionQA(
        question: 'What problems do you solve?',
        answer: 'Various things',
        wasVague: true,
        concreteExample: 'I build user-facing features',
        skipped: false,
        state: QuickVersionState.q2PaidProblems,
        problemIndex: 1,
      );

      expect(qa.wasVague, isTrue);
      expect(qa.concreteExample, 'I build user-facing features');
      expect(qa.problemIndex, 1);
    });

    test('toJson serializes correctly', () {
      final qa = QuickVersionQA(
        question: 'Test question',
        answer: 'Test answer',
        wasVague: true,
        concreteExample: 'Example',
        skipped: true,
        state: QuickVersionState.q3DirectionLoop,
        problemIndex: 2,
      );

      final json = qa.toJson();

      expect(json['question'], 'Test question');
      expect(json['answer'], 'Test answer');
      expect(json['wasVague'], true);
      expect(json['concreteExample'], 'Example');
      expect(json['skipped'], true);
      expect(json['state'], 'q3DirectionLoop');
      expect(json['problemIndex'], 2);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'question': 'From JSON question',
        'answer': 'From JSON answer',
        'wasVague': true,
        'concreteExample': 'JSON example',
        'skipped': false,
        'state': 'q4AvoidedDecision',
        'problemIndex': 0,
      };

      final qa = QuickVersionQA.fromJson(json);

      expect(qa.question, 'From JSON question');
      expect(qa.answer, 'From JSON answer');
      expect(qa.wasVague, isTrue);
      expect(qa.concreteExample, 'JSON example');
      expect(qa.skipped, isFalse);
      expect(qa.state, QuickVersionState.q4AvoidedDecision);
      expect(qa.problemIndex, 0);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'question': 'Minimal question',
        'answer': 'Minimal answer',
        'state': 'q1RoleContext',
      };

      final qa = QuickVersionQA.fromJson(json);

      expect(qa.wasVague, isFalse);
      expect(qa.concreteExample, isNull);
      expect(qa.skipped, isFalse);
      expect(qa.problemIndex, isNull);
    });

    test('fromJson handles unknown state', () {
      final json = {
        'question': 'Question',
        'answer': 'Answer',
        'state': 'unknownState',
      };

      final qa = QuickVersionQA.fromJson(json);

      expect(qa.state, QuickVersionState.initial);
    });
  });

  group('IdentifiedProblem', () {
    test('creates with required field', () {
      final problem = IdentifiedProblem(name: 'Building APIs');

      expect(problem.name, 'Building APIs');
      expect(problem.aiCheaper, isNull);
      expect(problem.errorCost, isNull);
      expect(problem.trustRequired, isNull);
      expect(problem.direction, isNull);
      expect(problem.directionRationale, isNull);
    });

    test('creates with all fields', () {
      final problem = IdentifiedProblem(
        name: 'Building APIs',
        aiCheaper: 'Not really, context matters',
        errorCost: 'High - can break production',
        trustRequired: 'Yes - need domain expertise',
        direction: ProblemDirection.appreciating,
        directionRationale: 'API design requires human judgment',
      );

      expect(problem.direction, ProblemDirection.appreciating);
      expect(problem.directionRationale, 'API design requires human judgment');
    });

    test('hasDirection returns true when all direction fields are set', () {
      final incompleteProblems = [
        IdentifiedProblem(name: 'Test'),
        IdentifiedProblem(name: 'Test', aiCheaper: 'Yes'),
        IdentifiedProblem(name: 'Test', aiCheaper: 'Yes', errorCost: 'Low'),
        IdentifiedProblem(
          name: 'Test',
          aiCheaper: 'Yes',
          errorCost: 'Low',
          trustRequired: 'No',
        ),
      ];

      for (final problem in incompleteProblems) {
        expect(problem.hasDirection, isFalse);
      }

      final completeProblem = IdentifiedProblem(
        name: 'Complete',
        aiCheaper: 'Yes',
        errorCost: 'Low',
        trustRequired: 'No',
        direction: ProblemDirection.depreciating,
      );

      expect(completeProblem.hasDirection, isTrue);
    });

    test('copyWith creates modified copy', () {
      final original = IdentifiedProblem(name: 'Original');
      final modified = original.copyWith(
        aiCheaper: 'No',
        direction: ProblemDirection.stable,
      );

      expect(modified.name, 'Original');
      expect(modified.aiCheaper, 'No');
      expect(modified.direction, ProblemDirection.stable);
      expect(original.aiCheaper, isNull);
    });

    test('toJson serializes correctly', () {
      final problem = IdentifiedProblem(
        name: 'Test Problem',
        aiCheaper: 'No',
        errorCost: 'Medium',
        trustRequired: 'Yes',
        direction: ProblemDirection.stable,
        directionRationale: 'Stable demand',
      );

      final json = problem.toJson();

      expect(json['name'], 'Test Problem');
      expect(json['direction'], 'stable');
      expect(json['directionRationale'], 'Stable demand');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'name': 'From JSON',
        'aiCheaper': 'Maybe',
        'errorCost': 'High',
        'trustRequired': 'Definitely',
        'direction': 'appreciating',
        'directionRationale': 'Growing value',
      };

      final problem = IdentifiedProblem.fromJson(json);

      expect(problem.name, 'From JSON');
      expect(problem.direction, ProblemDirection.appreciating);
    });

    test('fromJson handles unknown direction', () {
      final json = {
        'name': 'Test',
        'direction': 'unknown_direction',
      };

      final problem = IdentifiedProblem.fromJson(json);

      expect(problem.direction, ProblemDirection.stable);
    });
  });

  group('QuickVersionSessionData', () {
    test('creates with default values', () {
      const session = QuickVersionSessionData();

      expect(session.currentState, QuickVersionState.initial);
      expect(session.abstractionMode, isFalse);
      expect(session.vaguenessSkipCount, 0);
      expect(session.transcript, isEmpty);
      expect(session.roleContext, isNull);
      expect(session.problems, isEmpty);
      expect(session.currentProblemIndex, 0);
      expect(session.currentDirectionSubQuestion, 0);
      expect(session.avoidedDecision, isNull);
      expect(session.comfortWork, isNull);
      expect(session.outputMarkdown, isNull);
    });

    group('canSkip', () {
      test('returns true when skip count is less than 2', () {
        const session0 = QuickVersionSessionData(vaguenessSkipCount: 0);
        const session1 = QuickVersionSessionData(vaguenessSkipCount: 1);

        expect(session0.canSkip, isTrue);
        expect(session1.canSkip, isTrue);
      });

      test('returns false when skip count is 2 or more', () {
        const session2 = QuickVersionSessionData(vaguenessSkipCount: 2);
        const session3 = QuickVersionSessionData(vaguenessSkipCount: 3);

        expect(session2.canSkip, isFalse);
        expect(session3.canSkip, isFalse);
      });
    });

    group('allProblemsEvaluated', () {
      test('returns false when no problems', () {
        const session = QuickVersionSessionData();

        expect(session.allProblemsEvaluated, isFalse);
      });

      test('returns false when problems are incomplete', () {
        final session = QuickVersionSessionData(
          problems: [
            IdentifiedProblem(name: 'Problem 1'),
            IdentifiedProblem(
              name: 'Problem 2',
              aiCheaper: 'Yes',
              errorCost: 'Low',
              trustRequired: 'No',
              direction: ProblemDirection.depreciating,
            ),
          ],
        );

        expect(session.allProblemsEvaluated, isFalse);
      });

      test('returns true when all problems have direction', () {
        final session = QuickVersionSessionData(
          problems: [
            IdentifiedProblem(
              name: 'Problem 1',
              aiCheaper: 'Yes',
              errorCost: 'Low',
              trustRequired: 'No',
              direction: ProblemDirection.depreciating,
            ),
            IdentifiedProblem(
              name: 'Problem 2',
              aiCheaper: 'No',
              errorCost: 'High',
              trustRequired: 'Yes',
              direction: ProblemDirection.appreciating,
            ),
          ],
        );

        expect(session.allProblemsEvaluated, isTrue);
      });
    });

    group('currentProblem', () {
      test('returns null when no problems', () {
        const session = QuickVersionSessionData();

        expect(session.currentProblem, isNull);
      });

      test('returns null when index out of bounds', () {
        final session = QuickVersionSessionData(
          problems: [IdentifiedProblem(name: 'Only one')],
          currentProblemIndex: 5,
        );

        expect(session.currentProblem, isNull);
      });

      test('returns correct problem at index', () {
        final session = QuickVersionSessionData(
          problems: [
            IdentifiedProblem(name: 'First'),
            IdentifiedProblem(name: 'Second'),
            IdentifiedProblem(name: 'Third'),
          ],
          currentProblemIndex: 1,
        );

        expect(session.currentProblem?.name, 'Second');
      });
    });

    test('copyWith creates modified copy', () {
      const original = QuickVersionSessionData();
      final modified = original.copyWith(
        currentState: QuickVersionState.q2PaidProblems,
        abstractionMode: true,
        vaguenessSkipCount: 1,
        roleContext: 'Software engineer at startup',
      );

      expect(modified.currentState, QuickVersionState.q2PaidProblems);
      expect(modified.abstractionMode, isTrue);
      expect(modified.vaguenessSkipCount, 1);
      expect(modified.roleContext, 'Software engineer at startup');
      expect(original.currentState, QuickVersionState.initial);
    });

    test('toJson serializes correctly', () {
      final session = QuickVersionSessionData(
        currentState: QuickVersionState.q3DirectionLoop,
        abstractionMode: true,
        vaguenessSkipCount: 1,
        transcript: [
          QuickVersionQA(
            question: 'Q1',
            answer: 'A1',
            state: QuickVersionState.q1RoleContext,
          ),
        ],
        problems: [
          IdentifiedProblem(name: 'Test problem'),
        ],
        currentProblemIndex: 0,
        roleContext: 'Engineer',
        betPrediction: 'I will ship feature X',
        betWrongIf: 'Feature X not shipped',
      );

      final json = session.toJson();

      expect(json['currentState'], 'q3DirectionLoop');
      expect(json['abstractionMode'], true);
      expect(json['vaguenessSkipCount'], 1);
      expect(json['transcript'], isA<List>());
      expect(json['problems'], isA<List>());
      expect(json['roleContext'], 'Engineer');
      expect(json['betPrediction'], 'I will ship feature X');
      expect(json['betWrongIf'], 'Feature X not shipped');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'currentState': 'q5ComfortWork',
        'abstractionMode': true,
        'vaguenessSkipCount': 2,
        'transcript': [
          {
            'question': 'Q1',
            'answer': 'A1',
            'state': 'q1RoleContext',
          },
        ],
        'problems': [
          {'name': 'Problem 1'},
        ],
        'currentProblemIndex': 0,
        'roleContext': 'Manager',
        'avoidedDecision': 'Firing underperformer',
        'comfortWork': 'Email management',
        'assessment': 'Two sentence assessment.',
      };

      final session = QuickVersionSessionData.fromJson(json);

      expect(session.currentState, QuickVersionState.q5ComfortWork);
      expect(session.abstractionMode, isTrue);
      expect(session.vaguenessSkipCount, 2);
      expect(session.transcript, hasLength(1));
      expect(session.problems, hasLength(1));
      expect(session.roleContext, 'Manager');
      expect(session.avoidedDecision, 'Firing underperformer');
      expect(session.comfortWork, 'Email management');
      expect(session.assessment, 'Two sentence assessment.');
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{};

      final session = QuickVersionSessionData.fromJson(json);

      expect(session.currentState, QuickVersionState.initial);
      expect(session.abstractionMode, isFalse);
      expect(session.vaguenessSkipCount, 0);
      expect(session.transcript, isEmpty);
      expect(session.problems, isEmpty);
    });

    test('JSON roundtrip preserves data', () {
      final original = QuickVersionSessionData(
        currentState: QuickVersionState.finalized,
        abstractionMode: true,
        vaguenessSkipCount: 2,
        transcript: [
          QuickVersionQA(
            question: 'Q',
            answer: 'A',
            wasVague: true,
            concreteExample: 'Example',
            state: QuickVersionState.q1RoleContext,
          ),
        ],
        problems: [
          IdentifiedProblem(
            name: 'P1',
            aiCheaper: 'Yes',
            direction: ProblemDirection.depreciating,
          ),
        ],
        roleContext: 'Context',
        avoidedDecision: 'Decision',
        comfortWork: 'Work',
        outputMarkdown: '# Output',
        betPrediction: 'Prediction',
        betWrongIf: 'Wrong if',
        assessment: 'Assessment',
      );

      final json = original.toJson();
      final restored = QuickVersionSessionData.fromJson(json);

      expect(restored.currentState, original.currentState);
      expect(restored.abstractionMode, original.abstractionMode);
      expect(restored.vaguenessSkipCount, original.vaguenessSkipCount);
      expect(restored.transcript.length, original.transcript.length);
      expect(restored.problems.length, original.problems.length);
      expect(restored.roleContext, original.roleContext);
      expect(restored.outputMarkdown, original.outputMarkdown);
      expect(restored.betPrediction, original.betPrediction);
    });
  });
}
