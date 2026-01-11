import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/services/services.dart';

@GenerateMocks([
  GovernanceSessionRepository,
  BetRepository,
  ProblemRepository,
  BoardMemberRepository,
  PortfolioVersionRepository,
  PortfolioHealthRepository,
  ReSetupTriggerRepository,
  EvidenceItemRepository,
  UserPreferencesRepository,
  VaguenessDetectionService,
  QuarterlyAIService,
])
import 'quarterly_service_test.mocks.dart';

void main() {
  group('QuarterlyState', () {
    test('state machine progression', () {
      // Initial -> SensitivityGate
      expect(QuarterlyState.initial.nextState, QuarterlyState.sensitivityGate);
      expect(QuarterlyState.sensitivityGate.nextState,
          QuarterlyState.gate0Prerequisites);
      expect(QuarterlyState.gate0Prerequisites.nextState,
          QuarterlyState.recentReportWarning);
      expect(QuarterlyState.recentReportWarning.nextState,
          QuarterlyState.q1LastBetEvaluation);
    });

    test('question states progress correctly', () {
      expect(QuarterlyState.q1LastBetEvaluation.nextState,
          QuarterlyState.q2CommitmentsVsActuals);
      expect(QuarterlyState.q2CommitmentsVsActuals.nextState,
          QuarterlyState.q3AvoidedDecision);
      expect(QuarterlyState.q3AvoidedDecision.nextState,
          QuarterlyState.q4ComfortWork);
      expect(QuarterlyState.q4ComfortWork.nextState,
          QuarterlyState.q5PortfolioCheck);
      expect(QuarterlyState.q5PortfolioCheck.nextState,
          QuarterlyState.q6PortfolioHealthUpdate);
    });

    test('growth role states progress correctly', () {
      expect(QuarterlyState.q6PortfolioHealthUpdate.nextState,
          QuarterlyState.q7ProtectionCheck);
      expect(QuarterlyState.q7ProtectionCheck.nextState,
          QuarterlyState.q8OpportunityCheck);
      expect(QuarterlyState.q8OpportunityCheck.nextState,
          QuarterlyState.q9TriggerCheck);
    });

    test('final states progress correctly', () {
      expect(
          QuarterlyState.q9TriggerCheck.nextState, QuarterlyState.q10NextBet);
      expect(QuarterlyState.q10NextBet.nextState,
          QuarterlyState.coreBoardInterrogation);
      expect(QuarterlyState.coreBoardInterrogation.nextState,
          QuarterlyState.growthBoardInterrogation);
      expect(QuarterlyState.growthBoardInterrogation.nextState,
          QuarterlyState.generateReport);
      expect(
          QuarterlyState.generateReport.nextState, QuarterlyState.finalized);
    });

    test('finalized and abandoned states stay put', () {
      expect(QuarterlyState.finalized.nextState, QuarterlyState.finalized);
      expect(QuarterlyState.abandoned.nextState, QuarterlyState.abandoned);
    });

    test('isQuestion identifies correct states', () {
      expect(QuarterlyState.q1LastBetEvaluation.isQuestion, true);
      expect(QuarterlyState.q2CommitmentsVsActuals.isQuestion, true);
      expect(QuarterlyState.q3AvoidedDecision.isQuestion, true);
      expect(QuarterlyState.q4ComfortWork.isQuestion, true);
      expect(QuarterlyState.q5PortfolioCheck.isQuestion, true);
      expect(QuarterlyState.coreBoardInterrogation.isQuestion, true);
      expect(QuarterlyState.sensitivityGate.isQuestion, false);
      expect(QuarterlyState.generateReport.isQuestion, false);
    });

    test('isClarify identifies correct states', () {
      expect(QuarterlyState.q2Clarify.isClarify, true);
      expect(QuarterlyState.q3Clarify.isClarify, true);
      expect(QuarterlyState.q4Clarify.isClarify, true);
      expect(QuarterlyState.q5Clarify.isClarify, true);
      expect(QuarterlyState.boardInterrogationClarify.isClarify, true);
      expect(QuarterlyState.q2CommitmentsVsActuals.isClarify, false);
    });

    test('requiresVaguenessCheck identifies correct states', () {
      expect(QuarterlyState.q2CommitmentsVsActuals.requiresVaguenessCheck, true);
      expect(QuarterlyState.q3AvoidedDecision.requiresVaguenessCheck, true);
      expect(QuarterlyState.coreBoardInterrogation.requiresVaguenessCheck, true);
      expect(
          QuarterlyState.q1LastBetEvaluation.requiresVaguenessCheck, false);
      expect(
          QuarterlyState.q6PortfolioHealthUpdate.requiresVaguenessCheck, false);
    });

    test('clarifyState returns correct clarify state', () {
      expect(QuarterlyState.q2CommitmentsVsActuals.clarifyState,
          QuarterlyState.q2Clarify);
      expect(QuarterlyState.q3AvoidedDecision.clarifyState,
          QuarterlyState.q3Clarify);
      expect(QuarterlyState.coreBoardInterrogation.clarifyState,
          QuarterlyState.boardInterrogationClarify);
      expect(QuarterlyState.q1LastBetEvaluation.clarifyState, null);
    });

    test('questionNumber returns correct number', () {
      expect(QuarterlyState.q1LastBetEvaluation.questionNumber, 1);
      expect(QuarterlyState.q2CommitmentsVsActuals.questionNumber, 2);
      expect(QuarterlyState.q2Clarify.questionNumber, 2);
      expect(QuarterlyState.q10NextBet.questionNumber, 10);
      expect(QuarterlyState.sensitivityGate.questionNumber, 0);
      expect(QuarterlyState.coreBoardInterrogation.questionNumber, 0);
    });

    test('progress increases through states', () {
      expect(QuarterlyState.initial.progressPercent, 0);
      expect(
          QuarterlyState.sensitivityGate.progressPercent,
          lessThan(QuarterlyState.q1LastBetEvaluation.progressPercent));
      expect(
          QuarterlyState.q1LastBetEvaluation.progressPercent,
          lessThan(QuarterlyState.q5PortfolioCheck.progressPercent));
      expect(
          QuarterlyState.q5PortfolioCheck.progressPercent,
          lessThan(QuarterlyState.coreBoardInterrogation.progressPercent));
      expect(QuarterlyState.finalized.progressPercent, 100);
    });
  });

  group('QuarterlyQA', () {
    test('serialization round trip', () {
      const qa = QuarterlyQA(
        question: 'Test question?',
        answer: 'Test answer',
        wasVague: true,
        concreteExample: 'Concrete example here',
        state: QuarterlyState.q2CommitmentsVsActuals,
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
      );

      final json = qa.toJson();
      final restored = QuarterlyQA.fromJson(json);

      expect(restored.question, qa.question);
      expect(restored.answer, qa.answer);
      expect(restored.wasVague, qa.wasVague);
      expect(restored.concreteExample, qa.concreteExample);
      expect(restored.state, qa.state);
      expect(restored.roleType, qa.roleType);
      expect(restored.personaName, qa.personaName);
    });
  });

  group('BetEvaluation', () {
    test('serialization round trip', () {
      final eval = BetEvaluation(
        betId: 'bet-123',
        prediction: 'I will be promoted',
        wrongIf: 'Still same role by Q2',
        status: BetStatus.correct,
        rationale: 'Got the promotion in March',
        evidence: [
          const QuarterlyEvidence(
            description: 'Promotion email',
            type: EvidenceType.artifact,
            strength: EvidenceStrength.strong,
          ),
        ],
      );

      final json = eval.toJson();
      final restored = BetEvaluation.fromJson(json);

      expect(restored.betId, eval.betId);
      expect(restored.prediction, eval.prediction);
      expect(restored.wrongIf, eval.wrongIf);
      expect(restored.status, eval.status);
      expect(restored.rationale, eval.rationale);
      expect(restored.evidence.length, 1);
      expect(restored.evidence[0].description, 'Promotion email');
    });
  });

  group('QuarterlyEvidence', () {
    test('serialization round trip', () {
      const evidence = QuarterlyEvidence(
        description: 'Decision documentation',
        type: EvidenceType.decision,
        strength: EvidenceStrength.strong,
        context: 'Q1 planning',
      );

      final json = evidence.toJson();
      final restored = QuarterlyEvidence.fromJson(json);

      expect(restored.description, evidence.description);
      expect(restored.type, evidence.type);
      expect(restored.strength, evidence.strength);
      expect(restored.context, evidence.context);
    });

    test('defaults strength based on type', () {
      expect(EvidenceType.decision.defaultStrength, EvidenceStrength.strong);
      expect(EvidenceType.artifact.defaultStrength, EvidenceStrength.strong);
      expect(EvidenceType.proxy.defaultStrength, EvidenceStrength.medium);
      expect(EvidenceType.calendar.defaultStrength, EvidenceStrength.medium);
      expect(EvidenceType.none.defaultStrength, EvidenceStrength.none);
    });
  });

  group('DirectionUpdate', () {
    test('hasChanged returns correct value', () {
      const noChange = DirectionUpdate(
        problemId: 'p1',
        problemName: 'Problem 1',
        previousDirection: ProblemDirection.appreciating,
        newDirection: ProblemDirection.appreciating,
      );
      expect(noChange.hasChanged, false);

      const hasChange = DirectionUpdate(
        problemId: 'p1',
        problemName: 'Problem 1',
        previousDirection: ProblemDirection.stable,
        newDirection: ProblemDirection.depreciating,
      );
      expect(hasChange.hasChanged, true);
    });
  });

  group('AllocationUpdate', () {
    test('hasChanged and changeAmount work correctly', () {
      const noChange = AllocationUpdate(
        problemId: 'p1',
        problemName: 'Problem 1',
        previousPercent: 30,
        newPercent: 30,
      );
      expect(noChange.hasChanged, false);
      expect(noChange.changeAmount, 0);

      const increase = AllocationUpdate(
        problemId: 'p1',
        problemName: 'Problem 1',
        previousPercent: 30,
        newPercent: 40,
      );
      expect(increase.hasChanged, true);
      expect(increase.changeAmount, 10);

      const decrease = AllocationUpdate(
        problemId: 'p1',
        problemName: 'Problem 1',
        previousPercent: 40,
        newPercent: 30,
      );
      expect(decrease.hasChanged, true);
      expect(decrease.changeAmount, -10);
    });
  });

  group('HealthTrend', () {
    test('change calculations work correctly', () {
      const trend = HealthTrend(
        previousAppreciating: 30,
        currentAppreciating: 40,
        previousDepreciating: 50,
        currentDepreciating: 40,
        previousStable: 20,
        currentStable: 20,
      );

      expect(trend.appreciatingChange, 10);
      expect(trend.depreciatingChange, -10);
      expect(trend.stableChange, 0);
    });

    test('serialization round trip', () {
      const trend = HealthTrend(
        previousAppreciating: 30,
        currentAppreciating: 40,
        previousDepreciating: 50,
        currentDepreciating: 40,
        previousStable: 20,
        currentStable: 20,
        trendDescription: 'Good progress',
      );

      final json = trend.toJson();
      final restored = HealthTrend.fromJson(json);

      expect(restored.previousAppreciating, trend.previousAppreciating);
      expect(restored.currentAppreciating, trend.currentAppreciating);
      expect(restored.trendDescription, trend.trendDescription);
    });
  });

  group('BoardInterrogationResponse', () {
    test('serialization round trip', () {
      const response = BoardInterrogationResponse(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
        anchoredProblemId: 'problem-1',
        anchoredDemand: 'Show me the receipts',
        question: 'What evidence do you have?',
        response: 'I have the documentation',
        wasVague: true,
        concreteExample: 'The doc from March 5th',
        skipped: false,
      );

      final json = response.toJson();
      final restored = BoardInterrogationResponse.fromJson(json);

      expect(restored.roleType, response.roleType);
      expect(restored.personaName, response.personaName);
      expect(restored.question, response.question);
      expect(restored.response, response.response);
      expect(restored.wasVague, response.wasVague);
      expect(restored.concreteExample, response.concreteExample);
    });
  });

  group('NewBet', () {
    test('serialization round trip', () {
      const bet = NewBet(
        prediction: 'Will be promoted',
        wrongIf: 'Same role by June',
        durationDays: 90,
      );

      final json = bet.toJson();
      final restored = NewBet.fromJson(json);

      expect(restored.prediction, bet.prediction);
      expect(restored.wrongIf, bet.wrongIf);
      expect(restored.durationDays, bet.durationDays);
    });

    test('defaults to 90 days', () {
      const bet = NewBet(
        prediction: 'Test',
        wrongIf: 'Test',
      );
      expect(bet.durationDays, 90);
    });
  });

  group('QuarterlySessionData', () {
    test('canSkip returns correct value', () {
      const data0 = QuarterlySessionData(vaguenessSkipCount: 0);
      expect(data0.canSkip, true);

      const data1 = QuarterlySessionData(vaguenessSkipCount: 1);
      expect(data1.canSkip, true);

      const data2 = QuarterlySessionData(vaguenessSkipCount: 2);
      expect(data2.canSkip, false);

      const data3 = QuarterlySessionData(vaguenessSkipCount: 3);
      expect(data3.canSkip, false);
    });

    test('allCoreBoardResponded returns correct value', () {
      const dataEmpty = QuarterlySessionData(coreBoardResponses: []);
      expect(dataEmpty.allCoreBoardResponded, false);

      final data5 = QuarterlySessionData(
        coreBoardResponses: List.generate(
          5,
          (i) => BoardInterrogationResponse(
            roleType: BoardRoleType.values[i],
            personaName: 'Person $i',
            question: 'Q?',
            response: 'A',
          ),
        ),
      );
      expect(data5.allCoreBoardResponded, true);
    });

    test('allGrowthBoardResponded returns true if no growth roles active', () {
      const data = QuarterlySessionData(growthRolesActive: false);
      expect(data.allGrowthBoardResponded, true);
    });

    test('allGrowthBoardResponded checks growth responses when active', () {
      const dataEmpty = QuarterlySessionData(
        growthRolesActive: true,
        growthBoardResponses: [],
      );
      expect(dataEmpty.allGrowthBoardResponded, false);

      final data2 = QuarterlySessionData(
        growthRolesActive: true,
        growthBoardResponses: List.generate(
          2,
          (i) => BoardInterrogationResponse(
            roleType:
                i == 0 ? BoardRoleType.portfolioDefender : BoardRoleType.opportunityScout,
            personaName: 'Person $i',
            question: 'Q?',
            response: 'A',
          ),
        ),
      );
      expect(data2.allGrowthBoardResponded, true);
    });

    test('serialization round trip', () {
      final data = QuarterlySessionData(
        currentState: QuarterlyState.q5PortfolioCheck,
        abstractionMode: true,
        vaguenessSkipCount: 1,
        prerequisitesPassed: true,
        showedRecentWarning: true,
        daysSinceLastReport: 45,
        growthRolesActive: true,
        anyTriggerMet: false,
        newBet: const NewBet(
          prediction: 'Test prediction',
          wrongIf: 'Test wrong if',
        ),
      );

      final json = data.toJson();
      final restored = QuarterlySessionData.fromJson(json);

      expect(restored.currentState, data.currentState);
      expect(restored.abstractionMode, data.abstractionMode);
      expect(restored.vaguenessSkipCount, data.vaguenessSkipCount);
      expect(restored.prerequisitesPassed, data.prerequisitesPassed);
      expect(restored.showedRecentWarning, data.showedRecentWarning);
      expect(restored.daysSinceLastReport, data.daysSinceLastReport);
      expect(restored.growthRolesActive, data.growthRolesActive);
      expect(restored.anyTriggerMet, data.anyTriggerMet);
      expect(restored.newBet?.prediction, data.newBet?.prediction);
    });
  });

  group('QuarterlyService', () {
    late MockGovernanceSessionRepository mockSessionRepo;
    late MockBetRepository mockBetRepo;
    late MockProblemRepository mockProblemRepo;
    late MockBoardMemberRepository mockBoardMemberRepo;
    late MockPortfolioVersionRepository mockPortfolioVersionRepo;
    late MockPortfolioHealthRepository mockPortfolioHealthRepo;
    late MockReSetupTriggerRepository mockTriggerRepo;
    late MockEvidenceItemRepository mockEvidenceRepo;
    late MockUserPreferencesRepository mockPrefsRepo;
    late MockVaguenessDetectionService mockVaguenessService;
    late MockQuarterlyAIService mockAIService;
    late QuarterlyService service;

    setUp(() {
      mockSessionRepo = MockGovernanceSessionRepository();
      mockBetRepo = MockBetRepository();
      mockProblemRepo = MockProblemRepository();
      mockBoardMemberRepo = MockBoardMemberRepository();
      mockPortfolioVersionRepo = MockPortfolioVersionRepository();
      mockPortfolioHealthRepo = MockPortfolioHealthRepository();
      mockTriggerRepo = MockReSetupTriggerRepository();
      mockEvidenceRepo = MockEvidenceItemRepository();
      mockPrefsRepo = MockUserPreferencesRepository();
      mockVaguenessService = MockVaguenessDetectionService();
      mockAIService = MockQuarterlyAIService();

      service = QuarterlyService(
        sessionRepository: mockSessionRepo,
        betRepository: mockBetRepo,
        problemRepository: mockProblemRepo,
        boardMemberRepository: mockBoardMemberRepo,
        portfolioVersionRepository: mockPortfolioVersionRepo,
        portfolioHealthRepository: mockPortfolioHealthRepo,
        triggerRepository: mockTriggerRepo,
        evidenceRepository: mockEvidenceRepo,
        preferencesRepository: mockPrefsRepo,
        vaguenessService: mockVaguenessService,
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
        sessionType: GovernanceSessionType.quarterly,
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
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'sensitivityGate',
        abstractionMode: true,
      )).called(1);
    });

    test('checkPrerequisites returns correct result', () async {
      when(mockPortfolioVersionRepo.hasPortfolio())
          .thenAnswer((_) async => true);
      when(mockBoardMemberRepo.getAll())
          .thenAnswer((_) async => [_mockBoardMember()]);
      when(mockTriggerRepo.getAll()).thenAnswer((_) async => [_mockTrigger()]);

      final result = await service.checkPrerequisites();

      expect(result.hasPortfolio, true);
      expect(result.hasBoard, true);
      expect(result.hasTriggers, true);
      expect(result.passed, true);
    });

    test('checkPrerequisites fails when missing components', () async {
      when(mockPortfolioVersionRepo.hasPortfolio())
          .thenAnswer((_) async => false);
      when(mockBoardMemberRepo.getAll()).thenAnswer((_) async => []);
      when(mockTriggerRepo.getAll()).thenAnswer((_) async => []);

      final result = await service.checkPrerequisites();

      expect(result.hasPortfolio, false);
      expect(result.hasBoard, false);
      expect(result.hasTriggers, false);
      expect(result.passed, false);
    });

    test('checkRecentReport returns warning for <30 days', () async {
      when(mockSessionRepo.getMostRecentCompleted(any))
          .thenAnswer((_) async => _mockCompletedSession(
                completedDaysAgo: 15,
              ));

      final result = await service.checkRecentReport();

      expect(result.hasRecentReport, true);
      expect(result.daysSinceLastReport, 15);
      expect(result.showWarning, true);
    });

    test('checkRecentReport returns no warning for >=30 days', () async {
      when(mockSessionRepo.getMostRecentCompleted(any))
          .thenAnswer((_) async => _mockCompletedSession(
                completedDaysAgo: 45,
              ));

      final result = await service.checkRecentReport();

      expect(result.hasRecentReport, true);
      expect(result.daysSinceLastReport, 45);
      expect(result.showWarning, false);
    });

    test('checkRecentReport returns no warning when no previous report',
        () async {
      when(mockSessionRepo.getMostRecentCompleted(any))
          .thenAnswer((_) async => null);

      final result = await service.checkRecentReport();

      expect(result.hasRecentReport, false);
      expect(result.daysSinceLastReport, null);
      expect(result.showWarning, false);
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
    onboardingCompleted: false,
    lastSetupPromptDismissedAtUtc: null,
    createdAtUtc: DateTime.now(),
    updatedAtUtc: DateTime.now(),
    deletedAtUtc: null,
    syncStatus: 'pending',
    serverVersion: 0,
  );
}

BoardMember _mockBoardMember() {
  return BoardMember(
    id: 'member-1',
    roleType: BoardRoleType.accountability,
    isGrowthRole: false,
    isActive: true,
    personaName: 'Maya Chen',
    personaBackground: 'Executive coach',
    personaCommunicationStyle: 'Direct',
    personaSignaturePhrase: 'Show me the receipts',
    anchoredProblemId: null,
    anchoredDemand: null,
    originalPersonaName: 'Maya Chen',
    originalPersonaBackground: 'Executive coach',
    originalPersonaCommunicationStyle: 'Direct',
    originalPersonaSignaturePhrase: 'Show me the receipts',
    createdAtUtc: DateTime.now(),
    updatedAtUtc: DateTime.now(),
    deletedAtUtc: null,
    syncStatus: 'pending',
    serverVersion: 0,
  );
}

ReSetupTrigger _mockTrigger() {
  return ReSetupTrigger(
    id: 'trigger-1',
    triggerType: 'annual',
    description: 'Annual review',
    condition: '12 months since setup',
    recommendedAction: 'full_resetup',
    dueAtUtc: DateTime.now().add(const Duration(days: 365)),
    isMet: false,
    createdAtUtc: DateTime.now(),
    updatedAtUtc: DateTime.now(),
    deletedAtUtc: null,
    syncStatus: 'pending',
    serverVersion: 0,
  );
}

GovernanceSession _mockCompletedSession({required int completedDaysAgo}) {
  final now = DateTime.now().toUtc();
  return GovernanceSession(
    id: 'session-1',
    sessionType: GovernanceSessionType.quarterly.name,
    startedAtUtc: now.subtract(Duration(days: completedDaysAgo + 1)),
    completedAtUtc: now.subtract(Duration(days: completedDaysAgo)),
    currentState: 'finalized',
    abstractionMode: false,
    vaguenessSkipCount: 0,
    transcriptJson: '{}',
    outputMarkdown: null,
    createdBetId: null,
    createdAtUtc: now.subtract(Duration(days: completedDaysAgo + 1)),
    updatedAtUtc: now.subtract(Duration(days: completedDaysAgo)),
    deletedAtUtc: null,
    syncStatus: 'synced',
    serverVersion: 1,
  );
}
