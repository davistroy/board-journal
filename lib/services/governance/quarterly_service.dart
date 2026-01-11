import 'dart:convert';

import '../../data/data.dart';
import '../ai/quarterly_ai_service.dart';
import '../ai/vagueness_detection_service.dart';
import 'quarterly_state.dart';

/// Service for running Quarterly Report sessions.
///
/// Per PRD Section 4.5:
/// - Full quarterly report with board interrogation
/// - Evidence enforcement with strength labeling
/// - Bet evaluation (CORRECT/WRONG/EXPIRED) and creation
/// - Portfolio health trend analysis
/// - Each board member asks one question based on their anchoring
/// - Vagueness gates enforced (max 2 skips per session)
class QuarterlyService {
  final GovernanceSessionRepository _sessionRepository;
  final BetRepository _betRepository;
  final ProblemRepository _problemRepository;
  final BoardMemberRepository _boardMemberRepository;
  final PortfolioVersionRepository _portfolioVersionRepository;
  final PortfolioHealthRepository _portfolioHealthRepository;
  final ReSetupTriggerRepository _triggerRepository;
  final EvidenceItemRepository _evidenceRepository;
  final UserPreferencesRepository _preferencesRepository;
  final VaguenessDetectionService _vaguenessService;
  final QuarterlyAIService _aiService;

  QuarterlyService({
    required GovernanceSessionRepository sessionRepository,
    required BetRepository betRepository,
    required ProblemRepository problemRepository,
    required BoardMemberRepository boardMemberRepository,
    required PortfolioVersionRepository portfolioVersionRepository,
    required PortfolioHealthRepository portfolioHealthRepository,
    required ReSetupTriggerRepository triggerRepository,
    required EvidenceItemRepository evidenceRepository,
    required UserPreferencesRepository preferencesRepository,
    required VaguenessDetectionService vaguenessService,
    required QuarterlyAIService aiService,
  })  : _sessionRepository = sessionRepository,
        _betRepository = betRepository,
        _problemRepository = problemRepository,
        _boardMemberRepository = boardMemberRepository,
        _portfolioVersionRepository = portfolioVersionRepository,
        _portfolioHealthRepository = portfolioHealthRepository,
        _triggerRepository = triggerRepository,
        _evidenceRepository = evidenceRepository,
        _preferencesRepository = preferencesRepository,
        _vaguenessService = vaguenessService,
        _aiService = aiService;

  // ==================
  // Session Lifecycle
  // ==================

  /// Starts a new Quarterly Report session.
  ///
  /// Returns the session ID.
  Future<String> startSession({bool? abstractionMode}) async {
    // Get user's abstraction mode preference if not specified
    final effectiveAbstraction = abstractionMode ??
        (await _preferencesRepository.get()).abstractionModeQuarterly;

    final sessionId = await _sessionRepository.create(
      sessionType: GovernanceSessionType.quarterly,
      initialState: QuarterlyState.sensitivityGate.name,
      abstractionMode: effectiveAbstraction,
    );

    return sessionId;
  }

  /// Loads session data from the database.
  Future<QuarterlySessionData?> loadSession(String sessionId) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;

    final transcriptJson = session.transcriptJson;
    Map<String, dynamic> savedData = {};

    if (transcriptJson.isNotEmpty && transcriptJson != '[]') {
      try {
        savedData = jsonDecode(transcriptJson) as Map<String, dynamic>;
      } catch (e) {
        savedData = {};
      }
    }

