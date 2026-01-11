import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/models/export_format.dart';

void main() {
  group('exportFormatVersion', () {
    test('has correct value', () {
      expect(exportFormatVersion, '1.0');
    });
  });

  group('ExportData', () {
    test('creates with required fields and defaults', () {
      final now = DateTime.now();
      final data = ExportData(
        version: '1.0',
        exportedAt: now,
      );

      expect(data.version, '1.0');
      expect(data.exportedAt, now);
      expect(data.dailyEntries, isEmpty);
      expect(data.weeklyBriefs, isEmpty);
      expect(data.problems, isEmpty);
      expect(data.portfolioVersions, isEmpty);
      expect(data.boardMembers, isEmpty);
      expect(data.governanceSessions, isEmpty);
      expect(data.bets, isEmpty);
      expect(data.evidenceItems, isEmpty);
      expect(data.reSetupTriggers, isEmpty);
      expect(data.userPreferences, isNull);
    });

    test('empty factory creates empty export data', () {
      final data = ExportData.empty();

      expect(data.version, exportFormatVersion);
      expect(data.dailyEntries, isEmpty);
      expect(data.totalItemCount, 0);
    });

    test('totalItemCount returns correct count', () {
      final data = ExportData(
        version: '1.0',
        exportedAt: DateTime.now(),
      );

      expect(data.totalItemCount, 0);
    });

    test('summary returns ExportSummary', () {
      final data = ExportData.empty();

      final summary = data.summary;

      expect(summary, isA<ExportSummary>());
      expect(summary.dailyEntriesCount, 0);
      expect(summary.hasUserPreferences, isFalse);
    });
  });

  group('ExportSummary', () {
    test('creates with default values', () {
      const summary = ExportSummary();

      expect(summary.dailyEntriesCount, 0);
      expect(summary.weeklyBriefsCount, 0);
      expect(summary.problemsCount, 0);
      expect(summary.portfolioVersionsCount, 0);
      expect(summary.boardMembersCount, 0);
      expect(summary.governanceSessionsCount, 0);
      expect(summary.betsCount, 0);
      expect(summary.evidenceItemsCount, 0);
      expect(summary.reSetupTriggersCount, 0);
      expect(summary.hasUserPreferences, isFalse);
    });

    test('totalCount returns sum of all counts', () {
      const summary = ExportSummary(
        dailyEntriesCount: 5,
        weeklyBriefsCount: 2,
        problemsCount: 3,
        hasUserPreferences: true,
      );

      expect(summary.totalCount, 11); // 5 + 2 + 3 + 1
    });

    test('totalCount without preferences', () {
      const summary = ExportSummary(
        dailyEntriesCount: 10,
        hasUserPreferences: false,
      );

      expect(summary.totalCount, 10);
    });
  });

  group('ImportValidationResult', () {
    test('creates with required fields', () {
      const result = ImportValidationResult(
        isValid: true,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.data, isNull);
    });

    test('success factory creates valid result', () {
      final data = ExportData.empty();
      final result = ImportValidationResult.success(data);

      expect(result.isValid, isTrue);
      expect(result.data, data);
      expect(result.errors, isEmpty);
    });

    test('success factory with warnings', () {
      final data = ExportData.empty();
      final result = ImportValidationResult.success(
        data,
        warnings: ['Old format version'],
      );

      expect(result.isValid, isTrue);
      expect(result.warnings, contains('Old format version'));
    });

    test('failure factory creates invalid result', () {
      final result = ImportValidationResult.failure(['Invalid format', 'Missing version']);

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(2));
      expect(result.errors, contains('Invalid format'));
      expect(result.data, isNull);
    });
  });

  group('ConflictStrategy', () {
    test('has all expected values', () {
      expect(ConflictStrategy.values, contains(ConflictStrategy.overwrite));
      expect(ConflictStrategy.values, contains(ConflictStrategy.skip));
      expect(ConflictStrategy.values, contains(ConflictStrategy.merge));
    });

    test('displayName returns correct strings', () {
      expect(ConflictStrategy.overwrite.displayName, 'Overwrite existing');
      expect(ConflictStrategy.skip.displayName, 'Skip duplicates');
      expect(ConflictStrategy.merge.displayName, 'Keep newest');
    });

    test('description returns correct strings', () {
      expect(ConflictStrategy.overwrite.description, contains('Replace'));
      expect(ConflictStrategy.skip.description, contains('Keep existing'));
      expect(ConflictStrategy.merge.description, contains('Compare timestamps'));
    });
  });

  group('ImportResult', () {
    test('creates with required fields', () {
      const result = ImportResult(success: true);

      expect(result.success, isTrue);
      expect(result.importedCounts, isEmpty);
      expect(result.skippedCounts, isEmpty);
      expect(result.errorCounts, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('success factory creates successful result', () {
      final result = ImportResult.success(
        importedCounts: {'dailyEntries': 5, 'weeklyBriefs': 2},
        skippedCounts: {'dailyEntries': 1},
      );

      expect(result.success, isTrue);
      expect(result.totalImported, 7);
      expect(result.totalSkipped, 1);
    });

    test('failure factory creates failed result', () {
      final result = ImportResult.failure(['Database error', 'Permission denied']);

      expect(result.success, isFalse);
      expect(result.errors, hasLength(2));
    });

    test('totalImported returns sum of imported counts', () {
      final result = ImportResult.success(
        importedCounts: {'a': 10, 'b': 20, 'c': 30},
      );

      expect(result.totalImported, 60);
    });

    test('totalSkipped returns sum of skipped counts', () {
      final result = ImportResult.success(
        skippedCounts: {'a': 5, 'b': 3},
      );

      expect(result.totalSkipped, 8);
    });

    test('totalErrors returns sum of error counts', () {
      const result = ImportResult(
        success: false,
        errorCounts: {'a': 2, 'b': 1},
      );

      expect(result.totalErrors, 3);
    });
  });

  group('HistoryItem', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final item = HistoryItem(
        id: 'item-1',
        type: HistoryItemType.dailyEntry,
        title: 'Test Entry',
        date: now,
      );

      expect(item.id, 'item-1');
      expect(item.type, HistoryItemType.dailyEntry);
      expect(item.title, 'Test Entry');
      expect(item.date, now);
      expect(item.preview, isNull);
      expect(item.data, isNull);
    });

    test('creates with optional fields', () {
      final item = HistoryItem(
        id: 'item-2',
        type: HistoryItemType.weeklyBrief,
        title: 'Weekly Brief',
        preview: 'This is a preview...',
        date: DateTime.now(),
        data: {'key': 'value'},
      );

      expect(item.preview, 'This is a preview...');
      expect(item.data, {'key': 'value'});
    });
  });

  group('HistoryItemType', () {
    test('has all expected values', () {
      expect(HistoryItemType.values, contains(HistoryItemType.dailyEntry));
      expect(HistoryItemType.values, contains(HistoryItemType.weeklyBrief));
      expect(HistoryItemType.values, contains(HistoryItemType.governanceSession));
    });

    test('iconName returns correct values', () {
      expect(HistoryItemType.dailyEntry.iconName, 'calendar_today');
      expect(HistoryItemType.weeklyBrief.iconName, 'description');
      expect(HistoryItemType.governanceSession.iconName, 'gavel');
    });

    test('label returns correct values', () {
      expect(HistoryItemType.dailyEntry.label, 'Entry');
      expect(HistoryItemType.weeklyBrief.label, 'Brief');
      expect(HistoryItemType.governanceSession.label, 'Report');
    });
  });
}
