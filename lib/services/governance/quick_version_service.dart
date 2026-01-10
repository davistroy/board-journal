import 'dart:convert';

import '../../data/data.dart';
import '../ai/quick_version_ai_service.dart';
import '../ai/vagueness_detection_service.dart';
import 'quick_version_state.dart';

/// Service for running Quick Version (15-min audit) sessions.
///
/// Per PRD Section 4.3:
/// - 5-question audit with anti-vagueness enforcement
/// - One question at a time
/// - Max 2 skips per session
/// - Produces direction table, assessment, and bet
class QuickVersionService {
  final GovernanceSessionRepository _sessionRepository;
  final BetRepository _betRepository;
  final UserPreferencesRepository _preferencesRepository;
  final VaguenessDetectionService _vaguenessService;
  final QuickVersionAIService _aiService;

  QuickVersionService({
    required GovernanceSessionRepository sessionRepository,
    required BetRepository betRepository,
    required UserPreferencesRepository preferencesRepository,
    required VaguenessDetectionService vaguenessService,
    required QuickVersionAIService aiService,
  })  : _sessionRepository = sessionRepository,
        _betRepository = betRepository,
        _preferencesRepository = preferencesRepository,
        _vaguenessService = vaguenessService,
        _aiService = aiService;

  /// Starts a new Quick Version session.
  ///
  /// Returns the session ID.
  Future<String> startSession({bool? abstractionMode}) async {
    // Get user's abstraction mode preference if not specified
    final effectiveAbstraction = abstractionMode ??
        (await _preferencesRepository.get()).abstractionModeQuick;

    final sessionId = await _sessionRepository.create(
      sessionType: GovernanceSessionType.quick,
      initialState: QuickVersionState.sensitivityGate.name,
      abstractionMode: effectiveAbstraction,
    );

    return sessionId;
  }

  /// Loads session data from the database.
  Future<QuickVersionSessionData?> loadSession(String sessionId) async {
    final session = await _sessionRepository.getById(sessionId);
    if (session == null) return null;

    final transcriptJson = session.transcriptJson;
    Map<String, dynamic> savedData = {};

    if (transcriptJson.isNotEmpty && transcriptJson != '[]') {
      try {
        savedData = jsonDecode(transcriptJson) as Map<String, dynamic>;
      } catch (e) {
        // Old format - just transcript array
        savedData = {'transcript': jsonDecode(transcriptJson)};
      }
    }

    return QuickVersionSessionData.fromJson({
      ...savedData,
      'currentState': session.currentState,
      'abstractionMode': session.abstractionMode,
      'vaguenessSkipCount': session.vaguenessSkipCount,
    });
  }

  /// Saves session data to the database.
  Future<void> _saveSession(String sessionId, QuickVersionSessionData data) async {
    final json = data.toJson();

    // Remove fields stored in separate columns
    json.remove('currentState');
    json.remove('abstractionMode');
    json.remove('vaguenessSkipCount');

    await _sessionRepository.appendToTranscript(sessionId, jsonEncode(json));
    await _sessionRepository.updateState(sessionId, data.currentState.name);
  }

  /// Gets the question text for the current state.
  String getQuestionText(QuickVersionSessionData data) {
    switch (data.currentState) {
      case QuickVersionState.q1RoleContext:
        return 'In 1-2 sentences, what is your current role and work context?';

      case QuickVersionState.q1Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuickVersionState.q2PaidProblems:
        return 'What are the 3 problems you are paid to solve? List them briefly.';

      case QuickVersionState.q2Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuickVersionState.q3DirectionLoop:
        final problem = data.currentProblem;
        if (problem == null) return 'Error: No problem selected';

        switch (data.currentDirectionSubQuestion) {
          case 0:
            return 'For "${problem.name}": Is AI getting cheaper at solving this? How so?';
          case 1:
            return 'For "${problem.name}": What\'s the cost if you get this wrong?';
          case 2:
            return 'For "${problem.name}": Is trust or special access required to solve this?';
          default:
            return 'Error: Invalid sub-question';
        }

      case QuickVersionState.q3Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuickVersionState.q4AvoidedDecision:
        return 'What decision or conversation have you been avoiding? What\'s the cost of waiting?';

      case QuickVersionState.q4Clarify:
        return 'Give one concrete example (who/what/when/result).';

      case QuickVersionState.q5ComfortWork:
        return 'Where are you doing comfort work—tasks that feel productive but don\'t advance your goals?';

      case QuickVersionState.q5Clarify:
        return 'Give one concrete example (who/what/when/result).';

      default:
        return '';
    }
  }

