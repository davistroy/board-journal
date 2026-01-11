import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/models/export_format.dart';
import 'package:boardroom_journal/services/export/export_service.dart';
import 'package:boardroom_journal/services/export/import_service.dart';

void main() {
  late AppDatabase database;
  late ImportService importService;
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

    importService = ImportService(
      database: database,
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

  group('ImportService', () {
    group('validateImportFile', () {
      test('fails for invalid JSON', () {
        const invalidJson = 'not valid json {';

        final result = importService.validateImportFile(invalidJson);

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
        expect(result.errors.first, contains('Invalid JSON'));
      });

      test('fails for missing version field', () {
        const json = '{"exportedAt": "2024-01-01T00:00:00Z", "data": {}}';

        final result = importService.validateImportFile(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Missing required field: version'));
      });

      test('fails for missing exportedAt field', () {
        const json = '{"version": "1.0", "data": {}}';

        final result = importService.validateImportFile(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Missing required field: exportedAt'));
      });

      test('fails for missing data field', () {
        const json = '{"version": "1.0", "exportedAt": "2024-01-01T00:00:00Z"}';

        final result = importService.validateImportFile(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Missing required field: data'));
      });

      test('succeeds for valid export JSON', () {
        final json = jsonEncode({
          'version': '1.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'data': {
            'dailyEntries': [],
            'weeklyBriefs': [],
            'problems': [],
            'portfolioVersions': [],
            'boardMembers': [],
            'governanceSessions': [],
            'bets': [],
            'evidenceItems': [],
            'reSetupTriggers': [],
            'userPreferences': null,
          },
        });

        final result = importService.validateImportFile(json);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.data, isNotNull);
      });

      test('warns for different version but still valid', () {
        final json = jsonEncode({
          'version': '2.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'data': {
            'dailyEntries': [],
            'weeklyBriefs': [],
            'problems': [],
            'portfolioVersions': [],
            'boardMembers': [],
            'governanceSessions': [],
            'bets': [],
            'evidenceItems': [],
            'reSetupTriggers': [],
            'userPreferences': null,
          },
        });

        final result = importService.validateImportFile(json);

        expect(result.isValid, isTrue);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.first, contains('version'));
      });
    });

    group('parseImportFile', () {
      test('parses daily entries correctly', () {
        final now = DateTime.now().toUtc();
        final json = jsonEncode({
          'version': '1.0',
          'exportedAt': now.toIso8601String(),
          'data': {
            'dailyEntries': [
              {
                'id': 'test-entry-1',
                'transcriptRaw': 'Raw text',
                'transcriptEdited': 'Edited text',
                'extractedSignalsJson': '{}',
                'entryType': 'text',
                'wordCount': 2,
                'createdAtUtc': now.toIso8601String(),
                'createdAtTimezone': 'UTC',
                'updatedAtUtc': now.toIso8601String(),
              },
            ],
            'weeklyBriefs': [],
            'problems': [],
            'portfolioVersions': [],
            'boardMembers': [],
            'governanceSessions': [],
            'bets': [],
            'evidenceItems': [],
            'reSetupTriggers': [],
            'userPreferences': null,
          },
        });

        final data = importService.parseImportFile(json);

        expect(data.dailyEntries.length, 1);
        expect(data.dailyEntries[0].id, 'test-entry-1');
        expect(data.dailyEntries[0].transcriptEdited, 'Edited text');
      });

      test('parses bets correctly', () {
        final now = DateTime.now().toUtc();
        final dueDate = now.add(const Duration(days: 90));
        final json = jsonEncode({
          'version': '1.0',
          'exportedAt': now.toIso8601String(),
          'data': {
            'dailyEntries': [],
            'weeklyBriefs': [],
            'problems': [],
            'portfolioVersions': [],
            'boardMembers': [],
            'governanceSessions': [],
            'bets': [
              {
                'id': 'test-bet-1',
                'prediction': 'Market will grow',
                'wrongIf': 'Market shrinks',
                'status': 'open',
                'createdAtUtc': now.toIso8601String(),
                'dueAtUtc': dueDate.toIso8601String(),
                'updatedAtUtc': now.toIso8601String(),
              },
            ],
            'evidenceItems': [],
            'reSetupTriggers': [],
            'userPreferences': null,
          },
        });

        final data = importService.parseImportFile(json);

        expect(data.bets.length, 1);
        expect(data.bets[0].prediction, 'Market will grow');
        expect(data.bets[0].wrongIf, 'Market shrinks');
      });
    });

    group('previewImport', () {
      test('returns summary for valid file', () {
        final json = jsonEncode({
          'version': '1.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'data': {
            'dailyEntries': [
              {
                'id': 'e1',
                'transcriptRaw': 'R1',
                'transcriptEdited': 'E1',
                'entryType': 'text',
                'createdAtUtc': DateTime.now().toIso8601String(),
                'createdAtTimezone': 'UTC',
                'updatedAtUtc': DateTime.now().toIso8601String(),
              },
              {
                'id': 'e2',
                'transcriptRaw': 'R2',
                'transcriptEdited': 'E2',
                'entryType': 'text',
                'createdAtUtc': DateTime.now().toIso8601String(),
                'createdAtTimezone': 'UTC',
                'updatedAtUtc': DateTime.now().toIso8601String(),
              },
            ],
            'weeklyBriefs': [],
            'problems': [],
            'portfolioVersions': [],
            'boardMembers': [],
            'governanceSessions': [],
            'bets': [],
            'evidenceItems': [],
            'reSetupTriggers': [],
            'userPreferences': null,
          },
        });

        final summary = importService.previewImport(json);

        expect(summary.dailyEntriesCount, 2);
        expect(summary.totalCount, 2);
      });

      test('returns empty summary for invalid file', () {
        const invalidJson = 'not valid';

        final summary = importService.previewImport(invalidJson);

        expect(summary.totalCount, 0);
      });
    });

    group('importData', () {
      test('imports daily entries successfully', () async {
        final now = DateTime.now().toUtc();
        final data = ExportData(
          version: '1.0',
          exportedAt: now,
          dailyEntries: [
            DailyEntry(
              id: 'imported-entry-1',
              transcriptRaw: 'Raw import',
              transcriptEdited: 'Edited import',
              extractedSignalsJson: '{}',
              entryType: 'text',
              wordCount: 2,
              createdAtUtc: now,
              createdAtTimezone: 'UTC',
              updatedAtUtc: now,
              syncStatus: 'pending',
              serverVersion: 0,
            ),
          ],
        );

        final result = await importService.importData(data, ConflictStrategy.skip);

        expect(result.success, isTrue);
        expect(result.importedCounts['dailyEntries'], 1);

        final entries = await dailyEntryRepo.getAll();
        expect(entries.length, 1);
        expect(entries[0].id, 'imported-entry-1');
      });

      test('imports bets successfully', () async {
        final now = DateTime.now().toUtc();
        final dueDate = now.add(const Duration(days: 90));
        final data = ExportData(
          version: '1.0',
          exportedAt: now,
          bets: [
            Bet(
              id: 'imported-bet-1',
              prediction: 'Imported prediction',
              wrongIf: 'Imported wrong if',
              status: 'open',
              createdAtUtc: now,
              dueAtUtc: dueDate,
              updatedAtUtc: now,
              syncStatus: 'pending',
              serverVersion: 0,
            ),
          ],
        );

        final result = await importService.importData(data, ConflictStrategy.skip);

        expect(result.success, isTrue);
        expect(result.importedCounts['bets'], 1);

        final bets = await betRepo.getAll();
        expect(bets.length, 1);
        expect(bets[0].prediction, 'Imported prediction');
      });

      test('skip strategy skips existing entries', () async {
        // Create existing entry
        final existingId = await dailyEntryRepo.create(
          transcriptRaw: 'Existing',
          transcriptEdited: 'Existing',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final existing = await dailyEntryRepo.getById(existingId);

        // Try to import with same ID
        final data = ExportData(
          version: '1.0',
          exportedAt: DateTime.now(),
          dailyEntries: [
            DailyEntry(
              id: existingId,
              transcriptRaw: 'Imported',
              transcriptEdited: 'Imported',
              extractedSignalsJson: '{}',
              entryType: 'text',
              wordCount: 1,
              createdAtUtc: DateTime.now(),
              createdAtTimezone: 'UTC',
              updatedAtUtc: DateTime.now(),
              syncStatus: 'pending',
              serverVersion: 0,
            ),
          ],
        );

        final result = await importService.importData(data, ConflictStrategy.skip);

        expect(result.success, isTrue);
        expect(result.skippedCounts['dailyEntries'], 1);
        expect(result.importedCounts['dailyEntries'], 0);

        // Verify original is unchanged
        final entry = await dailyEntryRepo.getById(existingId);
        expect(entry!.transcriptEdited, 'Existing');
      });

      test('overwrite strategy replaces existing entries', () async {
        // Create existing entry
        final existingId = await dailyEntryRepo.create(
          transcriptRaw: 'Existing',
          transcriptEdited: 'Existing',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        // Try to import with same ID
        final data = ExportData(
          version: '1.0',
          exportedAt: DateTime.now(),
          dailyEntries: [
            DailyEntry(
              id: existingId,
              transcriptRaw: 'Imported',
              transcriptEdited: 'Imported',
              extractedSignalsJson: '{}',
              entryType: 'text',
              wordCount: 1,
              createdAtUtc: DateTime.now(),
              createdAtTimezone: 'UTC',
              updatedAtUtc: DateTime.now(),
              syncStatus: 'pending',
              serverVersion: 0,
            ),
          ],
        );

        final result = await importService.importData(data, ConflictStrategy.overwrite);

        expect(result.success, isTrue);
        expect(result.importedCounts['dailyEntries'], 1);

        // Verify entry was updated
        final entry = await dailyEntryRepo.getById(existingId);
        expect(entry!.transcriptEdited, 'Imported');
      });

      test('merge strategy keeps newer entries', () async {
        final oldDate = DateTime.now().subtract(const Duration(days: 1)).toUtc();
        final newDate = DateTime.now().toUtc();

        // Create existing entry with newer date
        final existingId = await dailyEntryRepo.create(
          transcriptRaw: 'Existing',
          transcriptEdited: 'Existing newer',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        // Try to import with older updatedAt
        final data = ExportData(
          version: '1.0',
          exportedAt: DateTime.now(),
          dailyEntries: [
            DailyEntry(
              id: existingId,
              transcriptRaw: 'Imported',
              transcriptEdited: 'Imported older',
              extractedSignalsJson: '{}',
              entryType: 'text',
              wordCount: 2,
              createdAtUtc: oldDate,
              createdAtTimezone: 'UTC',
              updatedAtUtc: oldDate,
              syncStatus: 'pending',
              serverVersion: 0,
            ),
          ],
        );

        final result = await importService.importData(data, ConflictStrategy.merge);

        expect(result.success, isTrue);
        expect(result.skippedCounts['dailyEntries'], 1);

        // Verify existing (newer) is kept
        final entry = await dailyEntryRepo.getById(existingId);
        expect(entry!.transcriptEdited, 'Existing newer');
      });
    });

    group('round-trip export/import', () {
      test('exports and imports daily entries correctly', () async {
        // Create data
        final entryId = await dailyEntryRepo.create(
          transcriptRaw: 'Test entry for round trip',
          transcriptEdited: 'Test entry for round trip edited',
          entryType: EntryType.text,
          timezone: 'America/New_York',
        );

        // Export
        final jsonString = await exportService.exportToJson();

        // Clear database
        await database.delete(database.dailyEntries).go();
        expect(await dailyEntryRepo.getAll(), isEmpty);

        // Import
        final validationResult = importService.validateImportFile(jsonString);
        expect(validationResult.isValid, isTrue);

        final result = await importService.importData(
          validationResult.data!,
          ConflictStrategy.skip,
        );

        expect(result.success, isTrue);
        expect(result.importedCounts['dailyEntries'], 1);

        // Verify data
        final entries = await dailyEntryRepo.getAll();
        expect(entries.length, 1);
        expect(entries[0].id, entryId);
        expect(entries[0].transcriptEdited, 'Test entry for round trip edited');
      });

      test('exports and imports bets correctly', () async {
        // Create bet
        final betId = await betRepo.create(
          prediction: 'Round trip prediction',
          wrongIf: 'Round trip wrong if',
        );

        // Export
        final jsonString = await exportService.exportToJson();

        // Clear database
        await database.delete(database.bets).go();
        expect(await betRepo.getAll(), isEmpty);

        // Import
        final validationResult = importService.validateImportFile(jsonString);
        expect(validationResult.isValid, isTrue);

        final result = await importService.importData(
          validationResult.data!,
          ConflictStrategy.skip,
        );

        expect(result.success, isTrue);
        expect(result.importedCounts['bets'], 1);

        // Verify data
        final bets = await betRepo.getAll();
        expect(bets.length, 1);
        expect(bets[0].id, betId);
        expect(bets[0].prediction, 'Round trip prediction');
      });
    });
  });

  group('ConflictStrategy', () {
    test('displayName returns correct strings', () {
      expect(ConflictStrategy.overwrite.displayName, 'Overwrite existing');
      expect(ConflictStrategy.skip.displayName, 'Skip duplicates');
      expect(ConflictStrategy.merge.displayName, 'Keep newest');
    });

    test('description returns correct strings', () {
      expect(ConflictStrategy.overwrite.description, contains('Replace'));
      expect(ConflictStrategy.skip.description, contains('ignore'));
      expect(ConflictStrategy.merge.description, contains('most recent'));
    });
  });

  group('ImportValidationResult', () {
    test('success factory creates valid result', () {
      final data = ExportData.empty();
      final result = ImportValidationResult.success(data);

      expect(result.isValid, isTrue);
      expect(result.data, isNotNull);
      expect(result.errors, isEmpty);
    });

    test('success factory with warnings', () {
      final data = ExportData.empty();
      final result = ImportValidationResult.success(
        data,
        warnings: ['Version mismatch'],
      );

      expect(result.isValid, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('failure factory creates invalid result', () {
      final result = ImportValidationResult.failure(['Error 1', 'Error 2']);

      expect(result.isValid, isFalse);
      expect(result.errors.length, 2);
      expect(result.data, isNull);
    });
  });

  group('ImportResult', () {
    test('success factory creates successful result', () {
      final result = ImportResult.success(
        importedCounts: {'entries': 5, 'bets': 3},
        skippedCounts: {'entries': 1},
      );

      expect(result.success, isTrue);
      expect(result.totalImported, 8);
      expect(result.totalSkipped, 1);
      expect(result.errors, isEmpty);
    });

    test('failure factory creates failed result', () {
      final result = ImportResult.failure(['Import error']);

      expect(result.success, isFalse);
      expect(result.errors, isNotEmpty);
    });
  });
}
