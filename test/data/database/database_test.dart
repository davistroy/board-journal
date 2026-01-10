import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/database/database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  const uuid = Uuid();

  setUp(() {
    // Use in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('DailyEntries', () {
    test('can insert and retrieve a daily entry', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.dailyEntries).insert(
            DailyEntriesCompanion.insert(
              id: id,
              transcriptRaw: 'Today was a productive day.',
              transcriptEdited: 'Today was a productive day.',
              entryType: 'text',
              createdAtUtc: now,
              createdAtTimezone: 'America/New_York',
              updatedAtUtc: now,
            ),
          );

      final entries = await database.select(database.dailyEntries).get();
      expect(entries.length, 1);
      expect(entries.first.id, id);
      expect(entries.first.transcriptRaw, 'Today was a productive day.');
      expect(entries.first.entryType, 'text');
    });

    test('can update a daily entry', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.dailyEntries).insert(
            DailyEntriesCompanion.insert(
              id: id,
              transcriptRaw: 'Original text.',
              transcriptEdited: 'Original text.',
              entryType: 'text',
              createdAtUtc: now,
              createdAtTimezone: 'America/New_York',
              updatedAtUtc: now,
            ),
          );

      await (database.update(database.dailyEntries)
            ..where((e) => e.id.equals(id)))
          .write(
        const DailyEntriesCompanion(
          transcriptEdited: Value('Edited text.'),
        ),
      );

      final entry = await (database.select(database.dailyEntries)
            ..where((e) => e.id.equals(id)))
          .getSingle();

      expect(entry.transcriptEdited, 'Edited text.');
      expect(entry.transcriptRaw, 'Original text.'); // Raw unchanged
    });

    test('can soft delete a daily entry', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.dailyEntries).insert(
            DailyEntriesCompanion.insert(
              id: id,
              transcriptRaw: 'To be deleted.',
              transcriptEdited: 'To be deleted.',
              entryType: 'text',
              createdAtUtc: now,
              createdAtTimezone: 'America/New_York',
              updatedAtUtc: now,
            ),
          );

      await (database.update(database.dailyEntries)
            ..where((e) => e.id.equals(id)))
          .write(
        DailyEntriesCompanion(
          deletedAtUtc: Value(DateTime.now().toUtc()),
        ),
      );

      // Entry still exists but has deletedAtUtc set
      final entry = await (database.select(database.dailyEntries)
            ..where((e) => e.id.equals(id)))
          .getSingle();

      expect(entry.deletedAtUtc, isNotNull);
    });
  });

  group('Bets', () {
    test('can insert and retrieve a bet', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();
      final dueDate = now.add(const Duration(days: 90));

      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: id,
              prediction: 'I will complete the MVP by Q2.',
              wrongIf: 'No working prototype exists by June 30.',
              createdAtUtc: now,
              dueAtUtc: dueDate,
              updatedAtUtc: now,
            ),
          );

      final bets = await database.select(database.bets).get();
      expect(bets.length, 1);
      expect(bets.first.status, 'open');
      expect(bets.first.prediction, 'I will complete the MVP by Q2.');
    });

    test('can update bet status', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();
      final dueDate = now.add(const Duration(days: 90));

      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: id,
              prediction: 'Test prediction.',
              wrongIf: 'Test wrong-if.',
              createdAtUtc: now,
              dueAtUtc: dueDate,
              updatedAtUtc: now,
            ),
          );

      await (database.update(database.bets)..where((b) => b.id.equals(id)))
          .write(
        const BetsCompanion(
          status: Value('correct'),
        ),
      );

      final bet = await (database.select(database.bets)
            ..where((b) => b.id.equals(id)))
          .getSingle();

      expect(bet.status, 'correct');
    });
  });

  group('Problems', () {
    test('can insert and retrieve a problem', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.problems).insert(
            ProblemsCompanion.insert(
              id: id,
              name: 'Strategic Decision Making',
              whatBreaks: 'Team loses direction without clear decisions.',
              scarcitySignalsJson: '["judgment required", "context-dependent"]',
              direction: 'appreciating',
              directionRationale: 'AI cannot replicate organizational context.',
              evidenceAiCheaper: 'AI provides options but cannot decide.',
              evidenceErrorCost: 'Bad decisions cost months of work.',
              evidenceTrustRequired: 'Stakeholders need to trust the decider.',
              timeAllocationPercent: 30,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      final problems = await database.select(database.problems).get();
      expect(problems.length, 1);
      expect(problems.first.name, 'Strategic Decision Making');
      expect(problems.first.direction, 'appreciating');
      expect(problems.first.timeAllocationPercent, 30);
    });
  });

  group('BoardMembers', () {
    test('can insert and retrieve a board member', () async {
      final id = uuid.v4();
      final problemId = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.boardMembers).insert(
            BoardMembersCompanion.insert(
              id: id,
              roleType: 'accountability',
              anchoredProblemId: Value(problemId),
              anchoredDemand: const Value('Show me the calendar.'),
              personaName: 'Maya Chen',
              personaBackground: 'Former operations executive.',
              personaCommunicationStyle: 'Warm but relentless.',
              personaSignaturePhrase:
                  const Value('I believe you believe that. Now show me the artifact.'),
              originalPersonaName: 'Maya Chen',
              originalPersonaBackground: 'Former operations executive.',
              originalPersonaCommunicationStyle: 'Warm but relentless.',
              originalPersonaSignaturePhrase:
                  const Value('I believe you believe that. Now show me the artifact.'),
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      final members = await database.select(database.boardMembers).get();
      expect(members.length, 1);
      expect(members.first.roleType, 'accountability');
      expect(members.first.personaName, 'Maya Chen');
      expect(members.first.isGrowthRole, false);
    });
  });

  group('GovernanceSessions', () {
    test('can insert and retrieve a governance session', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();

      await database.into(database.governanceSessions).insert(
            GovernanceSessionsCompanion.insert(
              id: id,
              sessionType: 'quick',
              currentState: 'q1_role_context',
              startedAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      final sessions = await database.select(database.governanceSessions).get();
      expect(sessions.length, 1);
      expect(sessions.first.sessionType, 'quick');
      expect(sessions.first.isCompleted, false);
    });
  });

  group('WeeklyBriefs', () {
    test('can insert and retrieve a weekly brief', () async {
      final id = uuid.v4();
      final now = DateTime.now().toUtc();
      final weekStart = DateTime.utc(2026, 1, 6); // A Monday
      final weekEnd = DateTime.utc(2026, 1, 12, 23, 59, 59);

      await database.into(database.weeklyBriefs).insert(
            WeeklyBriefsCompanion.insert(
              id: id,
              weekStartUtc: weekStart,
              weekEndUtc: weekEnd,
              weekTimezone: 'America/New_York',
              briefMarkdown: '# Weekly Brief\n\nThis was a productive week.',
              generatedAtUtc: now,
              updatedAtUtc: now,
            ),
          );

      final briefs = await database.select(database.weeklyBriefs).get();
      expect(briefs.length, 1);
      expect(briefs.first.regenCount, 0);
      expect(briefs.first.briefMarkdown, contains('Weekly Brief'));
    });
  });
}