  /// Processes a user's answer and advances the state machine.
  ///
  /// Returns the updated session data.
  Future<QuickVersionSessionData> processAnswer({
    required String sessionId,
    required QuickVersionSessionData currentData,
    required String answer,
  }) async {
    final state = currentData.currentState;
    final question = getQuestionText(currentData);

    // Check for vagueness if this is a main question (not clarify)
    bool isVague = false;
    if (state.isQuestion && !state.isClarify) {
      final vaguenessResult = await _vaguenessService.checkVagueness(
        question: question,
        answer: answer,
      );
      isVague = vaguenessResult.isVague;
    }

    // Create Q&A entry
    final qa = QuickVersionQA(
      question: question,
      answer: answer,
      wasVague: isVague,
      state: state,
      problemIndex: state == QuickVersionState.q3DirectionLoop
          ? currentData.currentProblemIndex
          : null,
    );

    var updatedData = currentData.copyWith(
      transcript: [...currentData.transcript, qa],
    );

    // Process based on current state
    switch (state) {
      case QuickVersionState.q1RoleContext:
      case QuickVersionState.q1Clarify:
        updatedData = updatedData.copyWith(roleContext: answer);
        if (isVague) {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q1Clarify,
          );
        } else {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q2PaidProblems,
          );
        }
        break;

      case QuickVersionState.q2PaidProblems:
      case QuickVersionState.q2Clarify:
        // Parse problems from answer
        final problemNames = await _aiService.parseProblems(answer);
        final problems = problemNames
            .map((name) => IdentifiedProblem(name: name))
            .toList();
        updatedData = updatedData.copyWith(problems: problems);

