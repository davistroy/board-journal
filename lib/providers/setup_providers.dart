import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../services/services.dart';
import 'ai_providers.dart';
import 'repository_providers.dart';

// ==================
// Setup AI Service Provider
// ==================

/// Provider for the Setup AI service.
///
/// Uses Claude Opus for governance features per PRD Section 3A.1.
final setupAIServiceProvider = Provider<SetupAIService?>((ref) {
  final client = ref.watch(claudeOpusClientProvider);

  if (client == null) {
    return null;
  }

  return SetupAIService(client);
});

// ==================
// Setup Service Provider
// ==================

/// Provider for the Setup service.
///
/// Returns null if AI services are not configured.
final setupServiceProvider = Provider<SetupService?>((ref) {
  final aiService = ref.watch(setupAIServiceProvider);

  if (aiService == null) {
    return null;
  }

  return SetupService(
    sessionRepository: ref.watch(governanceSessionRepositoryProvider),
    problemRepository: ref.watch(problemRepositoryProvider),
    boardMemberRepository: ref.watch(boardMemberRepositoryProvider),
    portfolioHealthRepository: ref.watch(portfolioHealthRepositoryProvider),
    portfolioVersionRepository: ref.watch(portfolioVersionRepositoryProvider),
    triggerRepository: ref.watch(reSetupTriggerRepositoryProvider),
    preferencesRepository: ref.watch(userPreferencesRepositoryProvider),
    aiService: aiService,
  );
});

// ==================
// Setup Session State
// ==================

/// State for an active Setup session.
class SetupSessionState {
  /// Session ID in the database.
  final String? sessionId;

  /// Current session data.
  final SetupSessionData data;

  /// Whether the session is loading.
  final bool isLoading;

  /// Whether an operation is in progress.
  final bool isProcessing;

  /// Error message if something went wrong.
  final String? error;

  /// Whether the AI service is configured.
  final bool isConfigured;

  const SetupSessionState({
    this.sessionId,
    this.data = const SetupSessionData(),
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.isConfigured = true,
  });

  SetupSessionState copyWith({
    String? sessionId,
    SetupSessionData? data,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool? isConfigured,
  }) =>
      SetupSessionState(
        sessionId: sessionId ?? this.sessionId,
        data: data ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        isProcessing: isProcessing ?? this.isProcessing,
        error: error,
        isConfigured: isConfigured ?? this.isConfigured,
      );

  /// Whether the session is active.
  bool get isActive =>
      sessionId != null &&
      data.currentState != SetupState.finalized &&
      data.currentState != SetupState.abandoned;

  /// Whether the session is completed.
  bool get isCompleted => data.currentState == SetupState.finalized;

  /// Progress percentage.
  int get progressPercent => data.currentState.progressPercent;

  /// Current state display name.
  String get currentStateName => data.currentState.displayName;
}

/// Notifier for managing Setup session state.
class SetupSessionNotifier extends AutoDisposeNotifier<SetupSessionState> {
  @override
  SetupSessionState build() {
    final service = ref.watch(setupServiceProvider);
    return SetupSessionState(
      isConfigured: service != null,
    );
  }

  SetupService? get _service => ref.read(setupServiceProvider);

