import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/services/services.dart';

@GenerateMocks([
  GovernanceSessionRepository,
  ProblemRepository,
  BoardMemberRepository,
  PortfolioHealthRepository,
  PortfolioVersionRepository,
  ReSetupTriggerRepository,
  UserPreferencesRepository,
  SetupAIService,
])
import 'setup_service_test.mocks.dart';

void main() {
  group('SetupState', () {
    test('state machine progression', () {
      // Initial -> SensitivityGate -> CollectProblem1 -> ValidateProblem1 -> ...
      expect(SetupState.initial.nextState, SetupState.sensitivityGate);
      expect(SetupState.sensitivityGate.nextState, SetupState.collectProblem1);
      expect(SetupState.collectProblem1.nextState, SetupState.validateProblem1);
      expect(SetupState.validateProblem1.nextState, SetupState.collectProblem2);
      expect(SetupState.collectProblem2.nextState, SetupState.validateProblem2);
      expect(SetupState.validateProblem2.nextState, SetupState.collectProblem3);
      expect(SetupState.collectProblem3.nextState, SetupState.validateProblem3);
      expect(SetupState.validateProblem3.nextState,
          SetupState.portfolioCompleteness);
    });

    test('optional problem states advance to portfolio completeness', () {
      expect(SetupState.collectProblem4.nextState, SetupState.validateProblem4);
      expect(SetupState.validateProblem4.nextState,
          SetupState.portfolioCompleteness);
      expect(SetupState.collectProblem5.nextState, SetupState.validateProblem5);
      expect(SetupState.validateProblem5.nextState,
          SetupState.portfolioCompleteness);
    });

    test('final state progression', () {
      expect(SetupState.portfolioCompleteness.nextState,
          SetupState.timeAllocation);
      expect(SetupState.timeAllocation.nextState, SetupState.calculateHealth);
      expect(SetupState.calculateHealth.nextState, SetupState.createCoreRoles);
      expect(SetupState.createCoreRoles.nextState, SetupState.createGrowthRoles);
      expect(SetupState.createGrowthRoles.nextState, SetupState.createPersonas);
      expect(SetupState.createPersonas.nextState,
          SetupState.defineReSetupTriggers);
      expect(SetupState.defineReSetupTriggers.nextState,
          SetupState.publishPortfolio);
      expect(SetupState.publishPortfolio.nextState, SetupState.finalized);
    });

    test('finalized and abandoned states stay put', () {
      expect(SetupState.finalized.nextState, SetupState.finalized);
      expect(SetupState.abandoned.nextState, SetupState.abandoned);
    });

    test('isProblemCollection identifies correct states', () {
      expect(SetupState.collectProblem1.isProblemCollection, true);
      expect(SetupState.collectProblem2.isProblemCollection, true);
      expect(SetupState.collectProblem3.isProblemCollection, true);
      expect(SetupState.collectProblem4.isProblemCollection, true);
      expect(SetupState.collectProblem5.isProblemCollection, true);
      expect(SetupState.validateProblem1.isProblemCollection, false);
      expect(SetupState.sensitivityGate.isProblemCollection, false);
    });

    test('isProblemValidation identifies correct states', () {
      expect(SetupState.validateProblem1.isProblemValidation, true);
      expect(SetupState.validateProblem2.isProblemValidation, true);
      expect(SetupState.validateProblem3.isProblemValidation, true);
      expect(SetupState.validateProblem4.isProblemValidation, true);
      expect(SetupState.validateProblem5.isProblemValidation, true);
      expect(SetupState.collectProblem1.isProblemValidation, false);
    });

    test('isOptionalProblem identifies correct states', () {
      expect(SetupState.collectProblem4.isOptionalProblem, true);
      expect(SetupState.validateProblem4.isOptionalProblem, true);
      expect(SetupState.collectProblem5.isOptionalProblem, true);
      expect(SetupState.validateProblem5.isOptionalProblem, true);
      expect(SetupState.collectProblem3.isOptionalProblem, false);
      expect(SetupState.validateProblem3.isOptionalProblem, false);
    });

    test('problemIndex returns correct index', () {
      expect(SetupState.collectProblem1.problemIndex, 0);
      expect(SetupState.validateProblem1.problemIndex, 0);
      expect(SetupState.collectProblem2.problemIndex, 1);
      expect(SetupState.validateProblem2.problemIndex, 1);
      expect(SetupState.collectProblem3.problemIndex, 2);
      expect(SetupState.validateProblem3.problemIndex, 2);
      expect(SetupState.collectProblem4.problemIndex, 3);
      expect(SetupState.collectProblem5.problemIndex, 4);
      expect(SetupState.sensitivityGate.problemIndex, null);
    });

    test('progress increases through states', () {
      expect(SetupState.initial.progressPercent, 0);
      expect(
          SetupState.sensitivityGate.progressPercent,
          lessThan(
              SetupState.collectProblem1.progressPercent));
      expect(
          SetupState.collectProblem1.progressPercent,
          lessThan(SetupState.collectProblem2.progressPercent));
      expect(
          SetupState.collectProblem2.progressPercent,
          lessThan(SetupState.collectProblem3.progressPercent));
      expect(SetupState.finalized.progressPercent, 100);
    });
  });

  group('TimeAllocationStatus', () {
    test('valid range 95-105%', () {
      expect(SetupSessionData.validateTimeAllocation(95),
          TimeAllocationStatus.valid);
      expect(SetupSessionData.validateTimeAllocation(100),
          TimeAllocationStatus.valid);
      expect(SetupSessionData.validateTimeAllocation(105),
          TimeAllocationStatus.valid);
    });

    test('warning range 90-94% and 106-110%', () {
      expect(SetupSessionData.validateTimeAllocation(90),
          TimeAllocationStatus.warning);
      expect(SetupSessionData.validateTimeAllocation(94),
          TimeAllocationStatus.warning);
      expect(SetupSessionData.validateTimeAllocation(106),
          TimeAllocationStatus.warning);
      expect(SetupSessionData.validateTimeAllocation(110),
          TimeAllocationStatus.warning);
    });

    test('error range <90% and >110%', () {
      expect(SetupSessionData.validateTimeAllocation(89),
          TimeAllocationStatus.error);
      expect(SetupSessionData.validateTimeAllocation(50),
          TimeAllocationStatus.error);
      expect(SetupSessionData.validateTimeAllocation(111),
          TimeAllocationStatus.error);
      expect(SetupSessionData.validateTimeAllocation(150),
          TimeAllocationStatus.error);
    });

    test('canProceed returns correct value', () {
      expect(TimeAllocationStatus.valid.canProceed, true);
      expect(TimeAllocationStatus.warning.canProceed, true);
      expect(TimeAllocationStatus.error.canProceed, false);
    });
  });

  group('SetupProblem', () {
    test('isComplete returns false when fields missing', () {
      const problem = SetupProblem();
      expect(problem.isComplete, false);

      const partial = SetupProblem(
        name: 'Test Problem',
        whatBreaks: 'Something breaks',
      );
      expect(partial.isComplete, false);
    });

    test('isComplete returns true when all fields present', () {
      final problem = SetupProblem(
        name: 'Test Problem',
        whatBreaks: 'Something breaks',
        scarcitySignals: const ['Signal 1', 'Signal 2'],
        evidenceAiCheaper: 'No',
        evidenceErrorCost: 'High',
        evidenceTrustRequired: 'Yes',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Because...',
      );
      expect(problem.isComplete, true);
    });

    test('isComplete with unknown scarcity', () {
      final problem = SetupProblem(
        name: 'Test Problem',
        whatBreaks: 'Something breaks',
        scarcityUnknownReason: 'Not sure about this',
        evidenceAiCheaper: 'No',
        evidenceErrorCost: 'High',
        evidenceTrustRequired: 'Yes',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Because...',
      );
      expect(problem.isComplete, true);
    });

    test('validate returns errors for missing fields', () {
      const problem = SetupProblem();
      final errors = problem.validate();

      expect(errors, contains('Problem name is required'));
      expect(errors, contains('What breaks if not solved is required'));
      expect(errors.any((e) => e.contains('scarcity')), true);
      expect(errors, contains('AI cheaper evidence is required'));
      expect(errors, contains('Error cost evidence is required'));
      expect(errors, contains('Trust required evidence is required'));
      expect(errors, contains('Direction classification is required'));
      expect(errors, contains('Direction rationale is required'));
    });

    test('scarcitySignalsJson encodes correctly', () {
      const problem = SetupProblem(
        scarcitySignals: ['Signal 1', 'Signal 2'],
      );
      expect(problem.scarcitySignalsJson, '["Signal 1","Signal 2"]');

      const unknownProblem = SetupProblem(
        scarcityUnknownReason: 'Not sure',
      );
      expect(unknownProblem.scarcitySignalsJson,
          '{"unknown":true,"reason":"Not sure"}');
    });

    test('serialization round trip', () {
      final problem = SetupProblem(
        name: 'Test Problem',
        whatBreaks: 'Something breaks',
        scarcitySignals: const ['Signal 1', 'Signal 2'],
        evidenceAiCheaper: 'No',
        evidenceErrorCost: 'High',
        evidenceTrustRequired: 'Yes',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Because...',
        timeAllocationPercent: 30,
      );

      final json = problem.toJson();
      final restored = SetupProblem.fromJson(json);

      expect(restored.name, problem.name);
      expect(restored.whatBreaks, problem.whatBreaks);
      expect(restored.scarcitySignals, problem.scarcitySignals);
      expect(restored.evidenceAiCheaper, problem.evidenceAiCheaper);
      expect(restored.direction, problem.direction);
      expect(restored.timeAllocationPercent, problem.timeAllocationPercent);
    });
  });

  group('SetupSessionData', () {
    test('problemCount returns correct count', () {
      const data = SetupSessionData();
      expect(data.problemCount, 0);

      final dataWithProblems = SetupSessionData(
        problems: [
          const SetupProblem(name: 'Problem 1'),
          const SetupProblem(name: 'Problem 2'),
          const SetupProblem(name: 'Problem 3'),
        ],
      );
      expect(dataWithProblems.problemCount, 3);
    });

    test('hasMinimumProblems requires 3', () {
      const data0 = SetupSessionData();
      expect(data0.hasMinimumProblems, false);

      final data2 = SetupSessionData(
        problems: [
          const SetupProblem(name: 'P1'),
          const SetupProblem(name: 'P2'),
        ],
      );
      expect(data2.hasMinimumProblems, false);

      final data3 = SetupSessionData(
        problems: [
          const SetupProblem(name: 'P1'),
          const SetupProblem(name: 'P2'),
          const SetupProblem(name: 'P3'),
        ],
      );
      expect(data3.hasMinimumProblems, true);
    });

    test('hasMaximumProblems requires 5', () {
      final data4 = SetupSessionData(
        problems: List.generate(4, (i) => SetupProblem(name: 'P$i')),
      );
      expect(data4.hasMaximumProblems, false);

      final data5 = SetupSessionData(
        problems: List.generate(5, (i) => SetupProblem(name: 'P$i')),
      );
      expect(data5.hasMaximumProblems, true);
    });

    test('canAddMoreProblems checks maximum', () {
      final data4 = SetupSessionData(
        problems: List.generate(4, (i) => SetupProblem(name: 'P$i')),
      );
      expect(data4.canAddMoreProblems, true);

      final data5 = SetupSessionData(
        problems: List.generate(5, (i) => SetupProblem(name: 'P$i')),
      );
      expect(data5.canAddMoreProblems, false);
    });

    test('hasAppreciatingProblems detects appreciating', () {
      final dataNoAppreciating = SetupSessionData(
        problems: [
          SetupProblem(
            name: 'P1',
            direction: ProblemDirection.depreciating,
          ),
          SetupProblem(
            name: 'P2',
            direction: ProblemDirection.stable,
          ),
        ],
      );
      expect(dataNoAppreciating.hasAppreciatingProblems, false);

      final dataWithAppreciating = SetupSessionData(
        problems: [
          SetupProblem(
            name: 'P1',
            direction: ProblemDirection.appreciating,
          ),
          SetupProblem(
            name: 'P2',
            direction: ProblemDirection.stable,
          ),
        ],
      );
      expect(dataWithAppreciating.hasAppreciatingProblems, true);
    });

    test('calculateTotalAllocation sums correctly', () {
      final data = SetupSessionData(
        problems: [
          const SetupProblem(timeAllocationPercent: 30),
          const SetupProblem(timeAllocationPercent: 40),
          const SetupProblem(timeAllocationPercent: 30),
        ],
      );
      expect(data.calculateTotalAllocation(), 100);
    });

    test('serialization round trip', () {
      final data = SetupSessionData(
        currentState: SetupState.timeAllocation,
        abstractionMode: true,
        problems: [
          SetupProblem(
            name: 'Test Problem',
            direction: ProblemDirection.appreciating,
            timeAllocationPercent: 50,
          ),
        ],
        currentProblemIndex: 1,
        totalTimeAllocation: 50,
        timeAllocationStatus: TimeAllocationStatus.warning,
      );

      final json = data.toJson();
      final restored = SetupSessionData.fromJson(json);

      expect(restored.currentState, data.currentState);
      expect(restored.abstractionMode, data.abstractionMode);
      expect(restored.problems.length, data.problems.length);
      expect(restored.problems[0].name, data.problems[0].name);
      expect(restored.currentProblemIndex, data.currentProblemIndex);
      expect(restored.totalTimeAllocation, data.totalTimeAllocation);
      expect(restored.timeAllocationStatus, data.timeAllocationStatus);
    });
  });

  group('SetupBoardMember', () {
    test('hasPersona returns correct value', () {
      const memberIncomplete = SetupBoardMember(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
      );
      expect(memberIncomplete.hasPersona, false);

      const memberComplete = SetupBoardMember(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
        personaBackground: 'Background here',
        personaCommunicationStyle: 'Direct',
      );
      expect(memberComplete.hasPersona, true);
    });

    test('serialization round trip', () {
      const member = SetupBoardMember(
        roleType: BoardRoleType.accountability,
        isGrowthRole: false,
        isActive: true,
        anchoredProblemIndex: 0,
        anchoredDemand: 'Show me the receipts',
        personaName: 'Maya Chen',
        personaBackground: 'Executive coach',
        personaCommunicationStyle: 'Direct',
        personaSignaturePhrase: 'Let us see the evidence',
      );

      final json = member.toJson();
      final restored = SetupBoardMember.fromJson(json);

      expect(restored.roleType, member.roleType);
      expect(restored.isGrowthRole, member.isGrowthRole);
      expect(restored.isActive, member.isActive);
      expect(restored.anchoredProblemIndex, member.anchoredProblemIndex);
      expect(restored.anchoredDemand, member.anchoredDemand);
      expect(restored.personaName, member.personaName);
      expect(restored.personaBackground, member.personaBackground);
      expect(restored.personaCommunicationStyle,
          member.personaCommunicationStyle);
      expect(restored.personaSignaturePhrase, member.personaSignaturePhrase);
    });
  });

  group('SetupPortfolioHealth', () {
    test('hasAppreciating returns correct value', () {
      const healthNoAppreciating = SetupPortfolioHealth(
        appreciatingPercent: 0,
        depreciatingPercent: 50,
        stablePercent: 50,
      );
      expect(healthNoAppreciating.hasAppreciating, false);

      const healthWithAppreciating = SetupPortfolioHealth(
        appreciatingPercent: 30,
        depreciatingPercent: 40,
        stablePercent: 30,
      );
      expect(healthWithAppreciating.hasAppreciating, true);
    });

    test('serialization round trip', () {
      const health = SetupPortfolioHealth(
        appreciatingPercent: 30,
        depreciatingPercent: 40,
        stablePercent: 30,
        riskStatement: 'Risk here',
        opportunityStatement: 'Opportunity here',
      );

      final json = health.toJson();
      final restored = SetupPortfolioHealth.fromJson(json);

      expect(restored.appreciatingPercent, health.appreciatingPercent);
      expect(restored.depreciatingPercent, health.depreciatingPercent);
      expect(restored.stablePercent, health.stablePercent);
      expect(restored.riskStatement, health.riskStatement);
      expect(restored.opportunityStatement, health.opportunityStatement);
    });
  });

  group('SetupTrigger', () {
    test('serialization round trip', () {
      final trigger = SetupTrigger(
        triggerType: 'annual',
        description: 'Annual review',
        condition: '12 months since setup',
        recommendedAction: 'full_resetup',
        dueAtUtc: DateTime.utc(2025, 1, 1),
      );

      final json = trigger.toJson();
      final restored = SetupTrigger.fromJson(json);

      expect(restored.triggerType, trigger.triggerType);
      expect(restored.description, trigger.description);
      expect(restored.condition, trigger.condition);
      expect(restored.recommendedAction, trigger.recommendedAction);
      expect(restored.dueAtUtc, trigger.dueAtUtc);
    });
  });

  group('SetupService', () {
    late MockGovernanceSessionRepository mockSessionRepo;
    late MockProblemRepository mockProblemRepo;
    late MockBoardMemberRepository mockBoardMemberRepo;
    late MockPortfolioHealthRepository mockPortfolioHealthRepo;
    late MockPortfolioVersionRepository mockPortfolioVersionRepo;
    late MockReSetupTriggerRepository mockTriggerRepo;
    late MockUserPreferencesRepository mockPrefsRepo;
    late MockSetupAIService mockAIService;
    late SetupService service;

    setUp(() {
      mockSessionRepo = MockGovernanceSessionRepository();
      mockProblemRepo = MockProblemRepository();
      mockBoardMemberRepo = MockBoardMemberRepository();
      mockPortfolioHealthRepo = MockPortfolioHealthRepository();
      mockPortfolioVersionRepo = MockPortfolioVersionRepository();
      mockTriggerRepo = MockReSetupTriggerRepository();
      mockPrefsRepo = MockUserPreferencesRepository();
      mockAIService = MockSetupAIService();

      service = SetupService(
        sessionRepository: mockSessionRepo,
        problemRepository: mockProblemRepo,
        boardMemberRepository: mockBoardMemberRepo,
        portfolioHealthRepository: mockPortfolioHealthRepo,
        portfolioVersionRepository: mockPortfolioVersionRepo,
        triggerRepository: mockTriggerRepo,
        preferencesRepository: mockPrefsRepo,
        aiService: mockAIService,
      );
    });

    test('startSession creates session and returns ID', () async {
      when(mockPrefsRepo.get()).thenAnswer((_) async => _mockUserPrefs());
      when(mockSessionRepo.create(
        sessionType: anyNamed('sessionType'),
        initialState: anyNamed('initialState'),
        abstractionMode: anyNamed('abstractionMode'),
      )).thenAnswer((_) async => 'test-session-id');

      final sessionId = await service.startSession();

      expect(sessionId, 'test-session-id');
      verify(mockSessionRepo.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'sensitivityGate',
        abstractionMode: false,
      )).called(1);
    });

    test('startSession uses provided abstraction mode', () async {
      when(mockSessionRepo.create(
        sessionType: anyNamed('sessionType'),
        initialState: anyNamed('initialState'),
        abstractionMode: anyNamed('abstractionMode'),
      )).thenAnswer((_) async => 'test-session-id');

      await service.startSession(abstractionMode: true);

      verify(mockSessionRepo.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'sensitivityGate',
        abstractionMode: true,
      )).called(1);
    });
  });
}

UserPreference _mockUserPrefs() {
  return UserPreference(
    id: 'test-id',
    abstractionModeQuick: false,
    abstractionModeSetup: false,
    abstractionModeQuarterly: false,
    rememberAbstractionChoice: false,
    analyticsEnabled: true,
    microReviewCollapsed: false,
    onboardingCompleted: false,
    setupPromptDismissed: false,
    setupPromptLastShownUtc: null,
    totalEntryCount: 0,
    createdAtUtc: DateTime.now(),
    updatedAtUtc: DateTime.now(),
    syncStatus: 'pending',
    serverVersion: 0,
  );
}
