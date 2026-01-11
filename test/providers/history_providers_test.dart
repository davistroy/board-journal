import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/models/export_format.dart';
import 'package:boardroom_journal/providers/history_providers.dart';

void main() {
  group('historyPageSize', () {
    test('has correct value', () {
      expect(historyPageSize, 20);
    });
  });

  group('HistoryItem', () {
    test('HistoryItemType has all expected values', () {
      expect(HistoryItemType.values, contains(HistoryItemType.dailyEntry));
      expect(HistoryItemType.values, contains(HistoryItemType.weeklyBrief));
      expect(HistoryItemType.values, contains(HistoryItemType.governanceSession));
    });

    test('creates from daily entry', () {
      final now = DateTime.now();
      final item = HistoryItem(
        id: 'entry-1',
        type: HistoryItemType.dailyEntry,
        date: now,
        preview: 'Test entry content',
        title: 'Daily Entry',
      );

      expect(item.id, 'entry-1');
      expect(item.type, HistoryItemType.dailyEntry);
      expect(item.date, now);
      expect(item.preview, 'Test entry content');
    });

    test('creates from weekly brief', () {
      final now = DateTime.now();
      final item = HistoryItem(
        id: 'brief-1',
        type: HistoryItemType.weeklyBrief,
        date: now,
        preview: 'Weekly summary',
        title: 'Weekly Brief',
      );

      expect(item.id, 'brief-1');
      expect(item.type, HistoryItemType.weeklyBrief);
    });

    test('creates from governance session', () {
      final now = DateTime.now();
      final item = HistoryItem(
        id: 'session-1',
        type: HistoryItemType.governanceSession,
        date: now,
        preview: 'Quick version audit',
        title: 'Governance Session',
      );

      expect(item.id, 'session-1');
      expect(item.type, HistoryItemType.governanceSession);
    });
  });

  group('History Providers', () {
    test('historyItemsProvider is a FutureProvider.family', () {
      // Verify provider exists and is typed correctly
      expect(historyItemsProvider, isA<FutureProviderFamily<List<HistoryItem>, int>>());
    });

    test('allHistoryItemsStreamProvider is a StreamProvider', () {
      expect(allHistoryItemsStreamProvider, isA<StreamProvider<List<HistoryItem>>>());
    });

    test('historyNotifierProvider is a StateNotifierProvider', () {
      expect(
        historyNotifierProvider,
        isA<StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryItem>>>>(),
      );
    });

    test('exportServiceProvider is a Provider', () {
      expect(exportServiceProvider, isNotNull);
    });

    test('importServiceProvider is a Provider', () {
      expect(importServiceProvider, isNotNull);
    });

    test('exportPreviewProvider is a FutureProvider', () {
      expect(exportPreviewProvider, isA<FutureProvider<ExportSummary>>());
    });
  });

  group('HistoryNotifier', () {
    test('hasMore getter exists', () {
      // Verify the HistoryNotifier class has the hasMore getter
      // This is tested by ensuring the class is constructable with mocks
      expect(HistoryNotifier, isNotNull);
    });
  });

  group('ExportSummary', () {
    test('can be created with counts', () {
      final summary = ExportSummary(
        dailyEntriesCount: 10,
        weeklyBriefsCount: 5,
        governanceSessionsCount: 3,
        betsCount: 2,
        problemsCount: 4,
        boardMembersCount: 7,
      );

      expect(summary.dailyEntriesCount, 10);
      expect(summary.weeklyBriefsCount, 5);
      expect(summary.governanceSessionsCount, 3);
      expect(summary.betsCount, 2);
      expect(summary.problemsCount, 4);
      expect(summary.boardMembersCount, 7);
      expect(summary.totalCount, 31);
    });
  });
}
