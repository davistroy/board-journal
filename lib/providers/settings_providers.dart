import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../services/settings/privacy_service.dart';
import 'database_provider.dart';
import 'repository_providers.dart';

// ==================
// Service Providers
// ==================

/// Provider for PrivacyService.
final privacyServiceProvider = Provider<PrivacyService>((ref) {
  final prefsRepo = ref.watch(userPreferencesRepositoryProvider);
  return PrivacyService(prefsRepo);
});

// ==================
// Settings State Providers
// ==================

/// Provider for abstraction mode enabled state.
final abstractionModeProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(privacyServiceProvider);
  return service.getAbstractionMode();
});

/// Provider for analytics enabled state.
final analyticsEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(privacyServiceProvider);
  return service.getAnalyticsEnabled();
});

// ==================
// Settings Notifiers
// ==================

/// State notifier for abstraction mode toggle.
class AbstractionModeNotifier extends StateNotifier<AsyncValue<bool>> {
  final PrivacyService _service;
  final Ref _ref;

  AbstractionModeNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _service.getAbstractionMode();
      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    await setEnabled(!current);
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _service.setAbstractionMode(enabled);
      state = AsyncValue.data(enabled);
      // Invalidate user preferences to refresh UI
      _ref.invalidate(userPreferencesStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for abstraction mode state notifier.
final abstractionModeNotifierProvider =
    StateNotifierProvider<AbstractionModeNotifier, AsyncValue<bool>>((ref) {
  final service = ref.watch(privacyServiceProvider);
  return AbstractionModeNotifier(service, ref);
});

/// State notifier for analytics toggle.
class AnalyticsNotifier extends StateNotifier<AsyncValue<bool>> {
  final PrivacyService _service;
  final Ref _ref;

  AnalyticsNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await _service.getAnalyticsEnabled();
      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    await setEnabled(!current);
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _service.setAnalyticsEnabled(enabled);
      state = AsyncValue.data(enabled);
      // Invalidate user preferences to refresh UI
      _ref.invalidate(userPreferencesStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for analytics state notifier.
final analyticsNotifierProvider =
    StateNotifierProvider<AnalyticsNotifier, AsyncValue<bool>>((ref) {
  final service = ref.watch(privacyServiceProvider);
  return AnalyticsNotifier(service, ref);
});

// ==================
// Board Personas Providers
// ==================

/// Provider for all board members (for settings).
final settingsBoardMembersProvider = FutureProvider<List<BoardMember>>((ref) async {
  final repo = ref.watch(boardMemberRepositoryProvider);
  return repo.getAll();
});

/// Provider for a single board member by ID.
final boardMemberByIdProvider = FutureProvider.family<BoardMember?, String>((ref, id) async {
  final repo = ref.watch(boardMemberRepositoryProvider);
  return repo.getById(id);
});

/// State notifier for managing board persona updates.
class BoardPersonaNotifier extends StateNotifier<AsyncValue<void>> {
  final BoardMemberRepository _repo;
  final Ref _ref;

  BoardPersonaNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  /// Updates a persona's fields.
  Future<void> updatePersona(
    String id, {
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updatePersona(
        id,
        name: name,
        background: background,
        communicationStyle: communicationStyle,
        signaturePhrase: signaturePhrase,
      );
      state = const AsyncValue.data(null);
      // Invalidate to refresh board members list
      _ref.invalidate(settingsBoardMembersProvider);
      _ref.invalidate(boardMembersStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Resets a single persona to original values.
  Future<void> resetPersona(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.resetPersona(id);
      state = const AsyncValue.data(null);
      // Invalidate to refresh board members list
      _ref.invalidate(settingsBoardMembersProvider);
      _ref.invalidate(boardMembersStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Resets all personas to original values.
  Future<void> resetAllPersonas() async {
    state = const AsyncValue.loading();
    try {
      await _repo.resetAllPersonas();
      state = const AsyncValue.data(null);
      // Invalidate to refresh board members list
      _ref.invalidate(settingsBoardMembersProvider);
      _ref.invalidate(boardMembersStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for board persona notifier.
final boardPersonaNotifierProvider =
    StateNotifierProvider<BoardPersonaNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(boardMemberRepositoryProvider);
  return BoardPersonaNotifier(repo, ref);
});

// ==================
// Portfolio Providers
// ==================

/// Provider for all problems (for settings).
final settingsProblemsProvider = FutureProvider<List<Problem>>((ref) async {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.getAll();
});

/// Provider for a single problem by ID.
final problemByIdProvider = FutureProvider.family<Problem?, String>((ref, id) async {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.getById(id);
});

/// Provider for total time allocation.
final totalAllocationProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.getTotalAllocation();
});

/// Provider for allocation validation message.
final allocationValidationProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(problemRepositoryProvider);
  return repo.validateAllocation();
});

/// State notifier for managing problem updates.
class ProblemEditorNotifier extends StateNotifier<AsyncValue<void>> {
  final ProblemRepository _problemRepo;
  final BoardMemberRepository _boardRepo;
  final Ref _ref;

  ProblemEditorNotifier(this._problemRepo, this._boardRepo, this._ref)
      : super(const AsyncValue.data(null));

  /// Updates problem fields.
  Future<void> updateProblem(
    String id, {
    String? name,
    String? whatBreaks,
    String? directionRationale,
    int? timeAllocationPercent,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _problemRepo.update(
        id,
        name: name,
        whatBreaks: whatBreaks,
        directionRationale: directionRationale,
        timeAllocationPercent: timeAllocationPercent,
      );
      state = const AsyncValue.data(null);
      _invalidateProblems();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates time allocation for a problem.
  Future<void> updateAllocation(String id, int percent) async {
    state = const AsyncValue.loading();
    try {
      await _problemRepo.update(id, timeAllocationPercent: percent);
      state = const AsyncValue.data(null);
      _invalidateProblems();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deletes a problem if allowed (min 3 enforced).
  ///
  /// Returns true if deletion succeeded, false if blocked due to minimum.
  Future<bool> deleteProblem(String id) async {
    state = const AsyncValue.loading();
    try {
      // Check if any board members are anchored to this problem
      final anchoredMembers = await _boardRepo.getByAnchoredProblem(id);

      // Attempt to delete
      final success = await _problemRepo.softDelete(id);

      if (success && anchoredMembers.isNotEmpty) {
        // Clear anchoring for affected members (they'll need re-anchoring)
        for (final member in anchoredMembers) {
          await _boardRepo.updateAnchoring(
            member.id,
            problemId: '',
            demand: '',
          );
        }
      }

      state = const AsyncValue.data(null);
      _invalidateProblems();
      _ref.invalidate(boardMembersStreamProvider);
      _ref.invalidate(settingsBoardMembersProvider);

      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Gets board members anchored to a problem.
  Future<List<BoardMember>> getAnchoredMembers(String problemId) async {
    return _boardRepo.getByAnchoredProblem(problemId);
  }

  void _invalidateProblems() {
    _ref.invalidate(settingsProblemsProvider);
    _ref.invalidate(problemsStreamProvider);
    _ref.invalidate(totalAllocationProvider);
    _ref.invalidate(allocationValidationProvider);
  }
}

/// Provider for problem editor notifier.
final problemEditorNotifierProvider =
    StateNotifierProvider<ProblemEditorNotifier, AsyncValue<void>>((ref) {
  final problemRepo = ref.watch(problemRepositoryProvider);
  final boardRepo = ref.watch(boardMemberRepositoryProvider);
  return ProblemEditorNotifier(problemRepo, boardRepo, ref);
});

// ==================
// Version History Providers
// ==================

/// Provider for all portfolio versions.
final allVersionsProvider = FutureProvider<List<PortfolioVersion>>((ref) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.getAll();
});

/// Provider for a specific version by ID.
final versionByIdProvider = FutureProvider.family<PortfolioVersion?, String>((ref, id) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.getById(id);
});

/// Provider for a specific version by number.
final versionByNumberProvider = FutureProvider.family<PortfolioVersion?, int>((ref, number) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.getByNumber(number);
});

/// Provider for comparing two versions.
final versionComparisonProvider =
    FutureProvider.family<List<PortfolioVersion>, ({int v1, int v2})>((ref, params) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.getForComparison(params.v1, params.v2);
});

// ==================
// Re-setup Triggers Providers
// ==================

/// Provider for all re-setup triggers.
final allTriggersProvider = FutureProvider<List<ReSetupTrigger>>((ref) async {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.getAll();
});

/// Provider for met triggers.
final metTriggersProvider = FutureProvider<List<ReSetupTrigger>>((ref) async {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.getMet();
});

/// Provider for unmet triggers.
final unmetTriggersProvider = FutureProvider<List<ReSetupTrigger>>((ref) async {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.getUnmet();
});

/// Provider for approaching triggers.
final approachingTriggersProvider = FutureProvider<List<ReSetupTrigger>>((ref) async {
  final repo = ref.watch(reSetupTriggerRepositoryProvider);
  return repo.getApproaching();
});

// ==================
// Data Management Providers
// ==================

/// State notifier for data management operations.
class DataManagementNotifier extends StateNotifier<AsyncValue<void>> {
  final AppDatabase _db;
  final Ref _ref;

  DataManagementNotifier(this._db, this._ref) : super(const AsyncValue.data(null));

  /// Deletes all data from the database.
  Future<void> deleteAllData() async {
    state = const AsyncValue.loading();
    try {
      // Delete all data from all tables
      await _db.delete(_db.dailyEntries).go();
      await _db.delete(_db.weeklyBriefs).go();
      await _db.delete(_db.problems).go();
      await _db.delete(_db.boardMembers).go();
      await _db.delete(_db.governanceSessions).go();
      await _db.delete(_db.bets).go();
      await _db.delete(_db.evidenceItems).go();
      await _db.delete(_db.portfolioVersions).go();
      await _db.delete(_db.portfolioHealths).go();
      await _db.delete(_db.reSetupTriggers).go();
      // Don't delete user preferences - just reset them
      await _db.delete(_db.userPreferences).go();

      state = const AsyncValue.data(null);

      // Invalidate all providers
      _ref.invalidate(dailyEntriesStreamProvider);
      _ref.invalidate(weeklyBriefsStreamProvider);
      _ref.invalidate(problemsStreamProvider);
      _ref.invalidate(boardMembersStreamProvider);
      _ref.invalidate(governanceSessionsStreamProvider);
      _ref.invalidate(betsStreamProvider);
      _ref.invalidate(portfolioVersionsStreamProvider);
      _ref.invalidate(portfolioHealthStreamProvider);
      _ref.invalidate(reSetupTriggersStreamProvider);
      _ref.invalidate(userPreferencesStreamProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for data management notifier.
final dataManagementNotifierProvider =
    StateNotifierProvider<DataManagementNotifier, AsyncValue<void>>((ref) {
  final db = ref.watch(databaseProvider);
  return DataManagementNotifier(db, ref);
});
