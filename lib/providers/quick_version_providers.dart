import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../services/services.dart';
import 'ai_providers.dart';
import 'repository_providers.dart';

// ==================
// Quick Version Service Provider
// ==================

/// Provider for the Quick Version service.
///
/// Returns null if AI services are not configured.
final quickVersionServiceProvider = Provider<QuickVersionService?>((ref) {
  final vaguenessService = ref.watch(vaguenessDetectionServiceProvider);
  final aiService = ref.watch(quickVersionAIServiceProvider);

  if (vaguenessService == null || aiService == null) {
    return null;
  }

  return QuickVersionService(
    sessionRepository: ref.watch(governanceSessionRepositoryProvider),
    betRepository: ref.watch(betRepositoryProvider),
    preferencesRepository: ref.watch(userPreferencesRepositoryProvider),
    vaguenessService: vaguenessService,
    aiService: aiService,
  );
});

// ==================
// Quick Version Session State
// ==================

/// State for an active Quick Version session.
class QuickVersionSessionState {
  /// Session ID in the database.
  final String? sessionId;

  /// Current session data.
  final QuickVersionSessionData data;

  /// Whether the session is loading.
  final bool isLoading;

  /// Whether an operation is in progress.
  final bool isProcessing;

  /// Error message if something went wrong.
  final String? error;

  /// Whether the AI service is configured.
  final bool isConfigured;

  const QuickVersionSessionState({
    this.sessionId,
    this.data = const QuickVersionSessionData(),
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.isConfigured = true,
  });

  QuickVersionSessionState copyWith({
    String? sessionId,
    QuickVersionSessionData? data,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool? isConfigured,
  }) =>
      QuickVersionSessionState(
        sessionId: sessionId ?? this.sessionId,
        data: data ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        isProcessing: isProcessing ?? this.isProcessing,
        error: error,
        isConfigured: isConfigured ?? this.isConfigured,
      );

  /// Whether the session is active.
  bool get isActive => sessionId != null && !data.currentState.name.contains('finalized');

  /// Whether the session is completed.
  bool get isCompleted => data.currentState == QuickVersionState.finalized;

  /// Current question number (1-5) or 0 if not in a question state.
  int get questionNumber => data.currentState.questionNumber;

  /// Progress percentage.
  int get progressPercent => data.currentState.progressPercent;
}

/// Notifier for managing Quick Version session state.
class QuickVersionSessionNotifier
    extends AutoDisposeNotifier<QuickVersionSessionState> {
  @override
  QuickVersionSessionState build() {
    final service = ref.watch(quickVersionServiceProvider);
    return QuickVersionSessionState(
      isConfigured: service != null,
    );
  }

  QuickVersionService? get _service => ref.read(quickVersionServiceProvider);

  /// Starts a new Quick Version session.
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
        data: sessionData ?? const QuickVersionSessionData(
          currentState: QuickVersionState.sensitivityGate,
        ),
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

  /// Submits an answer and advances the state machine.
  Future<void> submitAnswer(String answer) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.processAnswer(
        sessionId: sessionId,
        currentData: state.data,
        answer: answer,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Auto-generate output if we've reached that state
      if (updatedData.currentState == QuickVersionState.generateOutput) {
        await generateOutput();
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process answer: $e',
      );
    }
  }

  /// Skips the current vagueness gate (with confirmation).
  Future<bool> skipVaguenessGate() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return false;

    if (!state.data.canSkip) {
      state = state.copyWith(
        error: 'Maximum skips reached. You must provide a concrete example.',
      );
      return false;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.skipVaguenessGate(
        sessionId: sessionId,
        currentData: state.data,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Auto-generate output if we've reached that state
      if (updatedData.currentState == QuickVersionState.generateOutput) {
        await generateOutput();
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Generates the final output.
  Future<void> generateOutput() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.generateOutput(
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
        error: 'Failed to generate output: $e',
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
      state = const QuickVersionSessionState();
    } catch (e) {
      // Ignore errors when abandoning
    }
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Gets the current question text.
  String get currentQuestion {
    final service = _service;
    if (service == null) return '';
    return service.getQuestionText(state.data);
  }
}

/// Provider for Quick Version session state.
final quickVersionSessionProvider = NotifierProvider.autoDispose<
    QuickVersionSessionNotifier, QuickVersionSessionState>(
  QuickVersionSessionNotifier.new,
);

// ==================
// Quick Version Helpers
// ==================

/// Provider to check if there's an in-progress Quick Version session.
final hasInProgressQuickVersionProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  final session = await repo.getInProgress();
  if (session != null && session.sessionType == GovernanceSessionType.quick.name) {
    return session.id;
  }
  return null;
});

/// Provider for Quick Version session count this week.
final quickVersionWeeklyCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  return repo.getSessionCountForPeriod(
    GovernanceSessionType.quick,
    DateRange(start: weekStart.toUtc(), end: weekEnd.toUtc()),
  );
});

/// Provider for the user's remembered abstraction mode preference.
final rememberedAbstractionModeProvider = FutureProvider<bool?>((ref) async {
  final service = ref.watch(quickVersionServiceProvider);
  if (service == null) return null;
  return service.getRememberedAbstractionMode();
});
