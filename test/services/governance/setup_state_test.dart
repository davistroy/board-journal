import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/enums/board_role_type.dart';
import 'package:boardroom_journal/data/enums/problem_direction.dart';
import 'package:boardroom_journal/services/governance/setup_state.dart';

void main() {
  group('SetupState', () {
    group('enum values', () {
      test('has all expected states', () {
        expect(SetupState.values, contains(SetupState.initial));
        expect(SetupState.values, contains(SetupState.sensitivityGate));
        expect(SetupState.values, contains(SetupState.collectProblem1));
        expect(SetupState.values, contains(SetupState.collectProblem5));
        expect(SetupState.values, contains(SetupState.timeAllocation));
        expect(SetupState.values, contains(SetupState.createCoreRoles));
        expect(SetupState.values, contains(SetupState.createGrowthRoles));
        expect(SetupState.values, contains(SetupState.createPersonas));
        expect(SetupState.values, contains(SetupState.finalized));
        expect(SetupState.values, contains(SetupState.abandoned));
      });
    });

    group('isProblemCollection extension', () {
      test('returns true for problem collection states', () {
        expect(SetupState.collectProblem1.isProblemCollection, isTrue);
        expect(SetupState.collectProblem2.isProblemCollection, isTrue);
        expect(SetupState.collectProblem3.isProblemCollection, isTrue);
        expect(SetupState.collectProblem4.isProblemCollection, isTrue);
        expect(SetupState.collectProblem5.isProblemCollection, isTrue);
      });

      test('returns false for non-collection states', () {
        expect(SetupState.initial.isProblemCollection, isFalse);
        expect(SetupState.validateProblem1.isProblemCollection, isFalse);
        expect(SetupState.timeAllocation.isProblemCollection, isFalse);
      });
    });

    group('isProblemValidation extension', () {
      test('returns true for validation states', () {
        expect(SetupState.validateProblem1.isProblemValidation, isTrue);
        expect(SetupState.validateProblem2.isProblemValidation, isTrue);
        expect(SetupState.validateProblem3.isProblemValidation, isTrue);
        expect(SetupState.validateProblem4.isProblemValidation, isTrue);
        expect(SetupState.validateProblem5.isProblemValidation, isTrue);
      });

      test('returns false for non-validation states', () {
        expect(SetupState.collectProblem1.isProblemValidation, isFalse);
        expect(SetupState.timeAllocation.isProblemValidation, isFalse);
      });
    });

    group('isOptionalProblem extension', () {
      test('returns true for problem 4 and 5 states', () {
        expect(SetupState.collectProblem4.isOptionalProblem, isTrue);
        expect(SetupState.validateProblem4.isOptionalProblem, isTrue);
        expect(SetupState.collectProblem5.isOptionalProblem, isTrue);
        expect(SetupState.validateProblem5.isOptionalProblem, isTrue);
      });

      test('returns false for required problem states', () {
        expect(SetupState.collectProblem1.isOptionalProblem, isFalse);
        expect(SetupState.collectProblem2.isOptionalProblem, isFalse);
        expect(SetupState.collectProblem3.isOptionalProblem, isFalse);
      });
    });

    group('problemIndex extension', () {
      test('returns correct indices for each problem state', () {
        expect(SetupState.collectProblem1.problemIndex, 0);
        expect(SetupState.validateProblem1.problemIndex, 0);
        expect(SetupState.collectProblem2.problemIndex, 1);
        expect(SetupState.validateProblem2.problemIndex, 1);
        expect(SetupState.collectProblem3.problemIndex, 2);
        expect(SetupState.validateProblem3.problemIndex, 2);
        expect(SetupState.collectProblem4.problemIndex, 3);
        expect(SetupState.validateProblem4.problemIndex, 3);
        expect(SetupState.collectProblem5.problemIndex, 4);
        expect(SetupState.validateProblem5.problemIndex, 4);
      });

      test('returns null for non-problem states', () {
        expect(SetupState.initial.problemIndex, isNull);
        expect(SetupState.timeAllocation.problemIndex, isNull);
        expect(SetupState.finalized.problemIndex, isNull);
      });
    });

    group('nextState extension', () {
      test('follows correct flow from initial', () {
        expect(SetupState.initial.nextState, SetupState.sensitivityGate);
        expect(SetupState.sensitivityGate.nextState, SetupState.collectProblem1);
        expect(SetupState.collectProblem1.nextState, SetupState.validateProblem1);
        expect(SetupState.validateProblem1.nextState, SetupState.collectProblem2);
      });

      test('required problems flow to portfolioCompleteness after problem 3', () {
        expect(SetupState.validateProblem3.nextState, SetupState.portfolioCompleteness);
      });

      test('optional problems also flow to portfolioCompleteness', () {
        expect(SetupState.validateProblem4.nextState, SetupState.portfolioCompleteness);
        expect(SetupState.validateProblem5.nextState, SetupState.portfolioCompleteness);
      });

      test('follows correct flow after portfolio', () {
        expect(SetupState.portfolioCompleteness.nextState, SetupState.timeAllocation);
        expect(SetupState.timeAllocation.nextState, SetupState.calculateHealth);
        expect(SetupState.calculateHealth.nextState, SetupState.createCoreRoles);
        expect(SetupState.createCoreRoles.nextState, SetupState.createGrowthRoles);
        expect(SetupState.createGrowthRoles.nextState, SetupState.createPersonas);
        expect(SetupState.createPersonas.nextState, SetupState.defineReSetupTriggers);
        expect(SetupState.defineReSetupTriggers.nextState, SetupState.publishPortfolio);
        expect(SetupState.publishPortfolio.nextState, SetupState.finalized);
      });

      test('terminal states return themselves', () {
        expect(SetupState.finalized.nextState, SetupState.finalized);
        expect(SetupState.abandoned.nextState, SetupState.abandoned);
      });
    });

    group('displayName extension', () {
      test('returns correct display names', () {
        expect(SetupState.initial.displayName, 'Starting');
        expect(SetupState.sensitivityGate.displayName, 'Privacy Settings');
        expect(SetupState.collectProblem1.displayName, 'Problem 1');
        expect(SetupState.portfolioCompleteness.displayName, 'Portfolio Review');
        expect(SetupState.timeAllocation.displayName, 'Time Allocation');
        expect(SetupState.calculateHealth.displayName, 'Portfolio Health');
        expect(SetupState.createCoreRoles.displayName, 'Core Roles');
        expect(SetupState.createGrowthRoles.displayName, 'Growth Roles');
        expect(SetupState.createPersonas.displayName, 'Personas');
        expect(SetupState.defineReSetupTriggers.displayName, 'Triggers');
        expect(SetupState.publishPortfolio.displayName, 'Publishing');
        expect(SetupState.finalized.displayName, 'Complete');
        expect(SetupState.abandoned.displayName, 'Abandoned');
      });
    });

    group('progressPercent extension', () {
      test('starts at 0 and ends at 100', () {
        expect(SetupState.initial.progressPercent, 0);
        expect(SetupState.finalized.progressPercent, 100);
      });

      test('abandoned returns 0', () {
        expect(SetupState.abandoned.progressPercent, 0);
      });

      test('problem states have increasing progress', () {
        expect(SetupState.collectProblem1.progressPercent, 10);
        expect(SetupState.collectProblem2.progressPercent, 20);
        expect(SetupState.collectProblem3.progressPercent, 30);
        expect(SetupState.collectProblem4.progressPercent, 35);
        expect(SetupState.collectProblem5.progressPercent, 40);
      });
    });
  });

  group('TimeAllocationStatus', () {
    test('has all expected values', () {
      expect(TimeAllocationStatus.values, contains(TimeAllocationStatus.valid));
      expect(TimeAllocationStatus.values, contains(TimeAllocationStatus.warning));
      expect(TimeAllocationStatus.values, contains(TimeAllocationStatus.error));
    });

    group('canProceed extension', () {
      test('valid allows proceeding', () {
        expect(TimeAllocationStatus.valid.canProceed, isTrue);
      });

      test('warning allows proceeding', () {
        expect(TimeAllocationStatus.warning.canProceed, isTrue);
      });

      test('error does not allow proceeding', () {
        expect(TimeAllocationStatus.error.canProceed, isFalse);
      });
    });

    group('getMessage extension', () {
      test('valid returns positive message', () {
        final message = TimeAllocationStatus.valid.getMessage(100);
        expect(message, contains('100%'));
        expect(message, contains('good'));
      });

      test('warning returns warning message', () {
        final message = TimeAllocationStatus.warning.getMessage(92);
        expect(message, contains('92%'));
        expect(message, contains('outside the ideal range'));
      });

      test('error returns error message', () {
        final message = TimeAllocationStatus.error.getMessage(80);
        expect(message, contains('80%'));
        expect(message, contains('Must be between'));
      });
    });
  });

  group('SetupProblem', () {
    test('creates with default values', () {
      const problem = SetupProblem();

      expect(problem.name, isNull);
      expect(problem.whatBreaks, isNull);
      expect(problem.scarcitySignals, isEmpty);
      expect(problem.timeAllocationPercent, 0);
    });

    test('creates with all fields', () {
      const problem = SetupProblem(
        name: 'API Design',
        whatBreaks: 'Users cannot access features',
        scarcitySignals: ['Few experts', 'High salaries'],
        evidenceAiCheaper: 'Not yet',
        evidenceErrorCost: 'High',
        evidenceTrustRequired: 'Yes',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Growing demand for APIs',
        timeAllocationPercent: 40,
      );

      expect(problem.name, 'API Design');
      expect(problem.scarcitySignals, hasLength(2));
      expect(problem.timeAllocationPercent, 40);
    });

    group('isComplete', () {
      test('returns false when name is missing', () {
        const problem = SetupProblem(
          whatBreaks: 'Something',
          scarcitySignals: ['Signal 1', 'Signal 2'],
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'High',
          evidenceTrustRequired: 'Yes',
          direction: ProblemDirection.stable,
          directionRationale: 'Reason',
        );

        expect(problem.isComplete, isFalse);
      });

      test('returns false when whatBreaks is missing', () {
        const problem = SetupProblem(
          name: 'Problem',
          scarcitySignals: ['Signal 1', 'Signal 2'],
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'High',
          evidenceTrustRequired: 'Yes',
          direction: ProblemDirection.stable,
          directionRationale: 'Reason',
        );

        expect(problem.isComplete, isFalse);
      });

      test('returns true with scarcity unknown reason', () {
        const problem = SetupProblem(
          name: 'Problem',
          whatBreaks: 'Bad things',
          scarcityUnknownReason: 'New field, hard to measure',
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'High',
          evidenceTrustRequired: 'Yes',
          direction: ProblemDirection.stable,
          directionRationale: 'Reason',
        );

        expect(problem.isComplete, isTrue);
      });

      test('returns true with 2+ scarcity signals', () {
        const problem = SetupProblem(
          name: 'Problem',
          whatBreaks: 'Bad things',
          scarcitySignals: ['Signal 1', 'Signal 2'],
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'High',
          evidenceTrustRequired: 'Yes',
          direction: ProblemDirection.stable,
          directionRationale: 'Reason',
        );

        expect(problem.isComplete, isTrue);
      });
    });

    group('validate', () {
      test('returns empty list for complete problem', () {
        const problem = SetupProblem(
          name: 'Problem',
          whatBreaks: 'Bad things',
          scarcitySignals: ['Signal 1', 'Signal 2'],
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'High',
          evidenceTrustRequired: 'Yes',
          direction: ProblemDirection.stable,
          directionRationale: 'Reason',
        );

        expect(problem.validate(), isEmpty);
      });

      test('returns all errors for empty problem', () {
        const problem = SetupProblem();

        final errors = problem.validate();

        expect(errors, contains('Problem name is required'));
        expect(errors, contains('What breaks if not solved is required'));
        expect(errors, contains(matches('scarcity')));
      });
    });

    test('copyWith creates modified copy', () {
      const original = SetupProblem(name: 'Original');
      final modified = original.copyWith(
        whatBreaks: 'Things break',
        timeAllocationPercent: 25,
      );

      expect(modified.name, 'Original');
      expect(modified.whatBreaks, 'Things break');
      expect(modified.timeAllocationPercent, 25);
    });

    test('JSON roundtrip preserves data', () {
      const original = SetupProblem(
        name: 'Test',
        whatBreaks: 'Stuff',
        scarcitySignals: ['A', 'B'],
        evidenceAiCheaper: 'Yes',
        evidenceErrorCost: 'Low',
        evidenceTrustRequired: 'No',
        direction: ProblemDirection.depreciating,
        directionRationale: 'AI taking over',
        timeAllocationPercent: 30,
      );

      final json = original.toJson();
      final restored = SetupProblem.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.direction, original.direction);
      expect(restored.timeAllocationPercent, original.timeAllocationPercent);
    });
  });

  group('SetupBoardMember', () {
    test('creates with required fields', () {
      const member = SetupBoardMember(
        roleType: BoardRoleType.accountability,
      );

      expect(member.roleType, BoardRoleType.accountability);
      expect(member.isGrowthRole, isFalse);
      expect(member.isActive, isTrue);
    });

    test('creates growth role', () {
      const member = SetupBoardMember(
        roleType: BoardRoleType.portfolioDefender,
        isGrowthRole: true,
      );

      expect(member.isGrowthRole, isTrue);
    });

    group('hasPersona', () {
      test('returns false when persona incomplete', () {
        const member = SetupBoardMember(
          roleType: BoardRoleType.marketReality,
          personaName: 'Alex',
        );

        expect(member.hasPersona, isFalse);
      });

      test('returns true when persona complete', () {
        const member = SetupBoardMember(
          roleType: BoardRoleType.marketReality,
          personaName: 'Alex Chen',
          personaBackground: '15 years in market research',
          personaCommunicationStyle: 'Data-driven and direct',
        );

        expect(member.hasPersona, isTrue);
      });
    });

    test('copyWith creates modified copy', () {
      const original = SetupBoardMember(
        roleType: BoardRoleType.avoidance,
      );

      final modified = original.copyWith(
        anchoredDemand: 'What are you avoiding?',
        personaName: 'Pat',
      );

      expect(modified.roleType, BoardRoleType.avoidance);
      expect(modified.anchoredDemand, 'What are you avoiding?');
      expect(modified.personaName, 'Pat');
    });

    test('JSON roundtrip preserves data', () {
      const original = SetupBoardMember(
        roleType: BoardRoleType.devilsAdvocate,
        isGrowthRole: false,
        isActive: true,
        anchoredProblemId: 'problem-123',
        anchoredProblemIndex: 0,
        anchoredDemand: 'Challenge assumptions',
        personaName: 'Dr. Skeptic',
        personaBackground: 'Philosopher',
        personaCommunicationStyle: 'Socratic questioning',
        personaSignaturePhrase: 'But have you considered...',
      );

      final json = original.toJson();
      final restored = SetupBoardMember.fromJson(json);

      expect(restored.roleType, original.roleType);
      expect(restored.anchoredProblemId, original.anchoredProblemId);
      expect(restored.personaName, original.personaName);
      expect(restored.personaSignaturePhrase, original.personaSignaturePhrase);
    });
  });

  group('SetupPortfolioHealth', () {
    test('creates with default values', () {
      const health = SetupPortfolioHealth();

      expect(health.appreciatingPercent, 0);
      expect(health.depreciatingPercent, 0);
      expect(health.stablePercent, 0);
    });

    test('hasAppreciating returns correct value', () {
      const noAppreciating = SetupPortfolioHealth(appreciatingPercent: 0);
      const hasAppreciating = SetupPortfolioHealth(appreciatingPercent: 30);

      expect(noAppreciating.hasAppreciating, isFalse);
      expect(hasAppreciating.hasAppreciating, isTrue);
    });

    test('copyWith creates modified copy', () {
      const original = SetupPortfolioHealth();
      final modified = original.copyWith(
        appreciatingPercent: 40,
        riskStatement: 'Too much in depreciating',
      );

      expect(modified.appreciatingPercent, 40);
      expect(modified.riskStatement, 'Too much in depreciating');
    });

    test('JSON roundtrip preserves data', () {
      const original = SetupPortfolioHealth(
        appreciatingPercent: 35,
        depreciatingPercent: 25,
        stablePercent: 40,
        riskStatement: 'Risk statement',
        opportunityStatement: 'Opportunity statement',
      );

      final json = original.toJson();
      final restored = SetupPortfolioHealth.fromJson(json);

      expect(restored.appreciatingPercent, original.appreciatingPercent);
      expect(restored.riskStatement, original.riskStatement);
    });
  });

  group('SetupTrigger', () {
    test('creates with required fields', () {
      final trigger = SetupTrigger(
        triggerType: 'annual',
        description: 'Annual review',
        condition: 'One year since last setup',
        recommendedAction: 'Run setup again',
      );

      expect(trigger.triggerType, 'annual');
      expect(trigger.dueAtUtc, isNull);
    });

    test('creates with due date', () {
      final dueDate = DateTime.utc(2026, 4, 1);
      final trigger = SetupTrigger(
        triggerType: 'quarterly',
        description: 'Quarterly check',
        condition: 'Three months',
        recommendedAction: 'Review portfolio',
        dueAtUtc: dueDate,
      );

      expect(trigger.dueAtUtc, dueDate);
    });

    test('JSON roundtrip preserves data', () {
      final original = SetupTrigger(
        triggerType: 'promotion',
        description: 'Promotion trigger',
        condition: 'Role change',
        recommendedAction: 'Re-evaluate problems',
        dueAtUtc: DateTime.utc(2026, 6, 15),
      );

      final json = original.toJson();
      final restored = SetupTrigger.fromJson(json);

      expect(restored.triggerType, original.triggerType);
      expect(restored.description, original.description);
      expect(restored.dueAtUtc, original.dueAtUtc);
    });
  });

  group('SetupSessionData', () {
    test('creates with default values', () {
      const session = SetupSessionData();

      expect(session.currentState, SetupState.initial);
      expect(session.abstractionMode, isFalse);
      expect(session.problems, isEmpty);
      expect(session.boardMembers, isEmpty);
    });

    group('problem count helpers', () {
      test('problemCount returns correct count', () {
        final session = SetupSessionData(
          problems: [
            SetupProblem(name: 'P1'),
            SetupProblem(name: 'P2'),
          ],
        );

        expect(session.problemCount, 2);
      });

      test('hasMinimumProblems requires 3', () {
        final twoProblems = SetupSessionData(
          problems: [SetupProblem(name: 'P1'), SetupProblem(name: 'P2')],
        );
        final threeProblems = SetupSessionData(
          problems: [
            SetupProblem(name: 'P1'),
            SetupProblem(name: 'P2'),
            SetupProblem(name: 'P3'),
          ],
        );

        expect(twoProblems.hasMinimumProblems, isFalse);
        expect(threeProblems.hasMinimumProblems, isTrue);
      });

      test('hasMaximumProblems at 5', () {
        final fourProblems = SetupSessionData(
          problems: List.generate(4, (i) => SetupProblem(name: 'P$i')),
        );
        final fiveProblems = SetupSessionData(
          problems: List.generate(5, (i) => SetupProblem(name: 'P$i')),
        );

        expect(fourProblems.hasMaximumProblems, isFalse);
        expect(fiveProblems.hasMaximumProblems, isTrue);
      });

      test('canAddMoreProblems under 5', () {
        final threeProblems = SetupSessionData(
          problems: List.generate(3, (i) => SetupProblem(name: 'P$i')),
        );
        final fiveProblems = SetupSessionData(
          problems: List.generate(5, (i) => SetupProblem(name: 'P$i')),
        );

        expect(threeProblems.canAddMoreProblems, isTrue);
        expect(fiveProblems.canAddMoreProblems, isFalse);
      });
    });

    group('board member helpers', () {
      test('coreMembers filters non-growth roles', () {
        final session = SetupSessionData(
          boardMembers: [
            SetupBoardMember(roleType: BoardRoleType.accountability),
            SetupBoardMember(roleType: BoardRoleType.marketReality),
            SetupBoardMember(
              roleType: BoardRoleType.portfolioDefender,
              isGrowthRole: true,
            ),
          ],
        );

        expect(session.coreMembers, hasLength(2));
        expect(session.growthMembers, hasLength(1));
      });
    });

    group('hasAppreciatingProblems', () {
      test('returns false when no appreciating problems', () {
        final session = SetupSessionData(
          problems: [
            SetupProblem(name: 'P1', direction: ProblemDirection.stable),
            SetupProblem(name: 'P2', direction: ProblemDirection.depreciating),
          ],
        );

        expect(session.hasAppreciatingProblems, isFalse);
      });

      test('returns true when appreciating problem exists', () {
        final session = SetupSessionData(
          problems: [
            SetupProblem(name: 'P1', direction: ProblemDirection.appreciating),
            SetupProblem(name: 'P2', direction: ProblemDirection.stable),
          ],
        );

        expect(session.hasAppreciatingProblems, isTrue);
      });
    });

    group('validateTimeAllocation', () {
      test('95-105 is valid', () {
        expect(SetupSessionData.validateTimeAllocation(95), TimeAllocationStatus.valid);
        expect(SetupSessionData.validateTimeAllocation(100), TimeAllocationStatus.valid);
        expect(SetupSessionData.validateTimeAllocation(105), TimeAllocationStatus.valid);
      });

      test('90-94 and 106-110 is warning', () {
        expect(SetupSessionData.validateTimeAllocation(90), TimeAllocationStatus.warning);
        expect(SetupSessionData.validateTimeAllocation(94), TimeAllocationStatus.warning);
        expect(SetupSessionData.validateTimeAllocation(106), TimeAllocationStatus.warning);
        expect(SetupSessionData.validateTimeAllocation(110), TimeAllocationStatus.warning);
      });

      test('below 90 or above 110 is error', () {
        expect(SetupSessionData.validateTimeAllocation(89), TimeAllocationStatus.error);
        expect(SetupSessionData.validateTimeAllocation(50), TimeAllocationStatus.error);
        expect(SetupSessionData.validateTimeAllocation(111), TimeAllocationStatus.error);
        expect(SetupSessionData.validateTimeAllocation(150), TimeAllocationStatus.error);
      });
    });

    group('calculateTotalAllocation', () {
      test('sums all problem allocations', () {
        final session = SetupSessionData(
          problems: [
            SetupProblem(name: 'P1', timeAllocationPercent: 30),
            SetupProblem(name: 'P2', timeAllocationPercent: 40),
            SetupProblem(name: 'P3', timeAllocationPercent: 30),
          ],
        );

        expect(session.calculateTotalAllocation(), 100);
      });

      test('returns 0 for empty problems', () {
        const session = SetupSessionData();

        expect(session.calculateTotalAllocation(), 0);
      });
    });

    test('copyWith creates modified copy', () {
      const original = SetupSessionData();
      final modified = original.copyWith(
        currentState: SetupState.timeAllocation,
        abstractionMode: true,
        totalTimeAllocation: 100,
      );

      expect(modified.currentState, SetupState.timeAllocation);
      expect(modified.abstractionMode, isTrue);
      expect(modified.totalTimeAllocation, 100);
    });

    test('JSON roundtrip preserves data', () {
      final original = SetupSessionData(
        currentState: SetupState.createPersonas,
        abstractionMode: true,
        problems: [
          SetupProblem(name: 'Problem 1', timeAllocationPercent: 50),
        ],
        boardMembers: [
          SetupBoardMember(roleType: BoardRoleType.accountability),
        ],
        triggers: [
          SetupTrigger(
            triggerType: 'annual',
            description: 'Annual',
            condition: 'One year',
            recommendedAction: 'Re-setup',
          ),
        ],
        portfolioHealth: SetupPortfolioHealth(appreciatingPercent: 40),
        totalTimeAllocation: 100,
        timeAllocationStatus: TimeAllocationStatus.valid,
      );

      final json = original.toJson();
      final restored = SetupSessionData.fromJson(json);

      expect(restored.currentState, original.currentState);
      expect(restored.abstractionMode, original.abstractionMode);
      expect(restored.problems.length, original.problems.length);
      expect(restored.boardMembers.length, original.boardMembers.length);
      expect(restored.triggers.length, original.triggers.length);
      expect(restored.totalTimeAllocation, original.totalTimeAllocation);
    });
  });
}
