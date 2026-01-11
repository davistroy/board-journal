import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';
import '../services/services.dart';
import 'ai_providers.dart';
import 'repository_providers.dart';

// ==================
// Quarterly AI Service Provider
// ==================

/// Provider for the Quarterly AI service.
///
/// Uses Claude Opus for governance features per PRD Section 3A.1.
final quarterlyAIServiceProvider = Provider<QuarterlyAIService?>((ref) {
  final client = ref.watch(claudeOpusClientProvider);

  if (client == null) {
    return null;
  }

  return QuarterlyAIService(client);
});

// ==================
// Quarterly Service Provider
// ==================

/// Provider for the Quarterly service.
///
/// Returns null if AI services are not configured.
final quarterlyServiceProvider = Provider<QuarterlyService?>((ref) {
  final vaguenessService = ref.watch(vaguenessDetectionServiceProvider);
  final aiService = ref.watch(quarterlyAIServiceProvider);

  if (vaguenessService == null || aiService == null) {
    return null;
  }

  return QuarterlyService(
    sessionRepository: ref.watch(governanceSessionRepositoryProvider),
    betRepository: ref.watch(betRepositoryProvider),
    problemRepository: ref.watch(problemRepositoryProvider),
    boardMemberRepository: ref.watch(boardMemberRepositoryProvider),
    portfolioVersionRepository: ref.watch(portfolioVersionRepositoryProvider),
    portfolioHealthRepository: ref.watch(portfolioHealthRepositoryProvider),
    triggerRepository: ref.watch(reSetupTriggerRepositoryProvider),
    evidenceRepository: ref.watch(evidenceItemRepositoryProvider),
    preferencesRepository: ref.watch(userPreferencesRepositoryProvider),
    vaguenessService: vaguenessService,
    aiService: aiService,
  );
});

// ==================
// Quarterly Session State
// ==================

/// State for an active Quarterly Report session.
class QuarterlySessionState {
  /// Session ID in the database.
  final String? sessionId;

  /// Current session data.
  final QuarterlySessionData data;

  /// Whether the session is loading.
  final bool isLoading;

  /// Whether an operation is in progress.
  final bool isProcessing;

  /// Error message if something went wrong.
  final String? error;

  /// Whether the AI service is configured.
  final bool isConfigured;

  /// Current board member for interrogation.
  final BoardMember? currentBoardMember;

  /// Current board question.
  final String? currentBoardQuestion;

  const QuarterlySessionState({
    this.sessionId,
    this.data = const QuarterlySessionData(),
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.isConfigured = true,
    this.currentBoardMember,
    this.currentBoardQuestion,
  });

  QuarterlySessionState copyWith({
    String? sessionId,
    QuarterlySessionData? data,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    bool? isConfigured,
    BoardMember? currentBoardMember,
    String? currentBoardQuestion,
  }) =>
      QuarterlySessionState(
        sessionId: sessionId ?? this.sessionId,
        data: data ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        isProcessing: isProcessing ?? this.isProcessing,
        error: error,
        isConfigured: isConfigured ?? this.isConfigured,
        currentBoardMember: currentBoardMember ?? this.currentBoardMember,
        currentBoardQuestion: currentBoardQuestion ?? this.currentBoardQuestion,
      );

  /// Whether the session is active.
  bool get isActive =>
      sessionId != null &&
      data.currentState != QuarterlyState.finalized &&
      data.currentState != QuarterlyState.abandoned;

  /// Whether the session is completed.
  bool get isCompleted => data.currentState == QuarterlyState.finalized;

  /// Progress percentage.
  int get progressPercent => data.currentState.progressPercent;

  /// Current state display name.
  String get currentStateName => data.currentState.displayName;

  /// Whether currently in board interrogation phase.
  bool get isInBoardInterrogation =>
      data.currentState == QuarterlyState.coreBoardInterrogation ||
      data.currentState == QuarterlyState.growthBoardInterrogation ||
      data.currentState == QuarterlyState.boardInterrogationClarify;
}

