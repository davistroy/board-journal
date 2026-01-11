import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

/// Integration tests for the portfolio setup flow.
///
/// Per PRD Section 4.4 (Setup):
/// - Portfolio must have 3-5 problems
/// - Time allocations must sum to 95-105%
/// - Each problem has direction classification
/// - Board members are anchored to problems
void main() {
  late AppDatabase database;
  late ProblemRepository problemRepository;
  late BoardMemberRepository boardMemberRepository;
  late GovernanceSessionRepository sessionRepository;
  late PortfolioVersionRepository portfolioVersionRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    problemRepository = ProblemRepository(database);
    boardMemberRepository = BoardMemberRepository(database);
    sessionRepository = GovernanceSessionRepository(database);
    portfolioVersionRepository = PortfolioVersionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Portfolio Setup Flow', () {
    test('complete portfolio setup creates problems, board members, and portfolio version', () async {
      // Step 1: Start a setup session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'problems_intro',
      );

      // Step 2: Create 4 problems with valid allocation (100%)
      final problem1Id = await problemRepository.create(
        name: 'Technical Architecture',
        whatBreaks: 'System scalability suffers',
        scarcitySignalsJson: '["design decisions", "performance optimization"]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'AI cannot make architectural decisions with full context',
        evidenceAiCheaper: 'AI provides options but cannot decide',
        evidenceErrorCost: 'Wrong architecture costs months',
        evidenceTrustRequired: 'Team trusts human judgment',
        timeAllocationPercent: 35,
      );

      final problem2Id = await problemRepository.create(
        name: 'Team Leadership',
        whatBreaks: 'Team coordination fails',
        scarcitySignalsJson: '["mentoring", "conflict resolution"]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Human relationships require human interaction',
        evidenceAiCheaper: 'AI cannot mentor effectively',
        evidenceErrorCost: 'Bad leadership causes attrition',
        evidenceTrustRequired: 'High trust required',
        timeAllocationPercent: 30,
      );

      final problem3Id = await problemRepository.create(
        name: 'Documentation',
        whatBreaks: 'Knowledge gets lost',
        scarcitySignalsJson: '["writing", "organizing"]',
        direction: ProblemDirection.depreciating,
        directionRationale: 'AI can generate docs from code',
        evidenceAiCheaper: 'AI writes documentation faster',
        evidenceErrorCost: 'Low error cost',
        evidenceTrustRequired: 'Low trust needed',
        timeAllocationPercent: 15,
      );

      final problem4Id = await problemRepository.create(
        name: 'Code Review',
        whatBreaks: 'Quality decreases',
        scarcitySignalsJson: '["quality", "standards"]',
        direction: ProblemDirection.stable,
        directionRationale: 'AI assists but humans judge context',
        evidenceAiCheaper: 'AI can catch some issues',
        evidenceErrorCost: 'Medium error cost',
        evidenceTrustRequired: 'Medium trust',
        timeAllocationPercent: 20,
      );

      // Verify allocation is valid
      final allocation = await problemRepository.getTotalAllocation();
      expect(allocation, 100);

      final validationError = await problemRepository.validateAllocation();
      expect(validationError, isNull);

      // Step 3: Create board members anchored to problems
      // 5 core roles
      await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
        personaBackground: 'Former operations executive',
        personaCommunicationStyle: 'Warm but relentless',
        personaSignaturePhrase: 'Show me the artifact',
        anchoredProblemId: problem1Id,
        anchoredDemand: 'What decision did you make?',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.marketReality,
        personaName: 'Alex Rivera',
        personaBackground: 'Industry analyst',
        personaCommunicationStyle: 'Data-driven, direct',
        personaSignaturePhrase: 'What does the market say?',
        anchoredProblemId: problem2Id,
        anchoredDemand: 'What external validation exists?',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.avoidance,
        personaName: 'Jordan Park',
        personaBackground: 'Behavioral psychologist',
        personaCommunicationStyle: 'Empathetic but probing',
        personaSignaturePhrase: 'What are you avoiding?',
        anchoredProblemId: problem3Id,
        anchoredDemand: 'What task is being avoided?',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.longTermPositioning,
        personaName: 'Sam Wu',
        personaBackground: 'Venture capitalist',
        personaCommunicationStyle: 'Blunt, challenging',
        personaSignaturePhrase: 'What makes you so special?',
        anchoredProblemId: problem4Id,
        anchoredDemand: 'What unique advantage do you have?',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.devilsAdvocate,
        personaName: 'Taylor Kim',
        personaBackground: 'Strategy consultant',
        personaCommunicationStyle: 'Precise, clarifying',
        personaSignaturePhrase: 'What exactly do you mean?',
        anchoredProblemId: problem1Id,
        anchoredDemand: 'Can you be more specific?',
      );

      // 2 growth roles (inactive by default)
      await boardMemberRepository.create(
        roleType: BoardRoleType.portfolioDefender,
        personaName: 'Chris Lee',
        personaBackground: 'Investment strategist',
        personaCommunicationStyle: 'Analytical, protective',
        isGrowthRole: true,
        isActive: false,
        anchoredProblemId: problem1Id,
        anchoredDemand: 'What threatens your appreciating work?',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.opportunityScout,
        personaName: 'Drew Morgan',
        personaBackground: 'Innovation scout',
        personaCommunicationStyle: 'Enthusiastic, forward-looking',
        isGrowthRole: true,
        isActive: false,
        anchoredProblemId: problem2Id,
        anchoredDemand: 'What new opportunities exist?',
      );

      // Verify board composition
      final coreRoles = await boardMemberRepository.getCoreRoles();
      expect(coreRoles.length, 5);

      final growthRoles = await boardMemberRepository.getGrowthRoles();
      expect(growthRoles.length, 2);
      expect(growthRoles.every((r) => !r.isActive), isTrue);

      // Step 4: Create portfolio version snapshot
      final portfolioVersionId = await portfolioVersionRepository.create(
        versionNumber: 1,
        problemsSnapshotJson: '[{"id": "$problem1Id", "name": "Technical Architecture"}]',
        healthSnapshotJson: '{}',
        boardAnchoringSnapshotJson: '[]',
        triggersSnapshotJson: '{}',
        triggerReason: 'Initial setup from session $sessionId',
      );

      // Step 5: Complete the setup session
      await sessionRepository.complete(
        sessionId,
        outputMarkdown: '# Setup Complete\n\nPortfolio created with 4 problems.',
        createdPortfolioVersionId: portfolioVersionId,
      );

      // Verify session completion
      final session = await sessionRepository.getById(sessionId);
      expect(session!.isCompleted, isTrue);
      expect(session.createdPortfolioVersionId, portfolioVersionId);
    });

    test('growth roles activate when appreciating problems exist', () async {
      // Create problems with one appreciating
      await problemRepository.create(
        name: 'Appreciating Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 50,
      );

      await problemRepository.create(
        name: 'Depreciating Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.depreciating,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 50,
      );

      // Create growth roles (inactive)
      await boardMemberRepository.create(
        roleType: BoardRoleType.portfolioDefender,
        personaName: 'Defender',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
        isGrowthRole: true,
        isActive: false,
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.opportunityScout,
        personaName: 'Scout',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
        isGrowthRole: true,
        isActive: false,
      );

      // Check for appreciating problems
      final hasAppreciating = await problemRepository.hasAppreciatingProblems();
      expect(hasAppreciating, isTrue);

      // Activate growth roles since appreciating problems exist
      await boardMemberRepository.setGrowthRolesActive(true);

      // Verify activation
      final growthRoles = await boardMemberRepository.getGrowthRoles();
      expect(growthRoles.every((r) => r.isActive), isTrue);
    });

    test('growth roles remain inactive when no appreciating problems', () async {
      // Create only depreciating/stable problems
      await problemRepository.create(
        name: 'Depreciating Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.depreciating,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 60,
      );

      await problemRepository.create(
        name: 'Stable Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 40,
      );

      // Create growth roles
      await boardMemberRepository.create(
        roleType: BoardRoleType.portfolioDefender,
        personaName: 'Defender',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
        isGrowthRole: true,
        isActive: false,
      );

      // Check for appreciating problems
      final hasAppreciating = await problemRepository.hasAppreciatingProblems();
      expect(hasAppreciating, isFalse);

      // Growth roles should remain inactive
      final growthRoles = await boardMemberRepository.getGrowthRoles();
      expect(growthRoles.every((r) => !r.isActive), isTrue);
    });

    test('problem allocation constraints are enforced', () async {
      // Create problems with allocation below 90%
      await problemRepository.create(
        name: 'Problem 1',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 25,
      );

      await problemRepository.create(
        name: 'Problem 2',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 25,
      );

      await problemRepository.create(
        name: 'Problem 3',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 25,
      );

      // Total is 75%, which is below 90%
      final total = await problemRepository.getTotalAllocation();
      expect(total, 75);

      final error = await problemRepository.validateAllocation();
      expect(error, isNotNull);
      expect(error, contains('too low'));
    });

    test('minimum 3 problems enforced', () async {
      // Create exactly 3 problems
      final id1 = await problemRepository.create(
        name: 'Problem 1',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 34,
      );

      await problemRepository.create(
        name: 'Problem 2',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 33,
      );

      await problemRepository.create(
        name: 'Problem 3',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 33,
      );

      // Trying to delete below minimum should fail
      final deleteResult = await problemRepository.softDelete(id1);
      expect(deleteResult, isFalse);

      final count = await problemRepository.getCount();
      expect(count, 3);
    });

    test('board member anchoring updated when problem changes', () async {
      // Create problem
      final problemId = await problemRepository.create(
        name: 'Original Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      // Create board member anchored to problem
      final memberId = await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Test Member',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
        anchoredProblemId: problemId,
        anchoredDemand: 'Original demand',
      );

      // Verify anchoring
      var members = await boardMemberRepository.getByAnchoredProblem(problemId);
      expect(members.length, 1);
      expect(members[0].anchoredDemand, 'Original demand');

      // Update anchoring
      await boardMemberRepository.updateAnchoring(
        memberId,
        problemId: problemId,
        demand: 'Updated demand',
      );

      // Verify updated
      final member = await boardMemberRepository.getById(memberId);
      expect(member!.anchoredDemand, 'Updated demand');
    });
  });
}