        if (isVague) {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q2Clarify,
          );
        } else {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q3DirectionLoop,
            currentProblemIndex: 0,
            currentDirectionSubQuestion: 0,
          );
        }
        break;

      case QuickVersionState.q3DirectionLoop:
      case QuickVersionState.q3Clarify:
        updatedData = await _processDirectionAnswer(updatedData, answer, isVague);
        break;

      case QuickVersionState.q4AvoidedDecision:
      case QuickVersionState.q4Clarify:
        // Parse avoided decision and cost
        final parts = _parseAvoidedDecision(answer);
        updatedData = updatedData.copyWith(
          avoidedDecision: parts['decision'],
          avoidedDecisionCost: parts['cost'],
        );

        if (isVague) {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q4Clarify,
          );
        } else {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q5ComfortWork,
          );
        }
        break;

      case QuickVersionState.q5ComfortWork:
      case QuickVersionState.q5Clarify:
        updatedData = updatedData.copyWith(comfortWork: answer);

        if (isVague) {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.q5Clarify,
          );
        } else {
          updatedData = updatedData.copyWith(
            currentState: QuickVersionState.generateOutput,
          );
        }
        break;

      default:
        break;
    }

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  Future<QuickVersionSessionData> _processDirectionAnswer(
    QuickVersionSessionData data,
    String answer,
    bool isVague,
  ) async {
    if (data.currentProblem == null) {
      return data.copyWith(currentState: QuickVersionState.q4AvoidedDecision);
    }

    final problemIndex = data.currentProblemIndex;
    final subQuestion = data.currentDirectionSubQuestion;
    final problems = List<IdentifiedProblem>.from(data.problems);
    var problem = problems[problemIndex];

    // Update the current problem with the answer
    switch (subQuestion) {
      case 0:
        problem = problem.copyWith(aiCheaper: answer);
        break;
      case 1:
        problem = problem.copyWith(errorCost: answer);
        break;
      case 2:
        problem = problem.copyWith(trustRequired: answer);
        break;
    }

    problems[problemIndex] = problem;
    var updatedData = data.copyWith(problems: problems);

    if (isVague) {
      return updatedData.copyWith(
        currentState: QuickVersionState.q3Clarify,
      );
    }

    // Move to next sub-question or next problem
    if (subQuestion < 2) {
      // More sub-questions for this problem
      return updatedData.copyWith(
        currentDirectionSubQuestion: subQuestion + 1,
      );
    } else {
      // Evaluate direction for this problem
      try {
        final evaluation = await _aiService.evaluateDirection(
          problemName: problem.name,
          aiCheaper: problem.aiCheaper ?? '',
          errorCost: problem.errorCost ?? '',
          trustRequired: problem.trustRequired ?? '',
        );

        problem = problem.copyWith(
          direction: evaluation.direction,
          directionRationale: evaluation.rationale,
        );
        problems[problemIndex] = problem;
        updatedData = updatedData.copyWith(problems: problems);
      } catch (e) {
        // Continue even if direction evaluation fails
        problem = problem.copyWith(
          direction: ProblemDirection.stable,
          directionRationale: 'Could not evaluate direction',
        );
        problems[problemIndex] = problem;
        updatedData = updatedData.copyWith(problems: problems);
      }

      // Check if more problems to evaluate
      if (problemIndex < problems.length - 1) {
        return updatedData.copyWith(
          currentProblemIndex: problemIndex + 1,
          currentDirectionSubQuestion: 0,
        );
      } else {
        // All problems evaluated, move to Q4
        return updatedData.copyWith(
          currentState: QuickVersionState.q4AvoidedDecision,
        );
      }
    }
  }

  Map<String, String?> _parseAvoidedDecision(String answer) {
    // Try to extract decision and cost from the answer
    final lowerAnswer = answer.toLowerCase();

    // Look for cost indicators
    final costPatterns = [
      RegExp(r'cost[:\s]+(.+)', caseSensitive: false),
      RegExp(r'consequence[s]?[:\s]+(.+)', caseSensitive: false),
      RegExp(r'impact[:\s]+(.+)', caseSensitive: false),
      RegExp(r'risk[:\s]+(.+)', caseSensitive: false),
    ];

    String? cost;
    String decision = answer;

    for (final pattern in costPatterns) {
      final match = pattern.firstMatch(answer);
      if (match != null) {
        cost = match.group(1)?.trim();
        // Remove the cost part from the decision
        decision = answer.substring(0, match.start).trim();
        break;
      }
    }

    // If answer has two sentences, second might be cost
    if (cost == null) {
      final sentences = answer.split(RegExp(r'[.!?]\s+'));
      if (sentences.length >= 2) {
        decision = sentences[0].trim();
        cost = sentences.sublist(1).join('. ').trim();
      }
    }

    return {
      'decision': decision,
      'cost': cost,
    };
  }

  /// Handles user choosing to skip a vagueness gate.
  ///
  /// Per PRD: Max 2 skips per session, third gate cannot be skipped.
  Future<QuickVersionSessionData> skipVaguenessGate({
    required String sessionId,
    required QuickVersionSessionData currentData,
  }) async {
    if (!currentData.canSkip) {
      throw QuickVersionError('Maximum skips reached (2). You must provide a concrete example.');
    }

    // Record the skip
    await _sessionRepository.incrementVaguenessSkip(sessionId);

    // Add "[example refused]" to transcript
    final qa = QuickVersionQA(
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

  /// Sets abstraction mode and advances past sensitivity gate.
  Future<QuickVersionSessionData> setSensitivityGate({
    required String sessionId,
    required QuickVersionSessionData currentData,
    required bool abstractionMode,
    bool rememberChoice = false,
  }) async {
    // Save preference if requested
    if (rememberChoice) {
      await _preferencesRepository.updateAbstractionDefaults(
        quick: abstractionMode,
        rememberChoice: true,
      );
    }

    final updatedData = currentData.copyWith(
      abstractionMode: abstractionMode,
      currentState: QuickVersionState.q1RoleContext,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Generates the final output and completes the session.
  Future<QuickVersionSessionData> generateOutput({
    required String sessionId,
    required QuickVersionSessionData currentData,
  }) async {
    // Generate output using AI
    final output = await _aiService.generateOutput(sessionData: currentData);

    // Create the bet
    final betId = await _betRepository.create(
      prediction: output.betPrediction,
      wrongIf: output.betWrongIf,
      sourceSessionId: sessionId,
    );

    final updatedData = currentData.copyWith(
      outputMarkdown: output.markdown,
      assessment: output.assessment,
      betPrediction: output.betPrediction,
      betWrongIf: output.betWrongIf,
      currentState: QuickVersionState.finalized,
    );

    // Complete the session in database
    await _sessionRepository.complete(
      sessionId,
      outputMarkdown: output.markdown,
      createdBetId: betId,
    );

    return updatedData;
  }

  /// Abandons the current session.
  Future<void> abandonSession(String sessionId) async {
    await _sessionRepository.abandon(sessionId);
  }

  /// Gets the user's remembered abstraction mode preference.
  Future<bool?> getRememberedAbstractionMode() async {
    final prefs = await _preferencesRepository.get();
    if (prefs.rememberAbstractionChoice) {
      return prefs.abstractionModeQuick;
    }
    return null;
  }

  /// Checks if the user has a remembered abstraction mode choice.
  Future<bool> hasRememberedChoice() async {
    final prefs = await _preferencesRepository.get();
    return prefs.rememberAbstractionChoice;
  }
}

/// Error in Quick Version service.
class QuickVersionError implements Exception {
  final String message;

  QuickVersionError(this.message);

  @override
  String toString() => 'QuickVersionError: $message';
}