  /// Starts a new Setup session.
  Future<void> startSession({bool? abstractionMode}) async {
    final service = _service;
    if (service == null) {
      state = state.copyWith(
        error: 'AI service not configured',
        isConfigured: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessionId = await service.startSession(
        abstractionMode: abstractionMode,
      );
      final sessionData = await service.loadSession(sessionId);

      state = state.copyWith(
        sessionId: sessionId,
        data: sessionData ??
            const SetupSessionData(currentState: SetupState.sensitivityGate),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start session: $e',
      );
    }
  }

  /// Resumes an existing in-progress session.
  Future<void> resumeSession(String sessionId) async {
    final service = _service;
    if (service == null) {
      state = state.copyWith(
        error: 'AI service not configured',
        isConfigured: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessionData = await service.loadSession(sessionId);
      if (sessionData == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Session not found',
        );
        return;
      }

      state = state.copyWith(
        sessionId: sessionId,
        data: sessionData,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load session: $e',
      );
    }
  }

  /// Sets the sensitivity gate options and advances.
  Future<void> setSensitivityGate({
    required bool abstractionMode,
    bool rememberChoice = false,
  }) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.setSensitivityGate(
        sessionId: sessionId,
        currentData: state.data,
        abstractionMode: abstractionMode,
        rememberChoice: rememberChoice,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to save settings: $e',
      );
    }
  }

  /// Saves a problem and advances.
  Future<void> saveProblem(SetupProblem problem) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      var updatedData = await service.saveProblem(
        sessionId: sessionId,
        currentData: state.data,
        problem: problem,
      );

      // Validate and advance if problem is complete
      if (problem.isComplete) {
        updatedData = await service.validateAndAdvance(
          sessionId: sessionId,
          currentData: updatedData,
        );
      }

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to save problem: $e',
      );
    }
  }

  /// Adds another optional problem.
  Future<void> addAnotherProblem() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.addAnotherProblem(
        sessionId: sessionId,
        currentData: state.data,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to add problem: $e',
      );
    }
  }

  /// Proceeds to time allocation (done adding problems).
  Future<void> proceedToTimeAllocation() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.proceedToTimeAllocation(
        sessionId: sessionId,
        currentData: state.data,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to proceed: $e',
      );
    }
  }

  /// Updates time allocations for all problems.
  Future<void> updateTimeAllocations(List<int> allocations) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.updateTimeAllocations(
        sessionId: sessionId,
        currentData: state.data,
        allocations: allocations,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to update allocations: $e',
      );
    }
  }

  /// Proceeds from time allocation to health calculation.
  Future<void> proceedFromTimeAllocation() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      var updatedData = await service.proceedFromTimeAllocation(
        sessionId: sessionId,
        currentData: state.data,
      );

      // Auto-advance through AI generation steps
      updatedData = await service.calculatePortfolioHealth(
        sessionId: sessionId,
        currentData: updatedData,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to calculate health: $e',
      );
    }
  }

  /// Creates board roles and personas.
  Future<void> createBoardAndPersonas() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      var updatedData = await service.createCoreRoles(
        sessionId: sessionId,
        currentData: state.data,
      );

      updatedData = await service.createGrowthRoles(
        sessionId: sessionId,
        currentData: updatedData,
      );

      updatedData = await service.createPersonas(
        sessionId: sessionId,
        currentData: updatedData,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to create board: $e',
      );
    }
  }

  /// Updates a board member's persona.
  Future<void> updatePersona({
    required int memberIndex,
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.updatePersona(
        sessionId: sessionId,
        currentData: state.data,
        memberIndex: memberIndex,
        name: name,
        background: background,
        communicationStyle: communicationStyle,
        signaturePhrase: signaturePhrase,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to update persona: $e',
      );
    }
  }

  /// Defines triggers and publishes portfolio.
  Future<void> defineTriggersAndPublish() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      var updatedData = await service.defineReSetupTriggers(
        sessionId: sessionId,
        currentData: state.data,
      );

      updatedData = await service.publishPortfolio(
        sessionId: sessionId,
        currentData: updatedData,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to publish: $e',
      );
    }
  }

  /// Abandons the current session.
  Future<void> abandonSession() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    try {
      await service.abandonSession(sessionId);
      state = const SetupSessionState();
    } catch (e) {
      // Ignore errors when abandoning
    }
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for Setup session state.
final setupSessionProvider =
    NotifierProvider.autoDispose<SetupSessionNotifier, SetupSessionState>(
  SetupSessionNotifier.new,
);

// ==================
// Setup Helpers
// ==================

/// Provider to check if there's an in-progress Setup session.
final hasInProgressSetupProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  final session = await repo.getInProgress();
  if (session != null && session.sessionType == GovernanceSessionType.setup.name) {
    return session.id;
  }
  return null;
});

/// Provider for the user's remembered abstraction mode preference for Setup.
final rememberedSetupAbstractionModeProvider = FutureProvider<bool?>((ref) async {
  final service = ref.watch(setupServiceProvider);
  if (service == null) return null;
  return service.getRememberedAbstractionMode();
});

/// Provider to check if Setup has been completed (portfolio exists).
final setupCompletedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(portfolioVersionRepositoryProvider);
  return repo.hasPortfolio();
});

/// Stream provider for whether setup is needed.
final needsSetupProvider = StreamProvider<bool>((ref) async* {
  final versionRepo = ref.watch(portfolioVersionRepositoryProvider);
  final hasPortfolio = await versionRepo.hasPortfolio();
  yield !hasPortfolio;
});
