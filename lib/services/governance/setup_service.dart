import 'dart:convert';

import '../../data/data.dart';
import '../ai/setup_ai_service.dart';
import 'setup_state.dart';

/// Service for running Setup sessions (Portfolio + Board creation).
///
/// Per PRD Section 4.4:
/// - Creates 3-5 career problems with full validation
/// - Time allocation validation (95-105% ideal, 90-110% allowed)
/// - Calculates portfolio health metrics
/// - Creates 5 core board roles + 0-2 growth roles
/// - Each role anchored to specific problem with AI-generated demand
/// - Generates personas for each role
/// - Defines re-setup triggers including 12-month annual
class SetupService {
  final GovernanceSessionRepository _sessionRepository;
  final ProblemRepository _problemRepository;
  final BoardMemberRepository _boardMemberRepository;
  final PortfolioHealthRepository _portfolioHealthRepository;
  final PortfolioVersionRepository _portfolioVersionRepository;
  final ReSetupTriggerRepository _triggerRepository;
  final UserPreferencesRepository _preferencesRepository;
  final SetupAIService _aiService;

  SetupService({
    required GovernanceSessionRepository sessionRepository,
    required ProblemRepository problemRepository,
    required BoardMemberRepository boardMemberRepository,
    required PortfolioHealthRepository portfolioHealthRepository,
    required PortfolioVersionRepository portfolioVersionRepository,
    required ReSetupTriggerRepository triggerRepository,
    required UserPreferencesRepository preferencesRepository,
    required SetupAIService aiService,
  })  : _sessionRepository = sessionRepository,
        _problemRepository = problemRepository,
        _boardMemberRepository = boardMemberRepository,
        _portfolioHealthRepository = portfolioHealthRepository,
        _portfolioVersionRepository = portfolioVersionRepository,
        _triggerRepository = triggerRepository,
        _preferencesRepository = preferencesRepository,
        _aiService = aiService;

  /// Starts a new Setup session.
  ///
  /// Returns the session ID.
  Future<String> startSession({bool? abstractionMode}) async {
    // Get user's abstraction mode preference if not specified
    final effectiveAbstraction = abstractionMode ??
        (await _preferencesRepository.get()).abstractionModeSetup;

    final sessionId = await _sessionRepository.create(
      sessionType: GovernanceSessionType.setup,
      initialState: SetupState.sensitivityGate.name,
      abstractionMode: effectiveAbstraction,
    );

    return sessionId;
  }

  /// Loads session data from the database.
  Future<SetupSessionData?> loadSession(String sessionId) async {
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

    return SetupSessionData.fromJson({
      ...savedData,
      'currentState': session.currentState,
      'abstractionMode': session.abstractionMode,
    });
  }

  /// Saves session data to the database.
  Future<void> _saveSession(String sessionId, SetupSessionData data) async {
    final json = data.toJson();

    // Remove fields stored in separate columns
    json.remove('currentState');
    json.remove('abstractionMode');

    await _sessionRepository.appendToTranscript(sessionId, jsonEncode(json));
    await _sessionRepository.updateState(sessionId, data.currentState.name);
  }

