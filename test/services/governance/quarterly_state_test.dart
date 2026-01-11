import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/enums/bet_status.dart';
import 'package:boardroom_journal/data/enums/board_role_type.dart';
import 'package:boardroom_journal/data/enums/evidence_type.dart';
import 'package:boardroom_journal/data/enums/problem_direction.dart';
import 'package:boardroom_journal/services/governance/quarterly_state.dart';

void main() {
  group('QuarterlyState', () {
    group('enum values', () {
      test('has all expected states', () {
        expect(QuarterlyState.values, contains(QuarterlyState.initial));
        expect(QuarterlyState.values, contains(QuarterlyState.sensitivityGate));
        expect(QuarterlyState.values, contains(QuarterlyState.gate0Prerequisites));
        expect(QuarterlyState.values, contains(QuarterlyState.q1LastBetEvaluation));
        expect(QuarterlyState.values, contains(QuarterlyState.coreBoardInterrogation));
        expect(QuarterlyState.values, contains(QuarterlyState.growthBoardInterrogation));
        expect(QuarterlyState.values, contains(QuarterlyState.generateReport));
        expect(QuarterlyState.values, contains(QuarterlyState.finalized));
        expect(QuarterlyState.values, contains(QuarterlyState.abandoned));
      });
    });

    group('isQuestion extension', () {
      test('returns true for question states', () {
        expect(QuarterlyState.q1LastBetEvaluation.isQuestion, isTrue);
        expect(QuarterlyState.q2CommitmentsVsActuals.isQuestion, isTrue);
        expect(QuarterlyState.q3AvoidedDecision.isQuestion, isTrue);
        expect(QuarterlyState.q4ComfortWork.isQuestion, isTrue);
        expect(QuarterlyState.q5PortfolioCheck.isQuestion, isTrue);
        expect(QuarterlyState.q6PortfolioHealthUpdate.isQuestion, isTrue);
        expect(QuarterlyState.q10NextBet.isQuestion, isTrue);
        expect(QuarterlyState.coreBoardInterrogation.isQuestion, isTrue);
        expect(QuarterlyState.growthBoardInterrogation.isQuestion, isTrue);
      });

      test('returns false for non-question states', () {
        expect(QuarterlyState.initial.isQuestion, isFalse);
        expect(QuarterlyState.sensitivityGate.isQuestion, isFalse);
        expect(QuarterlyState.q2Clarify.isQuestion, isFalse);
        expect(QuarterlyState.generateReport.isQuestion, isFalse);
      });
    });

    group('isClarify extension', () {
      test('returns true for clarify states', () {
        expect(QuarterlyState.q2Clarify.isClarify, isTrue);
        expect(QuarterlyState.q3Clarify.isClarify, isTrue);
        expect(QuarterlyState.q4Clarify.isClarify, isTrue);
        expect(QuarterlyState.q5Clarify.isClarify, isTrue);
        expect(QuarterlyState.q7Clarify.isClarify, isTrue);
        expect(QuarterlyState.q8Clarify.isClarify, isTrue);
        expect(QuarterlyState.boardInterrogationClarify.isClarify, isTrue);
      });

      test('returns false for non-clarify states', () {
        expect(QuarterlyState.q1LastBetEvaluation.isClarify, isFalse);
        expect(QuarterlyState.coreBoardInterrogation.isClarify, isFalse);
      });
    });

    group('requiresVaguenessCheck extension', () {
      test('returns true for states requiring vagueness check', () {
        expect(QuarterlyState.q2CommitmentsVsActuals.requiresVaguenessCheck, isTrue);
        expect(QuarterlyState.q3AvoidedDecision.requiresVaguenessCheck, isTrue);
        expect(QuarterlyState.q4ComfortWork.requiresVaguenessCheck, isTrue);
        expect(QuarterlyState.q5PortfolioCheck.requiresVaguenessCheck, isTrue);
        expect(QuarterlyState.coreBoardInterrogation.requiresVaguenessCheck, isTrue);
      });

      test('returns false for states not requiring vagueness check', () {
        expect(QuarterlyState.q1LastBetEvaluation.requiresVaguenessCheck, isFalse);
        expect(QuarterlyState.q6PortfolioHealthUpdate.requiresVaguenessCheck, isFalse);
        expect(QuarterlyState.q9TriggerCheck.requiresVaguenessCheck, isFalse);
        expect(QuarterlyState.q10NextBet.requiresVaguenessCheck, isFalse);
      });
    });

    group('clarifyState extension', () {
      test('returns correct clarify state for each question', () {
        expect(QuarterlyState.q2CommitmentsVsActuals.clarifyState, QuarterlyState.q2Clarify);
        expect(QuarterlyState.q3AvoidedDecision.clarifyState, QuarterlyState.q3Clarify);
        expect(QuarterlyState.q4ComfortWork.clarifyState, QuarterlyState.q4Clarify);
        expect(QuarterlyState.q5PortfolioCheck.clarifyState, QuarterlyState.q5Clarify);
        expect(QuarterlyState.coreBoardInterrogation.clarifyState, QuarterlyState.boardInterrogationClarify);
        expect(QuarterlyState.growthBoardInterrogation.clarifyState, QuarterlyState.boardInterrogationClarify);
      });

      test('returns null for non-vagueness-checked states', () {
        expect(QuarterlyState.q1LastBetEvaluation.clarifyState, isNull);
        expect(QuarterlyState.q6PortfolioHealthUpdate.clarifyState, isNull);
        expect(QuarterlyState.initial.clarifyState, isNull);
      });
    });

    group('parentQuestionState extension', () {
      test('returns correct parent for each clarify state', () {
        expect(QuarterlyState.q2Clarify.parentQuestionState, QuarterlyState.q2CommitmentsVsActuals);
        expect(QuarterlyState.q3Clarify.parentQuestionState, QuarterlyState.q3AvoidedDecision);
        expect(QuarterlyState.q4Clarify.parentQuestionState, QuarterlyState.q4ComfortWork);
        expect(QuarterlyState.q5Clarify.parentQuestionState, QuarterlyState.q5PortfolioCheck);
        expect(QuarterlyState.q7Clarify.parentQuestionState, QuarterlyState.q7ProtectionCheck);
        expect(QuarterlyState.q8Clarify.parentQuestionState, QuarterlyState.q8OpportunityCheck);
      });

      test('boardInterrogationClarify returns null (context dependent)', () {
        expect(QuarterlyState.boardInterrogationClarify.parentQuestionState, isNull);
      });
    });

    group('nextState extension', () {
      test('follows correct flow from initial', () {
        expect(QuarterlyState.initial.nextState, QuarterlyState.sensitivityGate);
        expect(QuarterlyState.sensitivityGate.nextState, QuarterlyState.gate0Prerequisites);
        expect(QuarterlyState.gate0Prerequisites.nextState, QuarterlyState.recentReportWarning);
        expect(QuarterlyState.recentReportWarning.nextState, QuarterlyState.q1LastBetEvaluation);
      });

      test('follows correct flow through questions', () {
        expect(QuarterlyState.q1LastBetEvaluation.nextState, QuarterlyState.q2CommitmentsVsActuals);
        expect(QuarterlyState.q2CommitmentsVsActuals.nextState, QuarterlyState.q3AvoidedDecision);
        expect(QuarterlyState.q3AvoidedDecision.nextState, QuarterlyState.q4ComfortWork);
      });

      test('follows correct flow to board interrogation', () {
        expect(QuarterlyState.q10NextBet.nextState, QuarterlyState.coreBoardInterrogation);
        expect(QuarterlyState.coreBoardInterrogation.nextState, QuarterlyState.growthBoardInterrogation);
        expect(QuarterlyState.growthBoardInterrogation.nextState, QuarterlyState.generateReport);
        expect(QuarterlyState.generateReport.nextState, QuarterlyState.finalized);
      });

      test('terminal states return themselves', () {
        expect(QuarterlyState.finalized.nextState, QuarterlyState.finalized);
        expect(QuarterlyState.abandoned.nextState, QuarterlyState.abandoned);
      });
    });

    group('displayName extension', () {
      test('returns correct display names', () {
        expect(QuarterlyState.initial.displayName, 'Starting');
        expect(QuarterlyState.q1LastBetEvaluation.displayName, 'Bet Evaluation');
        expect(QuarterlyState.q2CommitmentsVsActuals.displayName, 'Commitments Review');
        expect(QuarterlyState.coreBoardInterrogation.displayName, 'Core Board Review');
        expect(QuarterlyState.growthBoardInterrogation.displayName, 'Growth Board Review');
        expect(QuarterlyState.finalized.displayName, 'Complete');
      });
    });

    group('questionNumber extension', () {
      test('returns correct question numbers', () {
        expect(QuarterlyState.q1LastBetEvaluation.questionNumber, 1);
        expect(QuarterlyState.q2CommitmentsVsActuals.questionNumber, 2);
        expect(QuarterlyState.q5PortfolioCheck.questionNumber, 5);
        expect(QuarterlyState.q10NextBet.questionNumber, 10);
      });

      test('clarify states return same question number', () {
        expect(QuarterlyState.q2Clarify.questionNumber, 2);
        expect(QuarterlyState.q3Clarify.questionNumber, 3);
      });

      test('returns 0 for non-numbered states', () {
        expect(QuarterlyState.coreBoardInterrogation.questionNumber, 0);
        expect(QuarterlyState.initial.questionNumber, 0);
      });
    });

    group('progressPercent extension', () {
      test('starts at 0 and ends at 100', () {
        expect(QuarterlyState.initial.progressPercent, 0);
        expect(QuarterlyState.finalized.progressPercent, 100);
      });

      test('abandoned returns 0', () {
        expect(QuarterlyState.abandoned.progressPercent, 0);
      });

      test('board interrogation has higher progress', () {
        expect(QuarterlyState.coreBoardInterrogation.progressPercent, 75);
        expect(QuarterlyState.growthBoardInterrogation.progressPercent, 88);
        expect(QuarterlyState.generateReport.progressPercent, 95);
      });
    });
  });

  group('QuarterlyQA', () {
    test('creates with required fields', () {
      final qa = QuarterlyQA(
        question: 'What commitments did you make?',
        answer: 'I committed to shipping feature X',
        state: QuarterlyState.q2CommitmentsVsActuals,
      );

      expect(qa.question, 'What commitments did you make?');
      expect(qa.answer, 'I committed to shipping feature X');
      expect(qa.wasVague, isFalse);
      expect(qa.roleType, isNull);
      expect(qa.personaName, isNull);
    });

    test('creates for board interrogation', () {
      final qa = QuarterlyQA(
        question: 'Show me the proof of your claims',
        answer: 'Here are the metrics...',
        state: QuarterlyState.coreBoardInterrogation,
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
      );

      expect(qa.roleType, BoardRoleType.accountability);
      expect(qa.personaName, 'Maya Chen');
    });

    test('JSON roundtrip preserves data', () {
      final original = QuarterlyQA(
        question: 'Q',
        answer: 'A',
        wasVague: true,
        concreteExample: 'Example',
        state: QuarterlyState.coreBoardInterrogation,
        roleType: BoardRoleType.marketReality,
        personaName: 'Alex',
      );

      final json = original.toJson();
      final restored = QuarterlyQA.fromJson(json);

      expect(restored.question, original.question);
      expect(restored.wasVague, original.wasVague);
      expect(restored.roleType, original.roleType);
      expect(restored.personaName, original.personaName);
    });
  });

  group('BetEvaluation', () {
    test('creates with required fields', () {
      const evaluation = BetEvaluation(
        betId: 'bet-123',
        prediction: 'I will ship feature X by March',
        wrongIf: 'Feature not shipped or delayed past March',
        status: BetStatus.correct,
      );

      expect(evaluation.betId, 'bet-123');
      expect(evaluation.status, BetStatus.correct);
      expect(evaluation.evidence, isEmpty);
    });

    test('creates with evidence', () {
      const evaluation = BetEvaluation(
        betId: 'bet-456',
        prediction: 'Prediction',
        wrongIf: 'Wrong if',
        status: BetStatus.wrong,
        rationale: 'Did not happen because...',
        evidence: [
          QuarterlyEvidence(
            description: 'Feature was not completed',
            type: EvidenceType.artifact,
            strength: EvidenceStrength.strong,
          ),
        ],
      );

      expect(evaluation.rationale, 'Did not happen because...');
      expect(evaluation.evidence, hasLength(1));
    });

    test('copyWith creates modified copy', () {
      const original = BetEvaluation(
        betId: 'bet-1',
        prediction: 'P',
        wrongIf: 'W',
        status: BetStatus.open,
      );

      final modified = original.copyWith(
        status: BetStatus.expired,
        rationale: 'Time passed',
      );

      expect(modified.status, BetStatus.expired);
      expect(modified.rationale, 'Time passed');
      expect(modified.betId, 'bet-1');
    });

    test('JSON roundtrip preserves data', () {
      const original = BetEvaluation(
        betId: 'bet-abc',
        prediction: 'Prediction text',
        wrongIf: 'Wrong if text',
        status: BetStatus.correct,
        rationale: 'Evaluation rationale',
        evidence: [
          QuarterlyEvidence(
            description: 'Evidence 1',
            type: EvidenceType.decision,
            strength: EvidenceStrength.medium,
          ),
        ],
      );

      final json = original.toJson();
      final restored = BetEvaluation.fromJson(json);

      expect(restored.betId, original.betId);
      expect(restored.status, original.status);
      expect(restored.evidence.length, original.evidence.length);
    });
  });

  group('QuarterlyEvidence', () {
    test('creates with required fields', () {
      const evidence = QuarterlyEvidence(
        description: 'Shipped feature X',
        type: EvidenceType.artifact,
        strength: EvidenceStrength.strong,
      );

      expect(evidence.description, 'Shipped feature X');
      expect(evidence.type, EvidenceType.artifact);
      expect(evidence.strength, EvidenceStrength.strong);
      expect(evidence.context, isNull);
    });

    test('JSON roundtrip preserves data', () {
      const original = QuarterlyEvidence(
        description: 'Calendar invite',
        type: EvidenceType.calendar,
        strength: EvidenceStrength.weak,
        context: 'Scheduled meeting',
      );

      final json = original.toJson();
      final restored = QuarterlyEvidence.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.strength, original.strength);
      expect(restored.context, original.context);
    });
  });

  group('DirectionUpdate', () {
    test('creates with required fields', () {
      const update = DirectionUpdate(
        problemId: 'problem-1',
        problemName: 'API Design',
        previousDirection: ProblemDirection.stable,
        newDirection: ProblemDirection.appreciating,
      );

      expect(update.hasChanged, isTrue);
    });

    test('hasChanged returns false when directions match', () {
      const update = DirectionUpdate(
        problemId: 'problem-2',
        problemName: 'Support',
        previousDirection: ProblemDirection.depreciating,
        newDirection: ProblemDirection.depreciating,
      );

      expect(update.hasChanged, isFalse);
    });

    test('JSON roundtrip preserves data', () {
      const original = DirectionUpdate(
        problemId: 'p-1',
        problemName: 'Test',
        previousDirection: ProblemDirection.appreciating,
        newDirection: ProblemDirection.stable,
        rationale: 'Market changed',
      );

      final json = original.toJson();
      final restored = DirectionUpdate.fromJson(json);

      expect(restored.previousDirection, original.previousDirection);
      expect(restored.newDirection, original.newDirection);
      expect(restored.rationale, original.rationale);
    });
  });

  group('AllocationUpdate', () {
    test('creates with required fields', () {
      const update = AllocationUpdate(
        problemId: 'p-1',
        problemName: 'Problem 1',
        previousPercent: 30,
        newPercent: 40,
      );

      expect(update.hasChanged, isTrue);
      expect(update.changeAmount, 10);
    });

    test('hasChanged returns false when percentages match', () {
      const update = AllocationUpdate(
        problemId: 'p-2',
        problemName: 'Problem 2',
        previousPercent: 25,
        newPercent: 25,
      );

      expect(update.hasChanged, isFalse);
      expect(update.changeAmount, 0);
    });

    test('changeAmount can be negative', () {
      const update = AllocationUpdate(
        problemId: 'p-3',
        problemName: 'Problem 3',
        previousPercent: 50,
        newPercent: 30,
      );

      expect(update.changeAmount, -20);
    });

    test('JSON roundtrip preserves data', () {
      const original = AllocationUpdate(
        problemId: 'p-1',
        problemName: 'Test',
        previousPercent: 20,
        newPercent: 35,
      );

      final json = original.toJson();
      final restored = AllocationUpdate.fromJson(json);

      expect(restored.previousPercent, original.previousPercent);
      expect(restored.newPercent, original.newPercent);
    });
  });

  group('HealthTrend', () {
    test('creates with required fields', () {
      const trend = HealthTrend(
        previousAppreciating: 30,
        currentAppreciating: 40,
        previousDepreciating: 30,
        currentDepreciating: 20,
        previousStable: 40,
        currentStable: 40,
      );

      expect(trend.appreciatingChange, 10);
      expect(trend.depreciatingChange, -10);
      expect(trend.stableChange, 0);
    });

    test('JSON roundtrip preserves data', () {
      const original = HealthTrend(
        previousAppreciating: 25,
        currentAppreciating: 35,
        previousDepreciating: 35,
        currentDepreciating: 25,
        previousStable: 40,
        currentStable: 40,
        trendDescription: 'Improving portfolio',
      );

      final json = original.toJson();
      final restored = HealthTrend.fromJson(json);

      expect(restored.appreciatingChange, original.appreciatingChange);
      expect(restored.trendDescription, original.trendDescription);
    });
  });

  group('TriggerStatus', () {
    test('creates with required fields', () {
      const status = TriggerStatus(
        triggerId: 'trigger-1',
        triggerType: 'annual',
        description: 'Annual review',
        isMet: true,
      );

      expect(status.isMet, isTrue);
      expect(status.details, isNull);
    });

    test('JSON roundtrip preserves data', () {
      const original = TriggerStatus(
        triggerId: 't-1',
        triggerType: 'promotion',
        description: 'Role change trigger',
        isMet: false,
        details: 'No promotion this quarter',
      );

      final json = original.toJson();
      final restored = TriggerStatus.fromJson(json);

      expect(restored.isMet, original.isMet);
      expect(restored.details, original.details);
    });
  });

  group('BoardInterrogationResponse', () {
    test('creates with required fields', () {
      const response = BoardInterrogationResponse(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
        question: 'Where is the proof?',
        response: 'Here are the metrics...',
      );

      expect(response.roleType, BoardRoleType.accountability);
      expect(response.wasVague, isFalse);
    });

    test('creates with anchoring info', () {
      const response = BoardInterrogationResponse(
        roleType: BoardRoleType.longTermPositioning,
        personaName: 'Dr. Future',
        anchoredProblemId: 'problem-1',
        anchoredDemand: 'What is your 5-year plan?',
        question: 'How are you positioning for the future?',
        response: 'I am building skills in...',
      );

      expect(response.anchoredProblemId, 'problem-1');
      expect(response.anchoredDemand, isNotNull);
    });

    test('copyWith creates modified copy', () {
      const original = BoardInterrogationResponse(
        roleType: BoardRoleType.avoidance,
        personaName: 'Pat',
        question: 'Q',
        response: 'R',
      );

      final modified = original.copyWith(
        wasVague: true,
        concreteExample: 'More specific...',
      );

      expect(modified.wasVague, isTrue);
      expect(modified.concreteExample, 'More specific...');
      expect(modified.roleType, BoardRoleType.avoidance);
    });

    test('JSON roundtrip preserves data', () {
      const original = BoardInterrogationResponse(
        roleType: BoardRoleType.devilsAdvocate,
        personaName: 'Dr. Skeptic',
        anchoredProblemId: 'p-1',
        anchoredDemand: 'Challenge assumptions',
        question: 'What if you are wrong?',
        response: 'I have considered...',
        wasVague: true,
        concreteExample: 'Specific example',
        skipped: false,
      );

      final json = original.toJson();
      final restored = BoardInterrogationResponse.fromJson(json);

      expect(restored.roleType, original.roleType);
      expect(restored.personaName, original.personaName);
      expect(restored.wasVague, original.wasVague);
      expect(restored.concreteExample, original.concreteExample);
    });
  });

  group('NewBet', () {
    test('creates with required fields', () {
      const bet = NewBet(
        prediction: 'I will ship feature X',
        wrongIf: 'Feature not shipped by deadline',
      );

      expect(bet.durationDays, 90);
    });

    test('allows custom duration', () {
      const bet = NewBet(
        prediction: 'Short term goal',
        wrongIf: 'Not achieved',
        durationDays: 30,
      );

      expect(bet.durationDays, 30);
    });

    test('JSON roundtrip preserves data', () {
      const original = NewBet(
        prediction: 'Prediction text',
        wrongIf: 'Wrong if text',
        durationDays: 60,
      );

      final json = original.toJson();
      final restored = NewBet.fromJson(json);

      expect(restored.prediction, original.prediction);
      expect(restored.wrongIf, original.wrongIf);
      expect(restored.durationDays, original.durationDays);
    });
  });

  group('QuarterlySessionData', () {
    test('creates with default values', () {
      const session = QuarterlySessionData();

      expect(session.currentState, QuarterlyState.initial);
      expect(session.abstractionMode, isFalse);
      expect(session.vaguenessSkipCount, 0);
      expect(session.transcript, isEmpty);
      expect(session.prerequisitesPassed, isFalse);
      expect(session.growthRolesActive, isFalse);
      expect(session.coreBoardResponses, isEmpty);
    });

    group('canSkip', () {
      test('returns true when skip count less than 2', () {
        const session0 = QuarterlySessionData(vaguenessSkipCount: 0);
        const session1 = QuarterlySessionData(vaguenessSkipCount: 1);

        expect(session0.canSkip, isTrue);
        expect(session1.canSkip, isTrue);
      });

      test('returns false when skip count is 2 or more', () {
        const session2 = QuarterlySessionData(vaguenessSkipCount: 2);

        expect(session2.canSkip, isFalse);
      });
    });

    group('allCoreBoardResponded', () {
      test('returns false when less than 5 responses', () {
        final session = QuarterlySessionData(
          coreBoardResponses: List.generate(
            3,
            (i) => BoardInterrogationResponse(
              roleType: BoardRoleType.accountability,
              personaName: 'P$i',
              question: 'Q',
              response: 'R',
            ),
          ),
        );

        expect(session.allCoreBoardResponded, isFalse);
      });

      test('returns true when 5 or more responses', () {
        final session = QuarterlySessionData(
          coreBoardResponses: List.generate(
            5,
            (i) => BoardInterrogationResponse(
              roleType: BoardRoleType.values[i % BoardRoleType.values.length],
              personaName: 'P$i',
              question: 'Q',
              response: 'R',
            ),
          ),
        );

        expect(session.allCoreBoardResponded, isTrue);
      });
    });

    group('allGrowthBoardResponded', () {
      test('returns true when growth roles not active', () {
        const session = QuarterlySessionData(growthRolesActive: false);

        expect(session.allGrowthBoardResponded, isTrue);
      });

      test('returns false when growth roles active but insufficient responses', () {
        final session = QuarterlySessionData(
          growthRolesActive: true,
          growthBoardResponses: [
            BoardInterrogationResponse(
              roleType: BoardRoleType.portfolioDefender,
              personaName: 'P1',
              question: 'Q',
              response: 'R',
            ),
          ],
        );

        expect(session.allGrowthBoardResponded, isFalse);
      });

      test('returns true when growth roles active and 2 responses', () {
        final session = QuarterlySessionData(
          growthRolesActive: true,
          growthBoardResponses: List.generate(
            2,
            (i) => BoardInterrogationResponse(
              roleType: i == 0 ? BoardRoleType.portfolioDefender : BoardRoleType.opportunityScout,
              personaName: 'P$i',
              question: 'Q',
              response: 'R',
            ),
          ),
        );

        expect(session.allGrowthBoardResponded, isTrue);
      });
    });

    test('copyWith creates modified copy', () {
      const original = QuarterlySessionData();
      final modified = original.copyWith(
        currentState: QuarterlyState.q5PortfolioCheck,
        abstractionMode: true,
        prerequisitesPassed: true,
        growthRolesActive: true,
      );

      expect(modified.currentState, QuarterlyState.q5PortfolioCheck);
      expect(modified.abstractionMode, isTrue);
      expect(modified.prerequisitesPassed, isTrue);
      expect(modified.growthRolesActive, isTrue);
    });

    test('JSON roundtrip preserves data', () {
      final original = QuarterlySessionData(
        currentState: QuarterlyState.coreBoardInterrogation,
        abstractionMode: true,
        vaguenessSkipCount: 1,
        transcript: [
          QuarterlyQA(
            question: 'Q1',
            answer: 'A1',
            state: QuarterlyState.q2CommitmentsVsActuals,
          ),
        ],
        prerequisitesPassed: true,
        showedRecentWarning: true,
        daysSinceLastReport: 45,
        betEvaluation: BetEvaluation(
          betId: 'bet-1',
          prediction: 'P',
          wrongIf: 'W',
          status: BetStatus.correct,
        ),
        directionUpdates: [
          DirectionUpdate(
            problemId: 'p-1',
            problemName: 'Problem',
            previousDirection: ProblemDirection.stable,
            newDirection: ProblemDirection.appreciating,
          ),
        ],
        healthTrend: HealthTrend(
          previousAppreciating: 30,
          currentAppreciating: 40,
          previousDepreciating: 30,
          currentDepreciating: 20,
          previousStable: 40,
          currentStable: 40,
        ),
        growthRolesActive: true,
        triggerStatuses: [
          TriggerStatus(
            triggerId: 't-1',
            triggerType: 'annual',
            description: 'Annual',
            isMet: false,
          ),
        ],
        newBet: NewBet(
          prediction: 'New prediction',
          wrongIf: 'Wrong if',
        ),
        coreBoardResponses: [
          BoardInterrogationResponse(
            roleType: BoardRoleType.accountability,
            personaName: 'Maya',
            question: 'Q',
            response: 'R',
          ),
        ],
        currentBoardMemberIndex: 2,
        inBoardClarification: true,
        outputMarkdown: '# Report',
        createdBetId: 'new-bet-id',
      );

      final json = original.toJson();
      final restored = QuarterlySessionData.fromJson(json);

      expect(restored.currentState, original.currentState);
      expect(restored.abstractionMode, original.abstractionMode);
      expect(restored.transcript.length, original.transcript.length);
      expect(restored.prerequisitesPassed, original.prerequisitesPassed);
      expect(restored.daysSinceLastReport, original.daysSinceLastReport);
      expect(restored.betEvaluation?.betId, original.betEvaluation?.betId);
      expect(restored.directionUpdates.length, original.directionUpdates.length);
      expect(restored.healthTrend?.appreciatingChange, original.healthTrend?.appreciatingChange);
      expect(restored.growthRolesActive, original.growthRolesActive);
      expect(restored.triggerStatuses.length, original.triggerStatuses.length);
      expect(restored.newBet?.prediction, original.newBet?.prediction);
      expect(restored.coreBoardResponses.length, original.coreBoardResponses.length);
      expect(restored.currentBoardMemberIndex, original.currentBoardMemberIndex);
      expect(restored.outputMarkdown, original.outputMarkdown);
      expect(restored.createdBetId, original.createdBetId);
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{};

      final session = QuarterlySessionData.fromJson(json);

      expect(session.currentState, QuarterlyState.initial);
      expect(session.transcript, isEmpty);
      expect(session.betEvaluation, isNull);
      expect(session.healthTrend, isNull);
      expect(session.newBet, isNull);
    });
  });
}