    return QuarterlySessionData.fromJson({
      ...savedData,
      'currentState': session.currentState,
      'abstractionMode': session.abstractionMode,
      'vaguenessSkipCount': session.vaguenessSkipCount,
    });
  }

  /// Saves session data to the database.
  Future<void> _saveSession(
      String sessionId, QuarterlySessionData data) async {
    final json = data.toJson();

    // Remove fields stored in separate columns
    json.remove('currentState');
    json.remove('abstractionMode');
    json.remove('vaguenessSkipCount');

    await _sessionRepository.appendToTranscript(sessionId, jsonEncode(json));
    await _sessionRepository.updateState(sessionId, data.currentState.name);
  }

  /// Abandons the current session.
  Future<void> abandonSession(String sessionId) async {
    await _sessionRepository.abandon(sessionId);
  }

  /// Gets the user's remembered abstraction mode preference for Quarterly.
  Future<bool?> getRememberedAbstractionMode() async {
    final prefs = await _preferencesRepository.get();
    if (prefs.rememberAbstractionChoice) {
      return prefs.abstractionModeQuarterly;
    }
    return null;
  }

  // ==================
  // Eligibility Checks
  // ==================

  /// Checks if the prerequisites for quarterly report are met.
  ///
  /// Per PRD: Requires portfolio, board, and triggers to exist.
  Future<PrerequisiteCheckResult> checkPrerequisites() async {
    final hasPortfolio = await _portfolioVersionRepository.hasPortfolio();
    final boardMembers = await _boardMemberRepository.getAll();
    final triggers = await _triggerRepository.getAll();

    final hasBoard = boardMembers.isNotEmpty;
    final hasTriggers = triggers.isNotEmpty;

    return PrerequisiteCheckResult(
      hasPortfolio: hasPortfolio,
      hasBoard: hasBoard,
      hasTriggers: hasTriggers,
      passed: hasPortfolio && hasBoard && hasTriggers,
    );
  }

  /// Checks if there was a recent quarterly report.
  ///
  /// Per PRD: Warning if <30 days since last report (non-blocking).
  Future<RecentReportCheckResult> checkRecentReport() async {
    final lastReport = await _sessionRepository.getMostRecentCompleted(
      GovernanceSessionType.quarterly,
    );

    if (lastReport == null) {
      return const RecentReportCheckResult(
        hasRecentReport: false,
        daysSinceLastReport: null,
        showWarning: false,
      );
    }

    final daysSince =
        DateTime.now().toUtc().difference(lastReport.completedAtUtc!).inDays;
    final showWarning = daysSince < 30;

    return RecentReportCheckResult(
      hasRecentReport: true,
      daysSinceLastReport: daysSince,
      showWarning: showWarning,
    );
  }

  // ==================
  // State Transitions
  // ==================

  /// Sets the sensitivity gate options and advances.
  Future<QuarterlySessionData> setSensitivityGate({
    required String sessionId,
    required QuarterlySessionData currentData,
    required bool abstractionMode,
    bool rememberChoice = false,
  }) async {
    // Save preference if requested
    if (rememberChoice) {
      await _preferencesRepository.updateAbstractionDefaults(
        quarterly: abstractionMode,
        rememberChoice: true,
      );
    }

    final updatedData = currentData.copyWith(
      abstractionMode: abstractionMode,
      currentState: QuarterlyState.gate0Prerequisites,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Processes the prerequisites gate.
  Future<QuarterlySessionData> processPrerequisitesGate({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    final result = await checkPrerequisites();

    if (!result.passed) {
      throw QuarterlyError(
        'Prerequisites not met: '
        '${!result.hasPortfolio ? "No portfolio. " : ""}'
        '${!result.hasBoard ? "No board. " : ""}'
        '${!result.hasTriggers ? "No triggers. " : ""}',
      );
    }

    // Check for growth roles
    final hasAppreciating = await _problemRepository.hasAppreciatingProblems();

    final updatedData = currentData.copyWith(
      prerequisitesPassed: true,
      growthRolesActive: hasAppreciating,
      currentState: QuarterlyState.recentReportWarning,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Processes the recent report warning gate.
  Future<QuarterlySessionData> processRecentReportWarning({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    final result = await checkRecentReport();

    var updatedData = currentData.copyWith(
      showedRecentWarning: result.showWarning,
      daysSinceLastReport: result.daysSinceLastReport,
      currentState: QuarterlyState.q1LastBetEvaluation,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // Bet Evaluation (Q1)
  // ==================

  /// Gets the last open bet for evaluation.
  Future<Bet?> getLastOpenBet() async {
    final bets = await _betRepository.getOpen();
    if (bets.isEmpty) return null;

    // Get the most recent open or expired bet
    bets.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return bets.first;
  }

  /// Evaluates the last bet.
  Future<QuarterlySessionData> evaluateBet({
    required String sessionId,
    required QuarterlySessionData currentData,
    required String betId,
    required BetStatus status,
    String? rationale,
    List<QuarterlyEvidence>? evidence,
  }) async {
    // Validate status
    if (status != BetStatus.correct &&
        status != BetStatus.wrong &&
        status != BetStatus.expired) {
      throw QuarterlyError(
          'Invalid bet status. Must be CORRECT, WRONG, or EXPIRED.');
    }

    // Get the bet
    final bet = await _betRepository.getById(betId);
    if (bet == null) {
      throw QuarterlyError('Bet not found.');
    }

    // Update the bet in the database
    await _betRepository.evaluate(
      betId,
      newStatus: status,
      evaluationNotes: rationale,
    );

    // Store evidence items if provided
    if (evidence != null && evidence.isNotEmpty) {
      for (final item in evidence) {
        await _evidenceRepository.create(
          sessionId: sessionId,
          evidenceType: item.type,
          statementText: item.description,
          strengthFlag: item.strength.name,
          context: 'bet_evaluation:$betId',
        );
      }
    }

    final betEval = BetEvaluation(
      betId: betId,
      prediction: bet.prediction,
      wrongIf: bet.wrongIf,
      status: status,
      rationale: rationale,
      evidence: evidence ?? [],
    );

    // Add to transcript
    final qa = QuarterlyQA(
      question: 'Evaluate your last bet: "${bet.prediction}"',
      answer: '${status.displayName}${rationale != null ? ": $rationale" : ""}',
      state: QuarterlyState.q1LastBetEvaluation,
    );

    final updatedData = currentData.copyWith(
      betEvaluation: betEval,
      transcript: [...currentData.transcript, qa],
      currentState: QuarterlyState.q2CommitmentsVsActuals,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Skips bet evaluation (no open bet).
  Future<QuarterlySessionData> skipBetEvaluation({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    final qa = QuarterlyQA(
      question: 'Bet Evaluation',
      answer: '[No open bet to evaluate]',
      state: QuarterlyState.q1LastBetEvaluation,
    );

    final updatedData = currentData.copyWith(
      transcript: [...currentData.transcript, qa],
      currentState: QuarterlyState.q2CommitmentsVsActuals,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // Question Processing (Q2-Q5)
  // ==================

  /// Gets the question text for the current state.
  String getQuestionText(QuarterlySessionData data) {
    switch (data.currentState) {
      case QuarterlyState.q2CommitmentsVsActuals:
        return 'What commitments did you make last quarter and how did they compare to your actual actions? Provide evidence where possible.';

      case QuarterlyState.q2Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.q3AvoidedDecision:
        return 'What decision or conversation have you been avoiding this quarter? What is the cost of continuing to wait?';

      case QuarterlyState.q3Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.q4ComfortWork:
        return 'Where have you been doing comfort work this quarter - tasks that feel productive but do not advance your goals?';

      case QuarterlyState.q4Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.q5PortfolioCheck:
        return 'Review your portfolio problems. Have any directions shifted? Should any time allocations change?';

      case QuarterlyState.q5Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.q7ProtectionCheck:
        return 'Your appreciating problems are your strengths. What threats could cause you to lose these advantages?';

      case QuarterlyState.q7Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.q8OpportunityCheck:
        return 'What adjacent opportunities exist near your appreciating problems? What would 2x their value?';

      case QuarterlyState.q8Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuarterlyState.boardInterrogationClarify:
        return 'Give one concrete example (who/what/when/result).';

      default:
        return '';
    }
  }

  /// Processes a user's answer and advances the state machine.
  Future<QuarterlySessionData> processAnswer({
    required String sessionId,
    required QuarterlySessionData currentData,
    required String answer,
  }) async {
    final state = currentData.currentState;
    final question = getQuestionText(currentData);

    // Check for vagueness if required
    bool isVague = false;
    if (state.requiresVaguenessCheck && !state.isClarify) {
      final vaguenessResult = await _vaguenessService.checkVagueness(
        question: question,
        answer: answer,
      );
      isVague = vaguenessResult.isVague;
    }

    // Create Q&A entry
    final qa = QuarterlyQA(
      question: question,
      answer: answer,
      wasVague: isVague,
      state: state,
    );

    var updatedData = currentData.copyWith(
      transcript: [...currentData.transcript, qa],
    );

    // Process based on current state
    switch (state) {
      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        updatedData = updatedData.copyWith(commitmentsResponse: answer);
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q2Clarify);
        } else {
          updatedData = updatedData.copyWith(
              currentState: QuarterlyState.q3AvoidedDecision);
        }
        break;

      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        updatedData = updatedData.copyWith(avoidedDecision: answer);
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q3Clarify);
        } else {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q4ComfortWork);
        }
        break;

      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        updatedData = updatedData.copyWith(comfortWork: answer);
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q4Clarify);
        } else {
          updatedData = updatedData.copyWith(
              currentState: QuarterlyState.q5PortfolioCheck);
        }
        break;

      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q5Clarify);
        } else {
          updatedData = updatedData.copyWith(
              currentState: QuarterlyState.q6PortfolioHealthUpdate);
        }
        break;

      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        updatedData = updatedData.copyWith(protectionResponse: answer);
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q7Clarify);
        } else {
          updatedData = updatedData.copyWith(
              currentState: QuarterlyState.q8OpportunityCheck);
        }
        break;

      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        updatedData = updatedData.copyWith(opportunityResponse: answer);
        if (isVague) {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q8Clarify);
        } else {
          updatedData =
              updatedData.copyWith(currentState: QuarterlyState.q9TriggerCheck);
        }
        break;

      default:
        break;
    }

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Handles user choosing to skip a vagueness gate.
  Future<QuarterlySessionData> skipVaguenessGate({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    if (!currentData.canSkip) {
      throw QuarterlyError(
          'Maximum skips reached (2). You must provide a concrete example.');
    }

    // Record the skip
    await _sessionRepository.incrementVaguenessSkip(sessionId);

    // Add "[example refused]" to transcript
    final qa = QuarterlyQA(
      question: getQuestionText(currentData),
      answer: '[example refused]',
      wasVague: true,
      skipped: true,
      state: currentData.currentState,
    );

    final updatedData = currentData.copyWith(
      vaguenessSkipCount: currentData.vaguenessSkipCount + 1,
      transcript: [...currentData.transcript, qa],
      currentState: currentData.currentState.nextState,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // Portfolio Health (Q6)
  // ==================

  /// Calculates portfolio health trend.
  Future<QuarterlySessionData> calculateHealthTrend({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    // Get previous health
    final previousHealth = await _portfolioHealthRepository.getCurrent();

    // Calculate current health from problems
    final problems = await _problemRepository.getAll();
    var currentAppreciating = 0;
    var currentDepreciating = 0;
    var currentStable = 0;

    for (final problem in problems) {
      switch (problem.direction) {
        case ProblemDirection.appreciating:
          currentAppreciating += problem.timeAllocationPercent;
          break;
        case ProblemDirection.depreciating:
          currentDepreciating += problem.timeAllocationPercent;
          break;
        case ProblemDirection.stable:
          currentStable += problem.timeAllocationPercent;
          break;
      }
    }

    // Generate trend analysis
    final trend = HealthTrend(
      previousAppreciating: previousHealth?.appreciatingPercent ?? 0,
      currentAppreciating: currentAppreciating,
      previousDepreciating: previousHealth?.depreciatingPercent ?? 0,
      currentDepreciating: currentDepreciating,
      previousStable: previousHealth?.stablePercent ?? 0,
      currentStable: currentStable,
      trendDescription: await _aiService.generateTrendDescription(
        previousAppreciating: previousHealth?.appreciatingPercent ?? 0,
        currentAppreciating: currentAppreciating,
        previousDepreciating: previousHealth?.depreciatingPercent ?? 0,
        currentDepreciating: currentDepreciating,
      ),
    );

    // Add to transcript
    final qa = QuarterlyQA(
      question: 'Portfolio Health Trend',
      answer:
          'Appreciating: ${trend.previousAppreciating}% -> ${trend.currentAppreciating}%, '
          'Depreciating: ${trend.previousDepreciating}% -> ${trend.currentDepreciating}%',
      state: QuarterlyState.q6PortfolioHealthUpdate,
    );

    // Determine next state based on growth roles
    final nextState = currentData.growthRolesActive
        ? QuarterlyState.q7ProtectionCheck
        : QuarterlyState.q9TriggerCheck;

    final updatedData = currentData.copyWith(
      healthTrend: trend,
      transcript: [...currentData.transcript, qa],
      currentState: nextState,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // Trigger Check (Q9)
  // ==================

  /// Checks re-setup trigger status.
  Future<QuarterlySessionData> checkTriggerStatus({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    final triggers = await _triggerRepository.getAll();
    final statuses = <TriggerStatus>[];
    var anyMet = false;

    for (final trigger in triggers) {
      final isMet = trigger.isMet;
      if (isMet) anyMet = true;

      statuses.add(TriggerStatus(
        triggerId: trigger.id,
        triggerType: trigger.triggerType,
        description: trigger.description,
        isMet: isMet,
        details: trigger.isMet
            ? 'Trigger condition has been met'
            : 'Trigger not yet met',
      ));
    }

    // Add to transcript
    final qa = QuarterlyQA(
      question: 'Re-setup Trigger Status',
      answer: anyMet
          ? 'Warning: ${statuses.where((s) => s.isMet).length} trigger(s) met'
          : 'No triggers met',
      state: QuarterlyState.q9TriggerCheck,
    );

    final updatedData = currentData.copyWith(
      triggerStatuses: statuses,
      anyTriggerMet: anyMet,
      transcript: [...currentData.transcript, qa],
      currentState: QuarterlyState.q10NextBet,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // New Bet (Q10)
  // ==================

  /// Creates a new bet.
  Future<QuarterlySessionData> createNewBet({
    required String sessionId,
    required QuarterlySessionData currentData,
    required String prediction,
    required String wrongIf,
    int durationDays = 90,
  }) async {
    final newBet = NewBet(
      prediction: prediction,
      wrongIf: wrongIf,
      durationDays: durationDays,
    );

    // Add to transcript
    final qa = QuarterlyQA(
      question: 'Create new bet with wrong-if condition',
      answer: 'Prediction: $prediction | Wrong if: $wrongIf',
      state: QuarterlyState.q10NextBet,
    );

    final updatedData = currentData.copyWith(
      newBet: newBet,
      transcript: [...currentData.transcript, qa],
      currentState: QuarterlyState.coreBoardInterrogation,
      currentBoardMemberIndex: 0,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  // ==================
  // Board Interrogation
  // ==================

  /// Gets the board members for interrogation.
  Future<List<BoardMember>> getBoardMembers({bool coreOnly = false}) async {
    final members = await _boardMemberRepository.getActive();
    if (coreOnly) {
      return members.where((m) => !m.isGrowthRole).toList();
    }
    return members;
  }

  /// Gets the next board member to ask a question.
  Future<BoardMember?> getCurrentBoardMember(
      QuarterlySessionData data) async {
    final members = await getBoardMembers(
      coreOnly: data.currentState == QuarterlyState.coreBoardInterrogation,
    );

    final relevantMembers = data.currentState ==
            QuarterlyState.coreBoardInterrogation
        ? members.where((m) => !m.isGrowthRole).toList()
        : members.where((m) => m.isGrowthRole).toList();

    if (data.currentBoardMemberIndex >= relevantMembers.length) {
      return null;
    }

    return relevantMembers[data.currentBoardMemberIndex];
  }

  /// Generates a question from a board member.
  Future<String> generateBoardQuestion({
    required BoardMember member,
    required QuarterlySessionData data,
  }) async {
    final roleType = BoardRoleType.values.firstWhere(
      (r) => r.name == member.roleType,
      orElse: () => BoardRoleType.accountability,
    );
    return _aiService.generateBoardQuestion(
      roleType: roleType,
      personaName: member.personaName,
      anchoredProblemId: member.anchoredProblemId,
      anchoredDemand: member.anchoredDemand,
      sessionContext: data,
    );
  }

  /// Processes a board interrogation response.
  Future<QuarterlySessionData> processBoardResponse({
    required String sessionId,
    required QuarterlySessionData currentData,
    required BoardMember member,
    required String question,
    required String response,
  }) async {
    // Check for vagueness
    final vaguenessResult = await _vaguenessService.checkVagueness(
      question: question,
      answer: response,
    );

    final roleType = BoardRoleType.values.firstWhere(
      (r) => r.name == member.roleType,
      orElse: () => BoardRoleType.accountability,
    );

    final boardResponse = BoardInterrogationResponse(
      roleType: roleType,
      personaName: member.personaName,
      anchoredProblemId: member.anchoredProblemId,
      anchoredDemand: member.anchoredDemand,
      question: question,
      response: response,
      wasVague: vaguenessResult.isVague,
    );

    // Add to transcript
    final qa = QuarterlyQA(
      question: question,
      answer: response,
      wasVague: vaguenessResult.isVague,
      state: currentData.currentState,
      roleType: roleType,
      personaName: member.personaName,
    );

    final isCore = !member.isGrowthRole;
    final responses = isCore
        ? [...currentData.coreBoardResponses, boardResponse]
        : [...currentData.growthBoardResponses, boardResponse];

    var updatedData = currentData.copyWith(
      coreBoardResponses: isCore ? responses : currentData.coreBoardResponses,
      growthBoardResponses:
          isCore ? currentData.growthBoardResponses : responses,
      transcript: [...currentData.transcript, qa],
    );

    // Handle vagueness
    if (vaguenessResult.isVague) {
      updatedData = updatedData.copyWith(
        inBoardClarification: true,
        currentState: QuarterlyState.boardInterrogationClarify,
      );
    } else {
      updatedData = await _advanceBoardInterrogation(updatedData, isCore);
    }

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Processes a board clarification response.
  Future<QuarterlySessionData> processBoardClarification({
    required String sessionId,
    required QuarterlySessionData currentData,
    required String example,
  }) async {
    final isCore = currentData.currentState.parentQuestionState ==
            QuarterlyState.coreBoardInterrogation ||
        currentData.coreBoardResponses.length <=
            currentData.growthBoardResponses.length;

    // Update the last response with the example
    final responses =
        isCore ? currentData.coreBoardResponses : currentData.growthBoardResponses;

    if (responses.isNotEmpty) {
      final lastResponse = responses.last;
      final updatedResponse =
          lastResponse.copyWith(concreteExample: example);
      final updatedResponses = [...responses];
      updatedResponses[updatedResponses.length - 1] = updatedResponse;

      final qa = QuarterlyQA(
        question: 'Give one concrete example (who/what/when/result).',
        answer: example,
        state: QuarterlyState.boardInterrogationClarify,
        roleType: lastResponse.roleType,
        personaName: lastResponse.personaName,
      );

      var updatedData = currentData.copyWith(
        coreBoardResponses: isCore ? updatedResponses : currentData.coreBoardResponses,
        growthBoardResponses:
            isCore ? currentData.growthBoardResponses : updatedResponses,
        transcript: [...currentData.transcript, qa],
        inBoardClarification: false,
      );

      updatedData = await _advanceBoardInterrogation(updatedData, isCore);
      await _saveSession(sessionId, updatedData);
      return updatedData;
    }

    return currentData;
  }

  /// Skips board clarification.
  Future<QuarterlySessionData> skipBoardClarification({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    if (!currentData.canSkip) {
      throw QuarterlyError(
          'Maximum skips reached (2). You must provide a concrete example.');
    }

    await _sessionRepository.incrementVaguenessSkip(sessionId);

    final isCore = currentData.coreBoardResponses.length <=
        currentData.growthBoardResponses.length;

    // Update the last response with skipped flag
    final responses =
        isCore ? currentData.coreBoardResponses : currentData.growthBoardResponses;

    if (responses.isNotEmpty) {
      final lastResponse = responses.last;
      final updatedResponse = lastResponse.copyWith(skipped: true);
      final updatedResponses = [...responses];
      updatedResponses[updatedResponses.length - 1] = updatedResponse;

      final qa = QuarterlyQA(
        question: 'Give one concrete example (who/what/when/result).',
        answer: '[example refused]',
        wasVague: true,
        skipped: true,
        state: QuarterlyState.boardInterrogationClarify,
        roleType: lastResponse.roleType,
        personaName: lastResponse.personaName,
      );

      var updatedData = currentData.copyWith(
        coreBoardResponses: isCore ? updatedResponses : currentData.coreBoardResponses,
        growthBoardResponses:
            isCore ? currentData.growthBoardResponses : updatedResponses,
        transcript: [...currentData.transcript, qa],
        vaguenessSkipCount: currentData.vaguenessSkipCount + 1,
        inBoardClarification: false,
      );

      updatedData = await _advanceBoardInterrogation(updatedData, isCore);
      await _saveSession(sessionId, updatedData);
      return updatedData;
    }

    return currentData;
  }

  Future<QuarterlySessionData> _advanceBoardInterrogation(
    QuarterlySessionData data,
    bool isCore,
  ) async {
    final coreMembers = await getBoardMembers(coreOnly: true);
    final allMembers = await getBoardMembers();
    final growthMembers = allMembers.where((m) => m.isGrowthRole).toList();

    if (isCore) {
      // Check if more core members to interrogate
      if (data.coreBoardResponses.length < coreMembers.length) {
        return data.copyWith(
          currentBoardMemberIndex: data.coreBoardResponses.length,
          currentState: QuarterlyState.coreBoardInterrogation,
        );
      } else {
        // Move to growth interrogation or generate report
        if (data.growthRolesActive && growthMembers.isNotEmpty) {
          return data.copyWith(
            currentBoardMemberIndex: 0,
            currentState: QuarterlyState.growthBoardInterrogation,
          );
        } else {
          return data.copyWith(
            currentState: QuarterlyState.generateReport,
          );
        }
      }
    } else {
      // Check if more growth members to interrogate
      if (data.growthBoardResponses.length < growthMembers.length) {
        return data.copyWith(
          currentBoardMemberIndex: data.growthBoardResponses.length,
          currentState: QuarterlyState.growthBoardInterrogation,
        );
      } else {
        return data.copyWith(
          currentState: QuarterlyState.generateReport,
        );
      }
    }
  }

  // ==================
  // Report Generation
  // ==================

  /// Generates the final quarterly report.
  Future<QuarterlySessionData> generateReport({
    required String sessionId,
    required QuarterlySessionData currentData,
  }) async {
    // Create the new bet in the database
    String? createdBetId;
    if (currentData.newBet != null) {
      createdBetId = await _betRepository.create(
        prediction: currentData.newBet!.prediction,
        wrongIf: currentData.newBet!.wrongIf,
        sourceSessionId: sessionId,
      );
    }

    // Update portfolio health
    if (currentData.healthTrend != null) {
      final nextVersion =
          await _portfolioVersionRepository.getNextVersionNumber();
      await _portfolioHealthRepository.upsert(
        appreciatingPercent: currentData.healthTrend!.currentAppreciating,
        depreciatingPercent: currentData.healthTrend!.currentDepreciating,
        stablePercent: currentData.healthTrend!.currentStable,
        portfolioVersion: nextVersion,
      );
    }

    // Generate the report markdown
    final reportMarkdown = await _aiService.generateReport(
      sessionData: currentData,
    );

    // Complete the session
    await _sessionRepository.complete(
      sessionId,
      outputMarkdown: reportMarkdown,
      createdBetId: createdBetId,
    );

    final updatedData = currentData.copyWith(
      outputMarkdown: reportMarkdown,
      createdBetId: createdBetId,
      currentState: QuarterlyState.finalized,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }
}

/// Result of prerequisite check.
class PrerequisiteCheckResult {
  final bool hasPortfolio;
  final bool hasBoard;
  final bool hasTriggers;
  final bool passed;

  const PrerequisiteCheckResult({
    required this.hasPortfolio,
    required this.hasBoard,
    required this.hasTriggers,
    required this.passed,
  });
}

/// Result of recent report check.
class RecentReportCheckResult {
  final bool hasRecentReport;
  final int? daysSinceLastReport;
  final bool showWarning;

  const RecentReportCheckResult({
    required this.hasRecentReport,
    required this.daysSinceLastReport,
    required this.showWarning,
  });
}

/// Error in Quarterly service.
class QuarterlyError implements Exception {
  final String message;

  QuarterlyError(this.message);

  @override
  String toString() => 'QuarterlyError: $message';
}
