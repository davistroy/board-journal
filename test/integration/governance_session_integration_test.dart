import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

/// Integration tests for governance session workflows.
///
/// Per PRD Section 4.3-4.5:
/// - Quick Version: 5 questions, 15 minutes
/// - Setup: Portfolio + Board + Personas
/// - Quarterly: Full report with board interrogation
void main() {
  late AppDatabase database;
  late GovernanceSessionRepository sessionRepository;
  late BetRepository betRepository;
  late ProblemRepository problemRepository;
  late BoardMemberRepository boardMemberRepository;
  late PortfolioVersionRepository portfolioVersionRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sessionRepository = GovernanceSessionRepository(database);
    betRepository = BetRepository(database);
    problemRepository = ProblemRepository(database);
    boardMemberRepository = BoardMemberRepository(database);
    portfolioVersionRepository = PortfolioVersionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Quick Version Session Flow', () {
    test('complete quick version session with state progression', () async {
      // Create session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'sensitivity_gate',
      );

      // Progress through FSM states
      await sessionRepository.updateState(sessionId, 'q1_role_context');
      await sessionRepository.appendToTranscript(
        sessionId,
        '{"q1": {"question": "What role context?", "answer": "Engineering lead"}}',
      );

      await sessionRepository.updateState(sessionId, 'q2_this_week');
      await sessionRepository.appendToTranscript(
        sessionId,
        '{"q2": {"question": "This week?", "answer": "Working on features"}}',
      );

      await sessionRepository.updateState(sessionId, 'q3_biggest_win');
      await sessionRepository.appendToTranscript(
        sessionId,
        '{"q3": {"question": "Biggest win?", "answer": "Shipped feature X"}}',
      );

      await sessionRepository.updateState(sessionId, 'q4_challenge');
      await sessionRepository.appendToTranscript(
        sessionId,
        '{"q4": {"question": "Challenge?", "answer": "Technical debt"}}',
      );

      await sessionRepository.updateState(sessionId, 'q5_next_step');
      await sessionRepository.appendToTranscript(
        sessionId,
        '{"q5": {"question": "Next step?", "answer": "Refactor module"}}',
      );

      // Complete session
      await sessionRepository.complete(
        sessionId,
        outputMarkdown: '# Quick Audit Summary\n\n- Role: Engineering Lead\n- Win: Shipped feature X',
      );

      // Verify completion
      final session = await sessionRepository.getById(sessionId);
      expect(session!.isCompleted, isTrue);
      expect(session.outputMarkdown, contains('Quick Audit Summary'));
      expect(session.durationSeconds, isNotNull);
    });

    test('vagueness gating enforces max 2 skips', () async {
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'q1_role_context',
      );

      // First skip allowed
      var canSkip = await sessionRepository.incrementVaguenessSkip(sessionId);
      expect(canSkip, isTrue);
      expect(await sessionRepository.getRemainingSkips(sessionId), 1);

      // Second skip allowed
      canSkip = await sessionRepository.incrementVaguenessSkip(sessionId);
      expect(canSkip, isTrue);
      expect(await sessionRepository.getRemainingSkips(sessionId), 0);

      // Third skip blocked
      canSkip = await sessionRepository.incrementVaguenessSkip(sessionId);
      expect(canSkip, isFalse);

      final session = await sessionRepository.getById(sessionId);
      expect(session!.vaguenessSkipCount, 2);
    });

    test('abstraction mode preserved throughout session', () async {
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'sensitivity_gate',
        abstractionMode: true,
      );

      // Progress through states
      await sessionRepository.updateState(sessionId, 'q1_role_context');
      await sessionRepository.updateState(sessionId, 'q2_this_week');

      // Verify abstraction mode preserved
      final session = await sessionRepository.getById(sessionId);
      expect(session!.abstractionMode, isTrue);
    });
  });

  group('Setup Session Flow', () {
    test('setup session creates portfolio version on completion', () async {
      // Start setup session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'problems_intro',
      );

      // Create problems
      await problemRepository.create(
        name: 'Problem 1',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 50,
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
        timeAllocationPercent: 50,
      );

      // Create portfolio version
      final portfolioVersionId = await portfolioVersionRepository.create(
        versionNumber: 1,
        problemsSnapshotJson: '[]',
        healthSnapshotJson: '{}',
        boardAnchoringSnapshotJson: '[]',
        triggersSnapshotJson: '{}',
        triggerReason: 'Setup session $sessionId',
      );

      // Complete setup session
      await sessionRepository.complete(
        sessionId,
        outputMarkdown: '# Setup Complete',
        createdPortfolioVersionId: portfolioVersionId,
      );

      // Verify session linked to portfolio version
      final session = await sessionRepository.getById(sessionId);
      expect(session!.isCompleted, isTrue);
      expect(session.createdPortfolioVersionId, portfolioVersionId);

      // Verify portfolio version exists
      final version = await portfolioVersionRepository.getById(portfolioVersionId);
      expect(version, isNotNull);
      expect(version!.triggerReason, contains('Setup session'));
    });
  });

  group('Quarterly Session Flow', () {
    test('quarterly session evaluates bet and creates new bet', () async {
      // Create an open bet to evaluate
      final oldBetId = await betRepository.create(
        prediction: 'Q2 MVP will be complete',
        wrongIf: 'No working prototype by June 30',
      );

      // Start quarterly session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );

      // Evaluate the old bet as correct
      await betRepository.evaluate(
        oldBetId,
        newStatus: BetStatus.correct,
        evaluationNotes: 'MVP was shipped on time',
        evaluationSessionId: sessionId,
      );

      // Create new bet
      final newBetId = await betRepository.create(
        prediction: 'Q3 user growth will hit 1000',
        wrongIf: 'User count below 800 by September 30',
        sourceSessionId: sessionId,
      );

      // Complete quarterly session
      await sessionRepository.complete(
        sessionId,
        outputMarkdown: '# Quarterly Report\n\nBet evaluated: correct',
        evaluatedBetId: oldBetId,
        createdBetId: newBetId,
      );

      // Verify session completion with bet references
      final session = await sessionRepository.getById(sessionId);
      expect(session!.isCompleted, isTrue);
      expect(session.evaluatedBetId, oldBetId);
      expect(session.createdBetId, newBetId);

      // Verify old bet is evaluated
      final oldBet = await betRepository.getById(oldBetId);
      expect(oldBet!.status, 'correct');
      expect(oldBet.evaluationSessionId, sessionId);

      // Verify new bet exists
      final newBet = await betRepository.getById(newBetId);
      expect(newBet!.sourceSessionId, sessionId);
    });

    test('quarterly session warns if recent report exists', () async {
      // Complete a quarterly session
      final firstSessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );
      await sessionRepository.complete(
        firstSessionId,
        outputMarkdown: '# First Quarterly',
      );

      // Check for recent quarterly report
      final hasRecent = await sessionRepository.hasRecentQuarterlyReport();
      expect(hasRecent, isTrue);

      // Create another quarterly session - should show warning
      final secondSessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );

      // The app would show a warning here based on hasRecentQuarterlyReport
      final session = await sessionRepository.getById(secondSessionId);
      expect(session, isNotNull);
    });
  });

  group('Session Rate Limiting', () {
    test('counts sessions per period for rate limiting visibility', () async {
      final now = DateTime.now().toUtc();

      // Create multiple quick sessions
      await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'start',
      );
      await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'start',
      );
      await sessionRepository.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'start',
      );

      // Count quick sessions in the current day
      final range = DateRange(
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 1)),
      );

      final quickCount = await sessionRepository.getSessionCountForPeriod(
        GovernanceSessionType.quick,
        range,
      );
      expect(quickCount, 2);

      final setupCount = await sessionRepository.getSessionCountForPeriod(
        GovernanceSessionType.setup,
        range,
      );
      expect(setupCount, 1);
    });
  });

  group('Session Recovery', () {
    test('in-progress session can be resumed', () async {
      // Start a session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'q1_role_context',
      );

      // Update state partway through
      await sessionRepository.updateState(sessionId, 'q3_biggest_win');

      // Get in-progress session (simulating app restart)
      final inProgress = await sessionRepository.getInProgress();
      expect(inProgress, isNotNull);
      expect(inProgress!.id, sessionId);
      expect(inProgress.currentState, 'q3_biggest_win');

      // Continue from where we left off
      await sessionRepository.updateState(sessionId, 'q4_challenge');
    });

    test('abandoned session excluded from in-progress', () async {
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'q1_role_context',
      );

      await sessionRepository.abandon(sessionId);

      final inProgress = await sessionRepository.getInProgress();
      expect(inProgress, isNull);
    });
  });

  group('Cross-Session Data Flow', () {
    test('board members from setup available in quick version', () async {
      // Complete setup with board members
      final setupSessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'start',
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya',
        personaBackground: 'Ops exec',
        personaCommunicationStyle: 'Warm',
      );

      await sessionRepository.complete(
        setupSessionId,
        outputMarkdown: '# Setup Complete',
      );

      // Start quick version session
      await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'sensitivity_gate',
      );

      // Board members should be available
      final members = await boardMemberRepository.getActive();
      expect(members.isNotEmpty, isTrue);
    });
  });
}
