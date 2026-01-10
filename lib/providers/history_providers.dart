import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../models/export_format.dart';
import '../services/export/export_service.dart';
import '../services/export/import_service.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

// ==================
// History Providers
// ==================

/// Items per page for pagination.
const int historyPageSize = 20;

/// Provider for combined history items with pagination support.
///
/// Combines daily entries, weekly briefs, and governance sessions
/// into a single reverse-chronological list.
final historyItemsProvider = FutureProvider.family<List<HistoryItem>, int>((ref, page) async {
  final entriesRepo = ref.watch(dailyEntryRepositoryProvider);
  final briefsRepo = ref.watch(weeklyBriefRepositoryProvider);
  final sessionsRepo = ref.watch(governanceSessionRepositoryProvider);

  // Calculate offset
  final offset = page * historyPageSize;

  // Fetch data from all sources with pagination
  // We fetch a bit more than needed to ensure we have enough after combining
  final entries = await entriesRepo.getAll(limit: historyPageSize * 2, offset: offset);
  final briefs = await briefsRepo.getAll(limit: historyPageSize, offset: offset ~/ 2);
  final sessions = await sessionsRepo.getCompleted();

  // Convert to HistoryItems
  final items = <HistoryItem>[];

  for (final entry in entries) {
    items.add(HistoryItem.fromDailyEntry(entry));
  }

  for (final brief in briefs) {
    items.add(HistoryItem.fromWeeklyBrief(brief));
  }

  for (final session in sessions) {
    items.add(HistoryItem.fromGovernanceSession(session));
  }

  // Sort by date descending
  items.sort((a, b) => b.date.compareTo(a.date));

  // Apply pagination
  if (offset >= items.length) {
    return [];
  }

  final endIndex = (offset + historyPageSize).clamp(0, items.length);
  return items.sublist(offset, endIndex);
});

/// Provider for all history items (for initial load).
final allHistoryItemsStreamProvider = StreamProvider<List<HistoryItem>>((ref) async* {
  final entriesRepo = ref.watch(dailyEntryRepositoryProvider);
  final briefsRepo = ref.watch(weeklyBriefRepositoryProvider);
  final sessionsRepo = ref.watch(governanceSessionRepositoryProvider);

  await for (final entries in entriesRepo.watchAll()) {
    final briefs = await briefsRepo.getAll();
    final sessions = await sessionsRepo.getCompleted();

    final items = <HistoryItem>[];

    for (final entry in entries) {
      items.add(HistoryItem.fromDailyEntry(entry));
    }

    for (final brief in briefs) {
      items.add(HistoryItem.fromWeeklyBrief(brief));
    }

    for (final session in sessions) {
      items.add(HistoryItem.fromGovernanceSession(session));
    }

    // Sort by date descending
    items.sort((a, b) => b.date.compareTo(a.date));

    yield items;
  }
});

/// Notifier for paginated history loading.
class HistoryNotifier extends StateNotifier<AsyncValue<List<HistoryItem>>> {
  final DailyEntryRepository _entriesRepo;
  final WeeklyBriefRepository _briefsRepo;
  final GovernanceSessionRepository _sessionsRepo;

  int _currentPage = 0;
  bool _hasMore = true;
  List<HistoryItem> _allItems = [];

  HistoryNotifier(this._entriesRepo, this._briefsRepo, this._sessionsRepo)
      : super(const AsyncValue.loading()) {
    _loadInitial();
  }

  bool get hasMore => _hasMore;

  Future<void> _loadInitial() async {
    try {
      final entries = await _entriesRepo.getAll();
      final briefs = await _briefsRepo.getAll();
      final sessions = await _sessionsRepo.getCompleted();

      _allItems = [];

      for (final entry in entries) {
        _allItems.add(HistoryItem.fromDailyEntry(entry));
      }

      for (final brief in briefs) {
        _allItems.add(HistoryItem.fromWeeklyBrief(brief));
      }

      for (final session in sessions) {
        _allItems.add(HistoryItem.fromGovernanceSession(session));
      }

      // Sort by date descending
      _allItems.sort((a, b) => b.date.compareTo(a.date));

      // Get first page
      final pageItems = _allItems.take(historyPageSize).toList();
      _hasMore = _allItems.length > historyPageSize;
      _currentPage = 0;

      state = AsyncValue.data(pageItems);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;

    final currentData = state.valueOrNull ?? [];
    _currentPage++;

    final startIndex = _currentPage * historyPageSize;
    final endIndex = (startIndex + historyPageSize).clamp(0, _allItems.length);

    if (startIndex >= _allItems.length) {
      _hasMore = false;
      return;
    }

    final newItems = _allItems.sublist(startIndex, endIndex);
    _hasMore = endIndex < _allItems.length;

    state = AsyncValue.data([...currentData, ...newItems]);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    _currentPage = 0;
    _hasMore = true;
    await _loadInitial();
  }
}

/// Provider for history notifier with pagination support.
final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<List<HistoryItem>>>((ref) {
  return HistoryNotifier(
    ref.watch(dailyEntryRepositoryProvider),
    ref.watch(weeklyBriefRepositoryProvider),
    ref.watch(governanceSessionRepositoryProvider),
  );
});

// ==================
// Export/Import Service Providers
// ==================

/// Provider for ExportService.
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(
    dailyEntryRepository: ref.watch(dailyEntryRepositoryProvider),
    weeklyBriefRepository: ref.watch(weeklyBriefRepositoryProvider),
    problemRepository: ref.watch(problemRepositoryProvider),
    portfolioVersionRepository: ref.watch(portfolioVersionRepositoryProvider),
    boardMemberRepository: ref.watch(boardMemberRepositoryProvider),
    governanceSessionRepository: ref.watch(governanceSessionRepositoryProvider),
    betRepository: ref.watch(betRepositoryProvider),
    evidenceItemRepository: ref.watch(evidenceItemRepositoryProvider),
    reSetupTriggerRepository: ref.watch(reSetupTriggerRepositoryProvider),
    userPreferencesRepository: ref.watch(userPreferencesRepositoryProvider),
  );
});

/// Provider for ImportService.
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    database: ref.watch(databaseProvider),
    dailyEntryRepository: ref.watch(dailyEntryRepositoryProvider),
    weeklyBriefRepository: ref.watch(weeklyBriefRepositoryProvider),
    problemRepository: ref.watch(problemRepositoryProvider),
    portfolioVersionRepository: ref.watch(portfolioVersionRepositoryProvider),
    boardMemberRepository: ref.watch(boardMemberRepositoryProvider),
    governanceSessionRepository: ref.watch(governanceSessionRepositoryProvider),
    betRepository: ref.watch(betRepositoryProvider),
    evidenceItemRepository: ref.watch(evidenceItemRepositoryProvider),
    reSetupTriggerRepository: ref.watch(reSetupTriggerRepositoryProvider),
    userPreferencesRepository: ref.watch(userPreferencesRepositoryProvider),
  );
});

/// Provider for export preview.
final exportPreviewProvider = FutureProvider<ExportSummary>((ref) async {
  final exportService = ref.watch(exportServiceProvider);
  return exportService.getExportPreview();
});