/// Notifier for managing Quarterly session state.
class QuarterlySessionNotifier
    extends AutoDisposeNotifier<QuarterlySessionState> {
  @override
  QuarterlySessionState build() {
    final service = ref.watch(quarterlyServiceProvider);
    return QuarterlySessionState(
      isConfigured: service != null,
    );
  }

  QuarterlyService? get _service => ref.read(quarterlyServiceProvider);

  /// Starts a new Quarterly Report session.
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
            const QuarterlySessionData(
                currentState: QuarterlyState.sensitivityGate),
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

  /// Processes the prerequisites gate.
  Future<void> processPrerequisitesGate() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.processPrerequisitesGate(
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
        error: e.toString(),
      );
    }
  }

  /// Processes the recent report warning and continues.
  Future<void> processRecentReportWarning() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.processRecentReportWarning(
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
        error: 'Failed to process warning: $e',
      );
    }
  }

  /// Evaluates the last bet.
  Future<void> evaluateBet({
    required String betId,
    required BetStatus status,
    String? rationale,
    List<QuarterlyEvidence>? evidence,
  }) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.evaluateBet(
        sessionId: sessionId,
        currentData: state.data,
        betId: betId,
        status: status,
        rationale: rationale,
        evidence: evidence,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to evaluate bet: $e',
      );
    }
  }

  /// Skips bet evaluation (no open bet).
  Future<void> skipBetEvaluation() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.skipBetEvaluation(
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
        error: 'Failed to skip bet evaluation: $e',
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

      // Auto-advance for certain states
      if (updatedData.currentState == QuarterlyState.q6PortfolioHealthUpdate) {
        await calculateHealthTrend();
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process answer: $e',
      );
    }
  }

  /// Skips the current vagueness gate.
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

      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Calculates the portfolio health trend.
  Future<void> calculateHealthTrend() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.calculateHealthTrend(
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
        error: 'Failed to calculate health trend: $e',
      );
    }
  }

  /// Checks trigger status.
  Future<void> checkTriggerStatus() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.checkTriggerStatus(
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
        error: 'Failed to check triggers: $e',
      );
    }
  }

  /// Creates a new bet.
  Future<void> createNewBet({
    required String prediction,
    required String wrongIf,
    int durationDays = 90,
  }) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.createNewBet(
        sessionId: sessionId,
        currentData: state.data,
        prediction: prediction,
        wrongIf: wrongIf,
        durationDays: durationDays,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Load the first board member for interrogation
      await _loadNextBoardMember(updatedData);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to create bet: $e',
      );
    }
  }

  /// Loads the next board member and generates their question.
  Future<void> _loadNextBoardMember(QuarterlySessionData data) async {
    final service = _service;
    if (service == null) return;

    try {
      final member = await service.getCurrentBoardMember(data);
      if (member == null) return;

      final question = await service.generateBoardQuestion(
        member: member,
        data: data,
      );

      state = state.copyWith(
        currentBoardMember: member,
        currentBoardQuestion: question,
      );
    } catch (e) {
      // Use signature question as fallback
      final member = await service.getCurrentBoardMember(data);
      if (member != null) {
        final roleType = BoardRoleType.values.firstWhere(
          (r) => r.name == member.roleType,
          orElse: () => BoardRoleType.accountability,
        );
        state = state.copyWith(
          currentBoardMember: member,
          currentBoardQuestion:
              member.anchoredDemand ?? roleType.signatureQuestion,
        );
      }
    }
  }

  /// Processes a board interrogation response.
  Future<void> processBoardResponse(String response) async {
    final service = _service;
    final sessionId = state.sessionId;
    final member = state.currentBoardMember;
    final question = state.currentBoardQuestion;

    if (service == null ||
        sessionId == null ||
        member == null ||
        question == null) {
      return;
    }

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.processBoardResponse(
        sessionId: sessionId,
        currentData: state.data,
        member: member,
        question: question,
        response: response,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Load next board member if still in interrogation
      if (updatedData.currentState == QuarterlyState.coreBoardInterrogation ||
          updatedData.currentState == QuarterlyState.growthBoardInterrogation) {
        await _loadNextBoardMember(updatedData);
      } else if (updatedData.currentState == QuarterlyState.generateReport) {
        await generateReport();
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process response: $e',
      );
    }
  }

  /// Processes board clarification.
  Future<void> processBoardClarification(String example) async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.processBoardClarification(
        sessionId: sessionId,
        currentData: state.data,
        example: example,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Load next board member if still in interrogation
      if (updatedData.currentState == QuarterlyState.coreBoardInterrogation ||
          updatedData.currentState == QuarterlyState.growthBoardInterrogation) {
        await _loadNextBoardMember(updatedData);
      } else if (updatedData.currentState == QuarterlyState.generateReport) {
        await generateReport();
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process clarification: $e',
      );
    }
  }

  /// Skips board clarification.
  Future<bool> skipBoardClarification() async {
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
      final updatedData = await service.skipBoardClarification(
        sessionId: sessionId,
        currentData: state.data,
      );

      state = state.copyWith(
        data: updatedData,
        isProcessing: false,
      );

      // Load next board member if still in interrogation
      if (updatedData.currentState == QuarterlyState.coreBoardInterrogation ||
          updatedData.currentState == QuarterlyState.growthBoardInterrogation) {
        await _loadNextBoardMember(updatedData);
      } else if (updatedData.currentState == QuarterlyState.generateReport) {
        await generateReport();
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

  /// Generates the final report.
  Future<void> generateReport() async {
    final service = _service;
    final sessionId = state.sessionId;
    if (service == null || sessionId == null) return;

    state = state.copyWith(isProcessing: true, error: null);

    try {
      final updatedData = await service.generateReport(
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
        error: 'Failed to generate report: $e',
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
      state = const QuarterlySessionState();
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

/// Provider for Quarterly session state.
final quarterlySessionProvider =
    NotifierProvider.autoDispose<QuarterlySessionNotifier, QuarterlySessionState>(
  QuarterlySessionNotifier.new,
);

// ==================
// Quarterly Helpers
// ==================

/// Provider to check if there's an in-progress Quarterly session.
final hasInProgressQuarterlyProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(governanceSessionRepositoryProvider);
  final session = await repo.getInProgress();
  if (session != null &&
      session.sessionType == GovernanceSessionType.quarterly.name) {
    return session.id;
  }
  return null;
});

/// Provider for checking quarterly eligibility.
final quarterlyEligibilityProvider =
    FutureProvider<QuarterlyEligibility>((ref) async {
  final service = ref.watch(quarterlyServiceProvider);

  if (service == null) {
    return const QuarterlyEligibility(
      isEligible: false,
      reason: 'AI service not configured',
    );
  }

  // Check prerequisites
  final prereqResult = await service.checkPrerequisites();
  if (!prereqResult.passed) {
    final missing = <String>[];
    if (!prereqResult.hasPortfolio) missing.add('portfolio');
    if (!prereqResult.hasBoard) missing.add('board');
    if (!prereqResult.hasTriggers) missing.add('triggers');
    return QuarterlyEligibility(
      isEligible: false,
      reason: 'Missing: ${missing.join(", ")}',
    );
  }

  // Check recent report
  final recentResult = await service.checkRecentReport();

  return QuarterlyEligibility(
    isEligible: true,
    showWarning: recentResult.showWarning,
    warningMessage: recentResult.showWarning
        ? 'Last report was ${recentResult.daysSinceLastReport} days ago'
        : null,
  );
});

/// Provider for getting the last open bet.
final lastOpenBetProvider = FutureProvider<Bet?>((ref) async {
  final service = ref.watch(quarterlyServiceProvider);
  if (service == null) return null;
  return service.getLastOpenBet();
});

/// Provider for the user's remembered abstraction mode preference for Quarterly.
final rememberedQuarterlyAbstractionModeProvider =
    FutureProvider<bool?>((ref) async {
  final service = ref.watch(quarterlyServiceProvider);
  if (service == null) return null;
  return service.getRememberedAbstractionMode();
});

/// Quarterly eligibility result.
class QuarterlyEligibility {
  final bool isEligible;
  final String? reason;
  final bool showWarning;
  final String? warningMessage;

  const QuarterlyEligibility({
    required this.isEligible,
    this.reason,
    this.showWarning = false,
    this.warningMessage,
  });
}
