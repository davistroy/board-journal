import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

/// Integration tests for cross-repository operations.
///
/// Tests interactions between multiple repositories including:
/// - Daily entries → Weekly briefs
/// - Problems → Board members
/// - Sync status across repositories
void main() {
  late AppDatabase database;
  late DailyEntryRepository entryRepository;
  late WeeklyBriefRepository briefRepository;
  late ProblemRepository problemRepository;
  late BoardMemberRepository boardMemberRepository;
  late GovernanceSessionRepository sessionRepository;
  late PortfolioVersionRepository portfolioVersionRepository;
  late EvidenceItemRepository evidenceRepository;
  late BetRepository betRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepository = DailyEntryRepository(database);
    briefRepository = WeeklyBriefRepository(database);
    problemRepository = ProblemRepository(database);
    boardMemberRepository = BoardMemberRepository(database);
    sessionRepository = GovernanceSessionRepository(database);
    portfolioVersionRepository = PortfolioVersionRepository(database);
    evidenceRepository = EvidenceItemRepository(database);
    betRepository = BetRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Daily Entries to Weekly Brief', () {
    test('weekly brief aggregates entries from the week', () async {
      final now = DateTime.now().toUtc();
      final weekRange = DateRange.forWeek(now);

      // Create multiple entries this week
      await entryRepository.create(
        transcriptRaw: 'Monday entry about project kickoff',
        transcriptEdited: 'Monday entry about project kickoff',
        entryType: EntryType.text,
        timezone: 'America/New_York',
        extractedSignalsJson: '{"wins": ["Project kickoff completed"]}',
      );

      await entryRepository.create(
        transcriptRaw: 'Tuesday entry about technical design',
        transcriptEdited: 'Tuesday entry about technical design',
        entryType: EntryType.text,
        timezone: 'America/New_York',
        extractedSignalsJson: '{"wins": ["Design approved"], "blockers": ["API delay"]}',
      );

      await entryRepository.create(
        transcriptRaw: 'Friday entry about sprint completion',
        transcriptEdited: 'Friday entry about sprint completion',
        entryType: EntryType.voice,
        timezone: 'America/New_York',
        durationSeconds: 300,
        extractedSignalsJson: '{"wins": ["Sprint completed"], "learnings": ["Better estimation needed"]}',
      );

      // Get entries for the week
      final weekEntries = await entryRepository.getEntriesForWeek(now);
      expect(weekEntries.length, 3);

      // Create weekly brief based on entries
      final briefId = await briefRepository.create(
        weekStartUtc: weekRange.start,
        weekEndUtc: weekRange.end,
        weekTimezone: 'America/New_York',
        briefMarkdown: '''
# Weekly Brief

## Summary
This week focused on project kickoff and initial sprint.

## Wins
- Project kickoff completed
- Design approved
- Sprint completed

## Blockers
- API delay

## Learnings
- Better estimation needed
''',
        entryCount: weekEntries.length,
      );

      final brief = await briefRepository.getById(briefId);
      expect(brief, isNotNull);
      expect(brief!.briefMarkdown, contains('Project kickoff'));
      expect(brief.entryCount, 3);
    });

    test('entry count for setup trigger tracks total entries', () async {
      // Create entries
      for (var i = 0; i < 5; i++) {
        await entryRepository.create(
          transcriptRaw: 'Entry $i',
          transcriptEdited: 'Entry $i',
          entryType: EntryType.text,
          timezone: 'UTC',
        );
      }

      // Check total count (for setup prompt trigger after 3-5 entries)
      final totalCount = await entryRepository.getTotalEntryCount();
      expect(totalCount, 5);
    });
  });

  group('Problems and Board Members', () {
    test('board member anchoring references valid problem', () async {
      // Create problem
      final problemId = await problemRepository.create(
        name: 'Strategic Planning',
        whatBreaks: 'Direction unclear',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'High human judgment required',
        evidenceAiCheaper: 'AI cannot decide strategy',
        evidenceErrorCost: 'Bad strategy costs months',
        evidenceTrustRequired: 'High trust needed',
        timeAllocationPercent: 100,
      );

      // Create board member anchored to problem
      final memberId = await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya Chen',
        personaBackground: 'Operations executive',
        personaCommunicationStyle: 'Warm but relentless',
        anchoredProblemId: problemId,
        anchoredDemand: 'Show me the decision artifact',
      );

      // Verify anchoring
      final members = await boardMemberRepository.getByAnchoredProblem(problemId);
      expect(members.length, 1);
      expect(members[0].id, memberId);

      // Get problem
      final problem = await problemRepository.getById(problemId);
      expect(problem, isNotNull);
    });

    test('highest appreciating problem determines growth role anchoring', () async {
      // Create problems with different allocations
      await problemRepository.create(
        name: 'Low Allocation Appreciating',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 20,
      );

      final highAlloc = await problemRepository.create(
        name: 'High Allocation Appreciating',
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
        timeAllocationPercent: 30,
      );

      // Get highest appreciating for growth role anchoring
      final highest = await problemRepository.getHighestAppreciating();
      expect(highest, isNotNull);
      expect(highest!.id, highAlloc);
      expect(highest.timeAllocationPercent, 50);
    });
  });

  group('Portfolio Versioning', () {
    test('portfolio version captures snapshot of problems and members', () async {
      // Create problems
      final problemId = await problemRepository.create(
        name: 'Problem 1',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      // Create board member
      final memberId = await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Test',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
      );

      // Create portfolio version
      final versionId = await portfolioVersionRepository.create(
        versionNumber: 1,
        problemsSnapshotJson: '[{"id": "$problemId", "name": "Problem 1", "allocation": 100}]',
        healthSnapshotJson: '{}',
        boardAnchoringSnapshotJson: '[{"id": "$memberId", "name": "Test", "role": "accountability"}]',
        triggersSnapshotJson: '{}',
        triggerReason: 'Initial setup',
      );

      // Verify version
      final version = await portfolioVersionRepository.getById(versionId);
      expect(version, isNotNull);
      expect(version!.problemsSnapshotJson, contains('Problem 1'));
      expect(version.boardAnchoringSnapshotJson, contains('accountability'));

      // Get current version
      final current = await portfolioVersionRepository.getCurrent();
      expect(current!.id, versionId);
    });
  });

  group('Sync Status Coordination', () {
    test('all repositories track sync status consistently', () async {
      // Create entities in multiple repositories
      final entryId = await entryRepository.create(
        transcriptRaw: 'Test',
        transcriptEdited: 'Test',
        entryType: EntryType.text,
        timezone: 'UTC',
      );

      final problemId = await problemRepository.create(
        name: 'Test Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'start',
      );

      // All should start as pending
      var entryPending = await entryRepository.getPendingSync();
      var problemPending = await problemRepository.getPendingSync();
      var sessionPending = await sessionRepository.getPendingSync();

      expect(entryPending.length, 1);
      expect(problemPending.length, 1);
      expect(sessionPending.length, 1);

      // Mark all as synced
      await entryRepository.updateSyncStatus(entryId, SyncStatus.synced, serverVersion: 1);
      await problemRepository.updateSyncStatus(problemId, SyncStatus.synced, serverVersion: 1);
      await sessionRepository.updateSyncStatus(sessionId, SyncStatus.synced, serverVersion: 1);

      // All pending lists should be empty
      entryPending = await entryRepository.getPendingSync();
      problemPending = await problemRepository.getPendingSync();
      sessionPending = await sessionRepository.getPendingSync();

      expect(entryPending, isEmpty);
      expect(problemPending, isEmpty);
      expect(sessionPending, isEmpty);
    });

    test('modifications set sync status back to pending', () async {
      final problemId = await problemRepository.create(
        name: 'Test Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      // Mark as synced
      await problemRepository.updateSyncStatus(problemId, SyncStatus.synced, serverVersion: 1);

      var pending = await problemRepository.getPendingSync();
      expect(pending, isEmpty);

      // Update the problem
      await problemRepository.update(problemId, name: 'Updated Name');

      // Should be pending again
      pending = await problemRepository.getPendingSync();
      expect(pending.length, 1);
    });
  });

  group('Evidence Linking', () {
    test('evidence item linked to session', () async {
      // Create governance session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'start',
      );

      // Create evidence linked to session
      final evidenceId = await evidenceRepository.create(
        sessionId: sessionId,
        evidenceType: EvidenceType.decision,
        statementText: 'Decision to pivot product strategy',
        strengthFlag: 'strong',
      );

      // Verify evidence
      final evidence = await evidenceRepository.getById(evidenceId);
      expect(evidence, isNotNull);
      expect(evidence!.sessionId, sessionId);

      // Get evidence for session
      final sessionEvidence = await evidenceRepository.getBySession(sessionId);
      expect(sessionEvidence.length, 1);
    });

    test('evidence linked to problem', () async {
      // Create problem
      final problemId = await problemRepository.create(
        name: 'Test Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.stable,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      // Create session for evidence
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'start',
      );

      // Create evidence linked to problem
      await evidenceRepository.create(
        sessionId: sessionId,
        problemId: problemId,
        evidenceType: EvidenceType.artifact,
        statementText: 'Design document completed',
        strengthFlag: 'strong',
      );

      // Get evidence for problem
      final problemEvidence = await evidenceRepository.getByProblem(problemId);
      expect(problemEvidence.length, 1);
    });
  });

  group('Complete Workflow Integration', () {
    test('full user journey: entries → brief → setup → governance', () async {
      final now = DateTime.now().toUtc();
      final weekRange = DateRange.forWeek(now);

      // 1. User creates daily entries
      for (var i = 0; i < 3; i++) {
        await entryRepository.create(
          transcriptRaw: 'Day $i entry',
          transcriptEdited: 'Day $i entry',
          entryType: EntryType.text,
          timezone: 'America/New_York',
        );
      }

      final totalEntries = await entryRepository.getTotalEntryCount();
      expect(totalEntries, 3);

      // 2. System generates weekly brief
      final briefId = await briefRepository.create(
        weekStartUtc: weekRange.start,
        weekEndUtc: weekRange.end,
        weekTimezone: 'America/New_York',
        briefMarkdown: '# Weekly Brief\n\nSummary of activities.',
        entryCount: totalEntries,
      );

      expect(await briefRepository.getById(briefId), isNotNull);

      // 3. User completes setup
      final setupSessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.setup,
        initialState: 'problems_intro',
      );

      final problemId = await problemRepository.create(
        name: 'Core Problem',
        whatBreaks: 'Test',
        scarcitySignalsJson: '[]',
        direction: ProblemDirection.appreciating,
        directionRationale: 'Test',
        evidenceAiCheaper: 'Test',
        evidenceErrorCost: 'Test',
        evidenceTrustRequired: 'Test',
        timeAllocationPercent: 100,
      );

      await boardMemberRepository.create(
        roleType: BoardRoleType.accountability,
        personaName: 'Maya',
        personaBackground: 'Test',
        personaCommunicationStyle: 'Test',
        anchoredProblemId: problemId,
        anchoredDemand: 'Test demand',
      );

      final portfolioVersionId = await portfolioVersionRepository.create(
        versionNumber: 1,
        problemsSnapshotJson: '[]',
        healthSnapshotJson: '{}',
        boardAnchoringSnapshotJson: '[]',
        triggersSnapshotJson: '{}',
        triggerReason: 'Initial setup',
      );

      await sessionRepository.complete(
        setupSessionId,
        outputMarkdown: '# Setup Complete',
        createdPortfolioVersionId: portfolioVersionId,
      );

      // 4. User runs quick version
      final quickSessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quick,
        initialState: 'sensitivity_gate',
      );

      await sessionRepository.updateState(quickSessionId, 'q5_next_step');
      await sessionRepository.complete(
        quickSessionId,
        outputMarkdown: '# Quick Audit Complete',
      );

      // 5. User runs quarterly
      final betId = await betRepository.create(
        prediction: 'Q3 goals achieved',
        wrongIf: 'Goals not met',
      );

      final quarterlySessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );

      await betRepository.evaluate(betId, newStatus: BetStatus.correct);

      final newBetId = await betRepository.create(
        prediction: 'Q4 expansion',
        wrongIf: 'No expansion',
        sourceSessionId: quarterlySessionId,
      );

      await sessionRepository.complete(
        quarterlySessionId,
        outputMarkdown: '# Quarterly Report',
        evaluatedBetId: betId,
        createdBetId: newBetId,
      );

      // Verify complete journey
      final allSessions = await sessionRepository.getAll();
      expect(allSessions.length, 3); // setup, quick, quarterly

      final completedSessions = await sessionRepository.getCompleted();
      expect(completedSessions.length, 3);
    });
  });

  group('Purge and Cleanup', () {
    test('purge old deleted entries', () async {
      final now = DateTime.now().toUtc();

      // Create and soft-delete an entry
      final entryId = await entryRepository.create(
        transcriptRaw: 'Old entry',
        transcriptEdited: 'Old entry',
        entryType: EntryType.text,
        timezone: 'UTC',
      );

      // Set deletedAtUtc to 31 days ago
      await (database.update(database.dailyEntries)
            ..where((e) => e.id.equals(entryId)))
          .write(DailyEntriesCompanion(
        deletedAtUtc: Value(now.subtract(const Duration(days: 31))),
      ));

      // Create recent entry (should not be purged)
      await entryRepository.create(
        transcriptRaw: 'Recent entry',
        transcriptEdited: 'Recent entry',
        entryType: EntryType.text,
        timezone: 'UTC',
      );

      // Purge
      final purgedCount = await entryRepository.purgeOldDeletedEntries();
      expect(purgedCount, 1);

      // Verify only recent entry remains
      final entries = await entryRepository.getAll();
      expect(entries.length, 1);
      expect(entries[0].transcriptRaw, 'Recent entry');
    });
  });
}