  /// Sets the sensitivity gate options and advances.
  Future<SetupSessionData> setSensitivityGate({
    required String sessionId,
    required SetupSessionData currentData,
    required bool abstractionMode,
    bool rememberChoice = false,
  }) async {
    // Save preference if requested
    if (rememberChoice) {
      await _preferencesRepository.updateAbstractionDefaults(
        setup: abstractionMode,
        rememberChoice: true,
      );
    }

    final updatedData = currentData.copyWith(
      abstractionMode: abstractionMode,
      currentState: SetupState.collectProblem1,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Adds or updates a problem at the current index.
  Future<SetupSessionData> saveProblem({
    required String sessionId,
    required SetupSessionData currentData,
    required SetupProblem problem,
  }) async {
    final problems = List<SetupProblem>.from(currentData.problems);
    final index = currentData.currentProblemIndex;

    if (index < problems.length) {
      problems[index] = problem;
    } else {
      problems.add(problem);
    }

    final updatedData = currentData.copyWith(
      problems: problems,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Validates the current problem and advances to next state.
  Future<SetupSessionData> validateAndAdvance({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final problem = currentData.currentProblem;
    if (problem == null || !problem.isComplete) {
      throw SetupError('Problem is incomplete');
    }

    // Determine next state
    SetupState nextState;
    final problemIndex = currentData.currentProblemIndex;

    if (problemIndex < 2) {
      // More required problems
      nextState = SetupState.values.firstWhere(
        (s) => s.name == 'collectProblem${problemIndex + 2}',
      );
    } else {
      // Third problem done, go to portfolio completeness
      nextState = SetupState.portfolioCompleteness;
    }

    final updatedData = currentData.copyWith(
      currentState: nextState,
      currentProblemIndex: problemIndex + 1,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Chooses to add another problem (problem 4 or 5).
  Future<SetupSessionData> addAnotherProblem({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    if (!currentData.canAddMoreProblems) {
      throw SetupError('Maximum 5 problems reached');
    }

    // Determine which problem to collect next
    final nextProblemNum = currentData.problemCount + 1;
    final nextState = SetupState.values.firstWhere(
      (s) => s.name == 'collectProblem$nextProblemNum',
    );

    final updatedData = currentData.copyWith(
      currentState: nextState,
      currentProblemIndex: currentData.problemCount,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Proceeds from portfolio completeness to time allocation.
  Future<SetupSessionData> proceedToTimeAllocation({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    if (!currentData.hasMinimumProblems) {
      throw SetupError('At least 3 problems required');
    }

    final updatedData = currentData.copyWith(
      currentState: SetupState.timeAllocation,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Updates time allocation for all problems.
  Future<SetupSessionData> updateTimeAllocations({
    required String sessionId,
    required SetupSessionData currentData,
    required List<int> allocations,
  }) async {
    if (allocations.length != currentData.problemCount) {
      throw SetupError('Allocation count must match problem count');
    }

    final problems = <SetupProblem>[];
    for (var i = 0; i < currentData.problems.length; i++) {
      problems.add(currentData.problems[i].copyWith(
        timeAllocationPercent: allocations[i],
      ));
    }

    final total = allocations.fold(0, (sum, a) => sum + a);
    final status = SetupSessionData.validateTimeAllocation(total);

    final updatedData = currentData.copyWith(
      problems: problems,
      totalTimeAllocation: total,
      timeAllocationStatus: status,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Validates time allocation and proceeds to health calculation.
  Future<SetupSessionData> proceedFromTimeAllocation({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final status = currentData.timeAllocationStatus;
    if (status == null || !status.canProceed) {
      throw SetupError('Time allocation must be 90-110%');
    }

    final updatedData = currentData.copyWith(
      currentState: SetupState.calculateHealth,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Calculates portfolio health metrics.
  Future<SetupSessionData> calculatePortfolioHealth({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    // Calculate percentages by direction
    var appreciating = 0;
    var depreciating = 0;
    var stable = 0;

    for (final problem in currentData.problems) {
      switch (problem.direction) {
        case ProblemDirection.appreciating:
          appreciating += problem.timeAllocationPercent;
          break;
        case ProblemDirection.depreciating:
          depreciating += problem.timeAllocationPercent;
          break;
        case ProblemDirection.stable:
        case null:
          stable += problem.timeAllocationPercent;
          break;
      }
    }

    // Generate health statements using AI
    final healthStatements = await _aiService.generateHealthStatements(
      problems: currentData.problems,
      appreciatingPercent: appreciating,
      depreciatingPercent: depreciating,
      stablePercent: stable,
    );

    final health = SetupPortfolioHealth(
      appreciatingPercent: appreciating,
      depreciatingPercent: depreciating,
      stablePercent: stable,
      riskStatement: healthStatements.riskStatement,
      opportunityStatement: healthStatements.opportunityStatement,
    );

    final updatedData = currentData.copyWith(
      portfolioHealth: health,
      currentState: SetupState.createCoreRoles,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Creates the 5 core board roles with anchoring.
  Future<SetupSessionData> createCoreRoles({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final coreRoles = BoardRoleTypeExtension.coreRoles;
    final members = <SetupBoardMember>[];

    // Get AI-generated anchoring for each role
    final anchorings = await _aiService.generateBoardAnchoring(
      problems: currentData.problems,
      roles: coreRoles,
    );

    for (var i = 0; i < coreRoles.length; i++) {
      final role = coreRoles[i];
      final anchoring = anchorings[i];

      members.add(SetupBoardMember(
        roleType: role,
        isGrowthRole: false,
        isActive: true,
        anchoredProblemIndex: anchoring.problemIndex,
        anchoredDemand: anchoring.demand,
      ));
    }

    final updatedData = currentData.copyWith(
      boardMembers: members,
      currentState: SetupState.createGrowthRoles,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Creates 0-2 growth roles if appreciating problems exist.
  Future<SetupSessionData> createGrowthRoles({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final members = List<SetupBoardMember>.from(currentData.boardMembers);

    if (currentData.hasAppreciatingProblems) {
      final growthRoles = BoardRoleTypeExtension.growthRoles;

      // Find the highest-appreciating problem
      int? highestAppreciatingIndex;
      var maxAllocation = 0;
      for (var i = 0; i < currentData.problems.length; i++) {
        final problem = currentData.problems[i];
        if (problem.direction == ProblemDirection.appreciating &&
            problem.timeAllocationPercent > maxAllocation) {
          maxAllocation = problem.timeAllocationPercent;
          highestAppreciatingIndex = i;
        }
      }

      // Get AI-generated anchoring for growth roles
      final anchorings = await _aiService.generateBoardAnchoring(
        problems: currentData.problems,
        roles: growthRoles,
        focusOnAppreciating: true,
      );

      for (var i = 0; i < growthRoles.length; i++) {
        final role = growthRoles[i];
        final anchoring = anchorings[i];

        members.add(SetupBoardMember(
          roleType: role,
          isGrowthRole: true,
          isActive: true,
          anchoredProblemIndex:
              anchoring.problemIndex ?? highestAppreciatingIndex,
          anchoredDemand: anchoring.demand,
        ));
      }
    }

    final updatedData = currentData.copyWith(
      boardMembers: members,
      currentState: SetupState.createPersonas,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Generates personas for all board members.
  Future<SetupSessionData> createPersonas({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final members = <SetupBoardMember>[];

    for (final member in currentData.boardMembers) {
      final persona = await _aiService.generatePersona(
        roleType: member.roleType,
        anchoredProblem: member.anchoredProblemIndex != null &&
                member.anchoredProblemIndex! < currentData.problems.length
            ? currentData.problems[member.anchoredProblemIndex!]
            : null,
        demand: member.anchoredDemand,
      );

      members.add(member.copyWith(
        personaName: persona.name,
        personaBackground: persona.background,
        personaCommunicationStyle: persona.communicationStyle,
        personaSignaturePhrase: persona.signaturePhrase,
      ));
    }

    final updatedData = currentData.copyWith(
      boardMembers: members,
      currentState: SetupState.defineReSetupTriggers,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Updates a board member's persona (user edit).
  Future<SetupSessionData> updatePersona({
    required String sessionId,
    required SetupSessionData currentData,
    required int memberIndex,
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) async {
    if (memberIndex >= currentData.boardMembers.length) {
      throw SetupError('Invalid member index');
    }

    final members = List<SetupBoardMember>.from(currentData.boardMembers);
    members[memberIndex] = members[memberIndex].copyWith(
      personaName: name,
      personaBackground: background,
      personaCommunicationStyle: communicationStyle,
      personaSignaturePhrase: signaturePhrase,
    );

    final updatedData = currentData.copyWith(boardMembers: members);
    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Defines re-setup triggers.
  Future<SetupSessionData> defineReSetupTriggers({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    final now = DateTime.now().toUtc();
    final annualDue = now.add(const Duration(days: 365));

    final triggers = <SetupTrigger>[
      SetupTrigger(
        triggerType: 'role_change',
        description: 'Role change detected',
        condition: 'Promotion, new job, or new team',
        recommendedAction: 'full_resetup',
      ),
      SetupTrigger(
        triggerType: 'scope_change',
        description: 'Scope change detected',
        condition: 'Major project ends or new responsibility',
        recommendedAction: 'full_resetup',
      ),
      SetupTrigger(
        triggerType: 'direction_shift',
        description: 'Problem direction shift',
        condition: 'Problem reclassified in 2+ quarterly reviews',
        recommendedAction: 'update_problem',
      ),
      SetupTrigger(
        triggerType: 'time_drift',
        description: 'Time allocation drift',
        condition: '20%+ shift in allocation vs setup',
        recommendedAction: 'review_health',
      ),
      SetupTrigger(
        triggerType: 'annual',
        description: 'Annual portfolio review',
        condition: '12 months since last setup',
        recommendedAction: 'full_resetup',
        dueAtUtc: annualDue,
      ),
    ];

    final updatedData = currentData.copyWith(
      triggers: triggers,
      currentState: SetupState.publishPortfolio,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Publishes the portfolio - saves everything to the database.
  Future<SetupSessionData> publishPortfolio({
    required String sessionId,
    required SetupSessionData currentData,
  }) async {
    // Delete existing problems and board members (re-setup)
    final existingProblems = await _problemRepository.getAll();
    for (final problem in existingProblems) {
      await _problemRepository.softDelete(problem.id);
    }
    await _boardMemberRepository.deleteAll();
    await _triggerRepository.deleteAll();

    // Create problems
    final createdProblemIds = <String>[];
    for (var i = 0; i < currentData.problems.length; i++) {
      final problem = currentData.problems[i];
      final problemId = await _problemRepository.create(
        name: problem.name!,
        whatBreaks: problem.whatBreaks!,
        scarcitySignalsJson: problem.scarcitySignalsJson,
        direction: problem.direction!,
        directionRationale: problem.directionRationale!,
        evidenceAiCheaper: problem.evidenceAiCheaper!,
        evidenceErrorCost: problem.evidenceErrorCost!,
        evidenceTrustRequired: problem.evidenceTrustRequired!,
        timeAllocationPercent: problem.timeAllocationPercent,
        displayOrder: i,
      );
      createdProblemIds.add(problemId);
    }

    // Create board members
    final createdBoardMemberIds = <String>[];
    for (final member in currentData.boardMembers) {
      final problemId = member.anchoredProblemIndex != null &&
              member.anchoredProblemIndex! < createdProblemIds.length
          ? createdProblemIds[member.anchoredProblemIndex!]
          : createdProblemIds.first;

      final boardMemberId = await _boardMemberRepository.create(
        roleType: member.roleType,
        personaName: member.personaName!,
        personaBackground: member.personaBackground!,
        personaCommunicationStyle: member.personaCommunicationStyle!,
        personaSignaturePhrase: member.personaSignaturePhrase,
        anchoredProblemId: problemId,
        anchoredDemand: member.anchoredDemand,
        isGrowthRole: member.isGrowthRole,
        isActive: member.isActive,
      );
      createdBoardMemberIds.add(boardMemberId);
    }

    // Create triggers
    for (final trigger in currentData.triggers) {
      await _triggerRepository.create(
        triggerType: trigger.triggerType,
        description: trigger.description,
        condition: trigger.condition,
        recommendedAction: trigger.recommendedAction,
        dueAtUtc: trigger.dueAtUtc,
      );
    }

    // Save portfolio health
    final health = currentData.portfolioHealth;
    if (health != null) {
      final nextVersion = await _portfolioVersionRepository.getNextVersionNumber();
      await _portfolioHealthRepository.upsert(
        appreciatingPercent: health.appreciatingPercent,
        depreciatingPercent: health.depreciatingPercent,
        stablePercent: health.stablePercent,
        riskStatement: health.riskStatement,
        opportunityStatement: health.opportunityStatement,
        portfolioVersion: nextVersion,
      );
    }

    // Create portfolio version snapshot
    final boardAnchoring = <String, dynamic>{};
    for (final member in currentData.boardMembers) {
      boardAnchoring[member.roleType.name] = {
        'problemIndex': member.anchoredProblemIndex,
        'demand': member.anchoredDemand,
      };
    }

    final nextVersion = await _portfolioVersionRepository.getNextVersionNumber();
    final portfolioVersionId = await _portfolioVersionRepository.create(
      versionNumber: nextVersion,
      problemsSnapshotJson: jsonEncode(
        currentData.problems.map((p) => p.toJson()).toList(),
      ),
      healthSnapshotJson: jsonEncode(currentData.portfolioHealth?.toJson()),
      boardAnchoringSnapshotJson: jsonEncode(boardAnchoring),
      triggersSnapshotJson: jsonEncode(
        currentData.triggers.map((t) => t.toJson()).toList(),
      ),
      triggerReason: 'initial_setup',
    );

    // Generate output summary
    final outputMarkdown = _generateOutputMarkdown(currentData);

    // Complete the session
    await _sessionRepository.complete(
      sessionId,
      outputMarkdown: outputMarkdown,
      createdPortfolioVersionId: portfolioVersionId,
    );

    // Mark setup as completed in preferences
    await _preferencesRepository.completeOnboarding();

    final updatedData = currentData.copyWith(
      createdProblemIds: createdProblemIds,
      createdBoardMemberIds: createdBoardMemberIds,
      portfolioVersionId: portfolioVersionId,
      outputMarkdown: outputMarkdown,
      currentState: SetupState.finalized,
    );

    await _saveSession(sessionId, updatedData);
    return updatedData;
  }

  /// Generates the output summary markdown.
  String _generateOutputMarkdown(SetupSessionData data) {
    final buffer = StringBuffer();

    buffer.writeln('# Portfolio Setup Complete');
    buffer.writeln();

    // Problems summary
    buffer.writeln('## Your Portfolio');
    buffer.writeln();
    buffer.writeln('| Problem | Direction | Time |');
    buffer.writeln('|---------|-----------|------|');
    for (final problem in data.problems) {
      buffer.writeln(
          '| ${problem.name} | ${problem.direction?.displayName ?? 'N/A'} | ${problem.timeAllocationPercent}% |');
    }
    buffer.writeln();

    // Health summary
    final health = data.portfolioHealth;
    if (health != null) {
      buffer.writeln('## Portfolio Health');
      buffer.writeln();
      buffer.writeln('- Appreciating: ${health.appreciatingPercent}%');
      buffer.writeln('- Depreciating: ${health.depreciatingPercent}%');
      buffer.writeln('- Stable: ${health.stablePercent}%');
      buffer.writeln();
      if (health.riskStatement != null) {
        buffer.writeln('**Risk:** ${health.riskStatement}');
        buffer.writeln();
      }
      if (health.opportunityStatement != null) {
        buffer.writeln('**Opportunity:** ${health.opportunityStatement}');
        buffer.writeln();
      }
    }

    // Board summary
    buffer.writeln('## Your Board');
    buffer.writeln();
    for (final member in data.boardMembers) {
      final roleLabel = member.isGrowthRole ? '(Growth)' : '(Core)';
      buffer.writeln('### ${member.personaName} - ${member.roleType.displayName} $roleLabel');
      buffer.writeln();
      buffer.writeln('**Background:** ${member.personaBackground}');
      buffer.writeln();
      buffer.writeln('**Style:** ${member.personaCommunicationStyle}');
      buffer.writeln();
      if (member.personaSignaturePhrase != null) {
        buffer.writeln('*"${member.personaSignaturePhrase}"*');
        buffer.writeln();
      }
      if (member.anchoredDemand != null) {
        buffer.writeln('**Focus:** ${member.anchoredDemand}');
        buffer.writeln();
      }
    }

    // Triggers summary
    buffer.writeln('## Re-Setup Triggers');
    buffer.writeln();
    for (final trigger in data.triggers) {
      buffer.writeln('- **${trigger.description}:** ${trigger.condition}');
      if (trigger.dueAtUtc != null) {
        buffer.writeln('  - Due: ${trigger.dueAtUtc!.toLocal()}');
      }
    }

    return buffer.toString();
  }

  /// Abandons the current session.
  Future<void> abandonSession(String sessionId) async {
    await _sessionRepository.abandon(sessionId);
  }

  /// Gets the user's remembered abstraction mode preference for Setup.
  Future<bool?> getRememberedAbstractionMode() async {
    final prefs = await _preferencesRepository.get();
    if (prefs.rememberAbstractionChoice) {
      return prefs.abstractionModeSetup;
    }
    return null;
  }
}

/// Error in Setup service.
class SetupError implements Exception {
  final String message;

  SetupError(this.message);

  @override
  String toString() => 'SetupError: $message';
}
