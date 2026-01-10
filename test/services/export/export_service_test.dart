import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/models/export_format.dart';
import 'package:boardroom_journal/services/export/export_service.dart';

void main() {
  late AppDatabase database;
  late ExportService exportService;

  // Repositories
  late DailyEntryRepository dailyEntryRepo;
  late WeeklyBriefRepository weeklyBriefRepo;
  late ProblemRepository problemRepo;
  late PortfolioVersionRepository portfolioVersionRepo;
  late BoardMemberRepository boardMemberRepo;
  late GovernanceSessionRepository governanceSessionRepo;
  late BetRepository betRepo;
  late EvidenceItemRepository evidenceItemRepo;
  late ReSetupTriggerRepository reSetupTriggerRepo;
  late UserPreferencesRepository userPreferencesRepo;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());

    dailyEntryRepo = DailyEntryRepository(database);
    weeklyBriefRepo = WeeklyBriefRepository(database);
    problemRepo = ProblemRepository(database);
    portfolioVersionRepo = PortfolioVersionRepository(database);
    boardMemberRepo = BoardMemberRepository(database);
    governanceSessionRepo = GovernanceSessionRepository(database);
    betRepo = BetRepository(database);
    evidenceItemRepo = EvidenceItemRepository(database);
    reSetupTriggerRepo = ReSetupTriggerRepository(database);
    userPreferencesRepo = UserPreferencesRepository(database);

    exportService = ExportService(
      dailyEntryRepository: dailyEntryRepo,
      weeklyBriefRepository: weeklyBriefRepo,
      problemRepository: problemRepo,
      portfolioVersionRepository: portfolioVersionRepo,
      boardMemberRepository: boardMemberRepo,
      governanceSessionRepository: governanceSessionRepo,
      betRepository: betRepo,
      evidenceItemRepository: evidenceItemRepo,
      reSetupTriggerRepository: reSetupTriggerRepo,
      userPreferencesRepository: userPreferencesRepo,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('ExportService', () {
    group('getExportData', () {
      test('returns empty export data when database is empty', () async {
        final data = await exportService.getExportData();

        expect(data.version, exportFormatVersion);
        expect(data.dailyEntries, isEmpty);
        expect(data.weeklyBriefs, isEmpty);
        expect(data.problems, isEmpty);
        expect(data.portfolioVersions, isEmpty);
        expect(data.boardMembers, isEmpty);
        expect(data.governanceSessions, isEmpty);
        expect(data.bets, isEmpty);
        expect(data.evidenceItems, isEmpty);
        expect(data.reSetupTriggers, isEmpty);
        expect(data.userPreferences, isNotNull);
      });

      test('includes daily entries in export', () async {
        await dailyEntryRepo.create(
          transcriptRaw: 'Test entry',
          transcriptEdited: 'Test entry edited',
          entryType: EntryType.text,
          timezone: 'America/New_York',
        );

        final data = await exportService.getExportData();

        expect(data.dailyEntries.length, 1);
        expect(data.dailyEntries[0].transcriptEdited, 'Test entry edited');
      });

      test('includes weekly briefs in export', () async {
        final now = DateTime.now().toUtc();
        await weeklyBriefRepo.create(
          weekStartUtc: now.subtract(const Duration(days: 7)),
          weekEndUtc: now,
          weekTimezone: 'America/New_York',
          briefMarkdown: '# Weekly Brief\n\nTest content.',
        );

        final data = await exportService.getExportData();

        expect(data.weeklyBriefs.length, 1);
        expect(data.weeklyBriefs[0].briefMarkdown, contains('Weekly Brief'));
      });

      test('includes bets in export', () async {
        await betRepo.create(
          prediction: 'I predict this will happen',
          wrongIf: 'This does not happen',
        );

        final data = await exportService.getExportData();

        expect(data.bets.length, 1);
        expect(data.bets[0].prediction, 'I predict this will happen');
      });

      test('includes governance sessions in export', () async {
        await governanceSessionRepo.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'initial',
        );

        final data = await exportService.getExportData();

        expect(data.governanceSessions.length, 1);
        expect(data.governanceSessions[0].sessionType, 'quick');
      });
    });

    group('exportToJson', () {
      test('exports valid JSON format', () async {
        await dailyEntryRepo.create(
          transcriptRaw: 'Test entry',
          transcriptEdited: 'Test entry',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final jsonString = await exportService.exportToJson();

        expect(() => jsonDecode(jsonString), returnsNormally);

        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(json['version'], exportFormatVersion);
        expect(json['exportedAt'], isNotNull);
        expect(json['data'], isA<Map<String, dynamic>>());
      });

      test('includes all required fields in JSON export', () async {
        final jsonString = await exportService.exportToJson();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;

        expect(data.containsKey('dailyEntries'), isTrue);
        expect(data.containsKey('weeklyBriefs'), isTrue);
        expect(data.containsKey('problems'), isTrue);
        expect(data.containsKey('portfolioVersions'), isTrue);
        expect(data.containsKey('boardMembers'), isTrue);
        expect(data.containsKey('governanceSessions'), isTrue);
        expect(data.containsKey('bets'), isTrue);
        expect(data.containsKey('evidenceItems'), isTrue);
        expect(data.containsKey('reSetupTriggers'), isTrue);
        expect(data.containsKey('userPreferences'), isTrue);
      });

      test('exports daily entry with all fields', () async {
        await dailyEntryRepo.create(
          transcriptRaw: 'Raw text',
          transcriptEdited: 'Edited text',
          entryType: EntryType.voice,
          timezone: 'America/Los_Angeles',
          durationSeconds: 300,
          extractedSignalsJson: '{"wins": ["test win"]}',
        );

        final jsonString = await exportService.exportToJson();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final entries = json['data']['dailyEntries'] as List;

        expect(entries.length, 1);
        final entry = entries[0] as Map<String, dynamic>;

        expect(entry['transcriptRaw'], 'Raw text');
        expect(entry['transcriptEdited'], 'Edited text');
        expect(entry['entryType'], 'voice');
        expect(entry['createdAtTimezone'], 'America/Los_Angeles');
        expect(entry['durationSeconds'], 300);
        expect(entry['extractedSignalsJson'], '{"wins": ["test win"]}');
      });
    });

    group('exportToMarkdown', () {
      test('exports human-readable Markdown', () async {
        await dailyEntryRepo.create(
          transcriptRaw: 'Test entry content',
          transcriptEdited: 'Test entry content',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final markdown = await exportService.exportToMarkdown();

        expect(markdown, contains('# Boardroom Journal Export'));
        expect(markdown, contains('## Summary'));
        expect(markdown, contains('## Daily Entries'));
        expect(markdown, contains('Test entry content'));
      });

      test('includes summary table in Markdown', () async {
        await dailyEntryRepo.create(
          transcriptRaw: 'Entry 1',
          transcriptEdited: 'Entry 1',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await dailyEntryRepo.create(
          transcriptRaw: 'Entry 2',
          transcriptEdited: 'Entry 2',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final markdown = await exportService.exportToMarkdown();

        expect(markdown, contains('| Daily Entries | 2 |'));
      });

      test('includes bets section in Markdown', () async {
        await betRepo.create(
          prediction: 'Market will grow by 20%',
          wrongIf: 'Market shrinks or stays flat',
        );

        final markdown = await exportService.exportToMarkdown();

        expect(markdown, contains('## Bets'));
        expect(markdown, contains('Market will grow by 20%'));
        expect(markdown, contains('Market shrinks or stays flat'));
      });

      test('includes board members section in Markdown', () async {
        await boardMemberRepo.create(
          roleType: BoardRoleType.challenger,
          personaName: 'Dr. Sarah Chen',
          personaBackground: 'Former CEO with 20 years experience',
          personaCommunicationStyle: 'Direct and challenging',
        );

        final markdown = await exportService.exportToMarkdown();

        expect(markdown, contains('## Board Members'));
        expect(markdown, contains('Dr. Sarah Chen'));
        expect(markdown, contains('challenger'));
      });
    });

    group('getExportPreview', () {
      test('returns correct summary counts', () async {
        // Create various data
        await dailyEntryRepo.create(
          transcriptRaw: 'Entry 1',
          transcriptEdited: 'Entry 1',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await dailyEntryRepo.create(
          transcriptRaw: 'Entry 2',
          transcriptEdited: 'Entry 2',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await betRepo.create(
          prediction: 'Test bet',
          wrongIf: 'Test condition',
        );

        final preview = await exportService.getExportPreview();

        expect(preview.dailyEntriesCount, 2);
        expect(preview.betsCount, 1);
        expect(preview.hasUserPreferences, isTrue);
      });

      test('returns zero counts for empty database', () async {
        final preview = await exportService.getExportPreview();

        expect(preview.dailyEntriesCount, 0);
        expect(preview.weeklyBriefsCount, 0);
        expect(preview.betsCount, 0);
        expect(preview.governanceSessionsCount, 0);
      });
    });
  });

  group('ExportData', () {
    test('empty factory creates valid structure', () {
      final data = ExportData.empty();

      expect(data.version, exportFormatVersion);
      expect(data.exportedAt, isA<DateTime>());
      expect(data.dailyEntries, isEmpty);
      expect(data.totalItemCount, 0);
    });

    test('totalItemCount sums all data types', () {
      final data = ExportData(
        version: '1.0',
        exportedAt: DateTime.now(),
        dailyEntries: List.generate(
          5,
          (i) => DailyEntry(
            id: 'entry-$i',
            transcriptRaw: 'Raw $i',
            transcriptEdited: 'Edited $i',
            extractedSignalsJson: '{}',
            entryType: 'text',
            wordCount: 10,
            createdAtUtc: DateTime.now(),
            createdAtTimezone: 'UTC',
            updatedAtUtc: DateTime.now(),
            syncStatus: 'pending',
            serverVersion: 0,
          ),
        ),
        bets: List.generate(
          3,
          (i) => Bet(
            id: 'bet-$i',
            prediction: 'Prediction $i',
            wrongIf: 'Wrong if $i',
            status: 'open',
            createdAtUtc: DateTime.now(),
            dueAtUtc: DateTime.now(),
            updatedAtUtc: DateTime.now(),
            syncStatus: 'pending',
            serverVersion: 0,
          ),
        ),
      );

      expect(data.totalItemCount, 8); // 5 entries + 3 bets
    });

    test('summary reflects data counts', () {
      final data = ExportData(
        version: '1.0',
        exportedAt: DateTime.now(),
        dailyEntries: List.generate(
          2,
          (i) => DailyEntry(
            id: 'entry-$i',
            transcriptRaw: 'Raw $i',
            transcriptEdited: 'Edited $i',
            extractedSignalsJson: '{}',
            entryType: 'text',
            wordCount: 10,
            createdAtUtc: DateTime.now(),
            createdAtTimezone: 'UTC',
            updatedAtUtc: DateTime.now(),
            syncStatus: 'pending',
            serverVersion: 0,
          ),
        ),
      );

      final summary = data.summary;
      expect(summary.dailyEntriesCount, 2);
      expect(summary.weeklyBriefsCount, 0);
      expect(summary.totalCount, 2);
    });
  });
}
