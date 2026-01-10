/// Setup state machine definitions for portfolio creation and board instantiation.
///
/// Per PRD Section 4.4:
/// - Creates 3-5 career problems with validation
/// - Time allocation 95-105% (warning 90-110%)
/// - Calculates portfolio health
/// - Creates 5 core roles + 0-2 growth roles
/// - Each role anchored to specific problem with specific demand
/// - Defines re-setup triggers

import 'dart:convert';

import '../../data/enums/board_role_type.dart';
import '../../data/enums/problem_direction.dart';

/// States in the Setup state machine.
enum SetupState {
  /// Initial state before starting.
  initial,

  /// Privacy reminder with abstraction mode option.
  sensitivityGate,

  /// Collecting first problem (required).
  collectProblem1,

  /// Validating first problem fields.
  validateProblem1,

  /// Collecting second problem (required).
  collectProblem2,

  /// Validating second problem fields.
  validateProblem2,

  /// Collecting third problem (required).
  collectProblem3,

  /// Validating third problem fields.
  validateProblem3,

  /// Collecting fourth problem (optional).
  collectProblem4,

  /// Validating fourth problem fields.
  validateProblem4,

  /// Collecting fifth problem (optional).
  collectProblem5,

  /// Validating fifth problem fields.
  validateProblem5,

  /// Checking portfolio has 3-5 problems.
  portfolioCompleteness,

  /// Time allocation validation (95-105%).
  timeAllocation,

  /// Calculating portfolio health metrics.
  calculateHealth,

  /// Creating the 5 core board roles.
  createCoreRoles,

  /// Creating 0-2 growth roles if appreciating problems exist.
  createGrowthRoles,

  /// Generating personas for each role.
  createPersonas,

  /// Defining re-setup trigger conditions.
  defineReSetupTriggers,

  /// Publishing portfolio version snapshot.
  publishPortfolio,

  /// Session completed.
  finalized,

  /// Session abandoned or errored.
  abandoned,
}

/// Extension methods for SetupState.
extension SetupStateExtension on SetupState {
  /// Whether this is a problem collection state.
  bool get isProblemCollection {
    return this == SetupState.collectProblem1 ||
        this == SetupState.collectProblem2 ||
        this == SetupState.collectProblem3 ||
        this == SetupState.collectProblem4 ||
        this == SetupState.collectProblem5;
  }

  /// Whether this is a problem validation state.
  bool get isProblemValidation {
    return this == SetupState.validateProblem1 ||
        this == SetupState.validateProblem2 ||
        this == SetupState.validateProblem3 ||
        this == SetupState.validateProblem4 ||
        this == SetupState.validateProblem5;
  }

  /// Whether this is an optional problem state (4 or 5).
  bool get isOptionalProblem {
    return this == SetupState.collectProblem4 ||
        this == SetupState.validateProblem4 ||
        this == SetupState.collectProblem5 ||
        this == SetupState.validateProblem5;
  }

  /// Gets the problem index for this state (0-indexed).
  int? get problemIndex {
    switch (this) {
      case SetupState.collectProblem1:
      case SetupState.validateProblem1:
        return 0;
      case SetupState.collectProblem2:
      case SetupState.validateProblem2:
        return 1;
      case SetupState.collectProblem3:
      case SetupState.validateProblem3:
        return 2;
      case SetupState.collectProblem4:
      case SetupState.validateProblem4:
        return 3;
      case SetupState.collectProblem5:
      case SetupState.validateProblem5:
        return 4;
      default:
        return null;
    }
  }

  /// Gets the next state in the normal flow.
  SetupState get nextState {
    switch (this) {
      case SetupState.initial:
        return SetupState.sensitivityGate;
      case SetupState.sensitivityGate:
        return SetupState.collectProblem1;
      case SetupState.collectProblem1:
        return SetupState.validateProblem1;
      case SetupState.validateProblem1:
        return SetupState.collectProblem2;
      case SetupState.collectProblem2:
        return SetupState.validateProblem2;
      case SetupState.validateProblem2:
        return SetupState.collectProblem3;
      case SetupState.collectProblem3:
        return SetupState.validateProblem3;
      case SetupState.validateProblem3:
        return SetupState.portfolioCompleteness;
      case SetupState.collectProblem4:
        return SetupState.validateProblem4;
      case SetupState.validateProblem4:
        return SetupState.portfolioCompleteness;
      case SetupState.collectProblem5:
        return SetupState.validateProblem5;
      case SetupState.validateProblem5:
        return SetupState.portfolioCompleteness;
      case SetupState.portfolioCompleteness:
        return SetupState.timeAllocation;
      case SetupState.timeAllocation:
        return SetupState.calculateHealth;
      case SetupState.calculateHealth:
        return SetupState.createCoreRoles;
      case SetupState.createCoreRoles:
        return SetupState.createGrowthRoles;
      case SetupState.createGrowthRoles:
        return SetupState.createPersonas;
      case SetupState.createPersonas:
        return SetupState.defineReSetupTriggers;
      case SetupState.defineReSetupTriggers:
        return SetupState.publishPortfolio;
      case SetupState.publishPortfolio:
        return SetupState.finalized;
      case SetupState.finalized:
      case SetupState.abandoned:
        return this;
    }
  }

  /// Display name for progress indicator.
  String get displayName {
    switch (this) {
      case SetupState.initial:
        return 'Starting';
      case SetupState.sensitivityGate:
        return 'Privacy Settings';
      case SetupState.collectProblem1:
      case SetupState.validateProblem1:
        return 'Problem 1';
      case SetupState.collectProblem2:
      case SetupState.validateProblem2:
        return 'Problem 2';
      case SetupState.collectProblem3:
      case SetupState.validateProblem3:
        return 'Problem 3';
      case SetupState.collectProblem4:
      case SetupState.validateProblem4:
        return 'Problem 4';
      case SetupState.collectProblem5:
      case SetupState.validateProblem5:
        return 'Problem 5';
      case SetupState.portfolioCompleteness:
        return 'Portfolio Review';
      case SetupState.timeAllocation:
        return 'Time Allocation';
      case SetupState.calculateHealth:
        return 'Portfolio Health';
      case SetupState.createCoreRoles:
        return 'Core Roles';
      case SetupState.createGrowthRoles:
        return 'Growth Roles';
      case SetupState.createPersonas:
        return 'Personas';
      case SetupState.defineReSetupTriggers:
        return 'Triggers';
      case SetupState.publishPortfolio:
        return 'Publishing';
      case SetupState.finalized:
        return 'Complete';
      case SetupState.abandoned:
        return 'Abandoned';
    }
  }

  /// Progress percentage (0-100).
  int get progressPercent {
    switch (this) {
      case SetupState.initial:
        return 0;
      case SetupState.sensitivityGate:
        return 5;
      case SetupState.collectProblem1:
      case SetupState.validateProblem1:
        return 10;
      case SetupState.collectProblem2:
      case SetupState.validateProblem2:
        return 20;
      case SetupState.collectProblem3:
      case SetupState.validateProblem3:
        return 30;
      case SetupState.collectProblem4:
      case SetupState.validateProblem4:
        return 35;
      case SetupState.collectProblem5:
      case SetupState.validateProblem5:
        return 40;
      case SetupState.portfolioCompleteness:
        return 45;
      case SetupState.timeAllocation:
        return 55;
      case SetupState.calculateHealth:
        return 65;
      case SetupState.createCoreRoles:
        return 70;
      case SetupState.createGrowthRoles:
        return 75;
      case SetupState.createPersonas:
        return 85;
      case SetupState.defineReSetupTriggers:
        return 90;
      case SetupState.publishPortfolio:
        return 95;
      case SetupState.finalized:
        return 100;
      case SetupState.abandoned:
        return 0;
    }
  }
}

/// Time allocation validation result.
enum TimeAllocationStatus {
  /// 95-105%: Valid, proceed.
  valid,

  /// 90-94% or 106-110%: Warning, allow proceed.
  warning,

  /// <90% or >110%: Error, block proceed.
  error,
}

/// Extension for TimeAllocationStatus.
extension TimeAllocationStatusExtension on TimeAllocationStatus {
  /// Whether user can proceed with this status.
  bool get canProceed =>
      this == TimeAllocationStatus.valid || this == TimeAllocationStatus.warning;

  /// Display message for this status.
  String getMessage(int total) {
    switch (this) {
      case TimeAllocationStatus.valid:
        return 'Time allocation is $total%. Looking good!';
      case TimeAllocationStatus.warning:
        return 'Time allocation is $total%. This is outside the ideal range (95-105%) but you can continue.';
      case TimeAllocationStatus.error:
        return 'Time allocation is $total%. Must be between 90% and 110% to proceed.';
    }
  }
}

/// A problem being collected during Setup.
class SetupProblem {
  /// Problem name/title (required).
  final String? name;

  /// What breaks if this problem isn't solved (required).
  final String? whatBreaks;

  /// Scarcity signals - 2 items or "Unknown" with reason.
  final List<String> scarcitySignals;

  /// If scarcity is unknown, the reason why.
  final String? scarcityUnknownReason;

  /// Evidence: Is AI getting cheaper/better at this?
  final String? evidenceAiCheaper;

  /// Evidence: What is the cost of errors?
  final String? evidenceErrorCost;

  /// Evidence: Is trust/access required?
  final String? evidenceTrustRequired;

  /// Direction classification.
  final ProblemDirection? direction;

  /// One-sentence rationale for direction classification.
  final String? directionRationale;

  /// Time allocation percentage (0-100).
  final int timeAllocationPercent;

  const SetupProblem({
    this.name,
    this.whatBreaks,
    this.scarcitySignals = const [],
    this.scarcityUnknownReason,
    this.evidenceAiCheaper,
    this.evidenceErrorCost,
    this.evidenceTrustRequired,
    this.direction,
    this.directionRationale,
    this.timeAllocationPercent = 0,
  });

  SetupProblem copyWith({
    String? name,
    String? whatBreaks,
    List<String>? scarcitySignals,
    String? scarcityUnknownReason,
    String? evidenceAiCheaper,
    String? evidenceErrorCost,
    String? evidenceTrustRequired,
    ProblemDirection? direction,
    String? directionRationale,
    int? timeAllocationPercent,
  }) =>
      SetupProblem(
        name: name ?? this.name,
        whatBreaks: whatBreaks ?? this.whatBreaks,
        scarcitySignals: scarcitySignals ?? this.scarcitySignals,
        scarcityUnknownReason: scarcityUnknownReason ?? this.scarcityUnknownReason,
        evidenceAiCheaper: evidenceAiCheaper ?? this.evidenceAiCheaper,
        evidenceErrorCost: evidenceErrorCost ?? this.evidenceErrorCost,
        evidenceTrustRequired: evidenceTrustRequired ?? this.evidenceTrustRequired,
        direction: direction ?? this.direction,
        directionRationale: directionRationale ?? this.directionRationale,
        timeAllocationPercent: timeAllocationPercent ?? this.timeAllocationPercent,
      );

  /// Whether all required fields are filled.
  bool get isComplete {
    final hasName = name != null && name!.isNotEmpty;
    final hasWhatBreaks = whatBreaks != null && whatBreaks!.isNotEmpty;
    final hasScarcity = scarcitySignals.length >= 2 ||
        (scarcityUnknownReason != null && scarcityUnknownReason!.isNotEmpty);
    final hasEvidence = evidenceAiCheaper != null &&
        evidenceAiCheaper!.isNotEmpty &&
        evidenceErrorCost != null &&
        evidenceErrorCost!.isNotEmpty &&
        evidenceTrustRequired != null &&
        evidenceTrustRequired!.isNotEmpty;
    final hasDirection = direction != null &&
        directionRationale != null &&
        directionRationale!.isNotEmpty;

    return hasName && hasWhatBreaks && hasScarcity && hasEvidence && hasDirection;
  }

  /// Validates the problem and returns error messages.
  List<String> validate() {
    final errors = <String>[];

    if (name == null || name!.isEmpty) {
      errors.add('Problem name is required');
    }
    if (whatBreaks == null || whatBreaks!.isEmpty) {
      errors.add('What breaks if not solved is required');
    }
    if (scarcitySignals.length < 2 &&
        (scarcityUnknownReason == null || scarcityUnknownReason!.isEmpty)) {
      errors.add('Either 2 scarcity signals or "Unknown + reason" is required');
    }
    if (evidenceAiCheaper == null || evidenceAiCheaper!.isEmpty) {
      errors.add('AI cheaper evidence is required');
    }
    if (evidenceErrorCost == null || evidenceErrorCost!.isEmpty) {
      errors.add('Error cost evidence is required');
    }
    if (evidenceTrustRequired == null || evidenceTrustRequired!.isEmpty) {
      errors.add('Trust required evidence is required');
    }
    if (direction == null) {
      errors.add('Direction classification is required');
    }
    if (directionRationale == null || directionRationale!.isEmpty) {
      errors.add('Direction rationale is required');
    }

    return errors;
  }

  /// Converts scarcity to JSON format for storage.
  String get scarcitySignalsJson {
    if (scarcityUnknownReason != null && scarcityUnknownReason!.isNotEmpty) {
      return jsonEncode({'unknown': true, 'reason': scarcityUnknownReason});
    }
    return jsonEncode(scarcitySignals);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'whatBreaks': whatBreaks,
        'scarcitySignals': scarcitySignals,
        'scarcityUnknownReason': scarcityUnknownReason,
        'evidenceAiCheaper': evidenceAiCheaper,
        'evidenceErrorCost': evidenceErrorCost,
        'evidenceTrustRequired': evidenceTrustRequired,
        'direction': direction?.name,
        'directionRationale': directionRationale,
        'timeAllocationPercent': timeAllocationPercent,
      };

  factory SetupProblem.fromJson(Map<String, dynamic> json) => SetupProblem(
        name: json['name'] as String?,
        whatBreaks: json['whatBreaks'] as String?,
        scarcitySignals: (json['scarcitySignals'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        scarcityUnknownReason: json['scarcityUnknownReason'] as String?,
        evidenceAiCheaper: json['evidenceAiCheaper'] as String?,
        evidenceErrorCost: json['evidenceErrorCost'] as String?,
        evidenceTrustRequired: json['evidenceTrustRequired'] as String?,
        direction: json['direction'] != null
            ? ProblemDirection.values.firstWhere(
                (d) => d.name == json['direction'],
                orElse: () => ProblemDirection.stable,
              )
            : null,
        directionRationale: json['directionRationale'] as String?,
        timeAllocationPercent: json['timeAllocationPercent'] as int? ?? 0,
      );
}

/// A board member being created during Setup.
class SetupBoardMember {
  /// The role type.
  final BoardRoleType roleType;

  /// Whether this is a growth role.
  final bool isGrowthRole;

  /// Whether this role is active.
  final bool isActive;

  /// ID of the problem this role is anchored to.
  final String? anchoredProblemId;

  /// Index of the anchored problem (0-indexed).
  final int? anchoredProblemIndex;

  /// The specific demand derived from the anchored problem.
  final String? anchoredDemand;

  /// Persona name (e.g., "Maya Chen").
  final String? personaName;

  /// Persona background.
  final String? personaBackground;

  /// Persona communication style.
  final String? personaCommunicationStyle;

  /// Persona signature phrase.
  final String? personaSignaturePhrase;

  const SetupBoardMember({
    required this.roleType,
    this.isGrowthRole = false,
    this.isActive = true,
    this.anchoredProblemId,
    this.anchoredProblemIndex,
    this.anchoredDemand,
    this.personaName,
    this.personaBackground,
    this.personaCommunicationStyle,
    this.personaSignaturePhrase,
  });

  SetupBoardMember copyWith({
    BoardRoleType? roleType,
    bool? isGrowthRole,
    bool? isActive,
    String? anchoredProblemId,
    int? anchoredProblemIndex,
    String? anchoredDemand,
    String? personaName,
    String? personaBackground,
    String? personaCommunicationStyle,
    String? personaSignaturePhrase,
  }) =>
      SetupBoardMember(
        roleType: roleType ?? this.roleType,
        isGrowthRole: isGrowthRole ?? this.isGrowthRole,
        isActive: isActive ?? this.isActive,
        anchoredProblemId: anchoredProblemId ?? this.anchoredProblemId,
        anchoredProblemIndex: anchoredProblemIndex ?? this.anchoredProblemIndex,
        anchoredDemand: anchoredDemand ?? this.anchoredDemand,
        personaName: personaName ?? this.personaName,
        personaBackground: personaBackground ?? this.personaBackground,
        personaCommunicationStyle:
            personaCommunicationStyle ?? this.personaCommunicationStyle,
        personaSignaturePhrase:
            personaSignaturePhrase ?? this.personaSignaturePhrase,
      );

  /// Whether this member has a complete persona.
  bool get hasPersona =>
      personaName != null &&
      personaBackground != null &&
      personaCommunicationStyle != null;

  Map<String, dynamic> toJson() => {
        'roleType': roleType.name,
        'isGrowthRole': isGrowthRole,
        'isActive': isActive,
        'anchoredProblemId': anchoredProblemId,
        'anchoredProblemIndex': anchoredProblemIndex,
        'anchoredDemand': anchoredDemand,
        'personaName': personaName,
        'personaBackground': personaBackground,
        'personaCommunicationStyle': personaCommunicationStyle,
        'personaSignaturePhrase': personaSignaturePhrase,
      };

  factory SetupBoardMember.fromJson(Map<String, dynamic> json) =>
      SetupBoardMember(
        roleType: BoardRoleType.values.firstWhere(
          (r) => r.name == json['roleType'],
          orElse: () => BoardRoleType.accountability,
        ),
        isGrowthRole: json['isGrowthRole'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        anchoredProblemId: json['anchoredProblemId'] as String?,
        anchoredProblemIndex: json['anchoredProblemIndex'] as int?,
        anchoredDemand: json['anchoredDemand'] as String?,
        personaName: json['personaName'] as String?,
        personaBackground: json['personaBackground'] as String?,
        personaCommunicationStyle: json['personaCommunicationStyle'] as String?,
        personaSignaturePhrase: json['personaSignaturePhrase'] as String?,
      );
}

/// Portfolio health metrics calculated from problems.
class SetupPortfolioHealth {
  /// Percentage of time in appreciating problems.
  final int appreciatingPercent;

  /// Percentage of time in depreciating problems.
  final int depreciatingPercent;

  /// Percentage of time in stable problems.
  final int stablePercent;

  /// One sentence describing where user is most exposed.
  final String? riskStatement;

  /// One sentence describing where user is under-investing.
  final String? opportunityStatement;

  const SetupPortfolioHealth({
    this.appreciatingPercent = 0,
    this.depreciatingPercent = 0,
    this.stablePercent = 0,
    this.riskStatement,
    this.opportunityStatement,
  });

  SetupPortfolioHealth copyWith({
    int? appreciatingPercent,
    int? depreciatingPercent,
    int? stablePercent,
    String? riskStatement,
    String? opportunityStatement,
  }) =>
      SetupPortfolioHealth(
        appreciatingPercent: appreciatingPercent ?? this.appreciatingPercent,
        depreciatingPercent: depreciatingPercent ?? this.depreciatingPercent,
        stablePercent: stablePercent ?? this.stablePercent,
        riskStatement: riskStatement ?? this.riskStatement,
        opportunityStatement: opportunityStatement ?? this.opportunityStatement,
      );

  /// Whether there are appreciating problems (for growth roles).
  bool get hasAppreciating => appreciatingPercent > 0;

  Map<String, dynamic> toJson() => {
        'appreciatingPercent': appreciatingPercent,
        'depreciatingPercent': depreciatingPercent,
        'stablePercent': stablePercent,
        'riskStatement': riskStatement,
        'opportunityStatement': opportunityStatement,
      };

  factory SetupPortfolioHealth.fromJson(Map<String, dynamic> json) =>
      SetupPortfolioHealth(
        appreciatingPercent: json['appreciatingPercent'] as int? ?? 0,
        depreciatingPercent: json['depreciatingPercent'] as int? ?? 0,
        stablePercent: json['stablePercent'] as int? ?? 0,
        riskStatement: json['riskStatement'] as String?,
        opportunityStatement: json['opportunityStatement'] as String?,
      );
}

/// Re-setup trigger definition.
class SetupTrigger {
  /// Trigger type.
  final String triggerType;

  /// Human-readable description.
  final String description;

  /// Specific condition to check.
  final String condition;

  /// Recommended action when triggered.
  final String recommendedAction;

  /// Due date for time-based triggers.
  final DateTime? dueAtUtc;

  const SetupTrigger({
    required this.triggerType,
    required this.description,
    required this.condition,
    required this.recommendedAction,
    this.dueAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'triggerType': triggerType,
        'description': description,
        'condition': condition,
        'recommendedAction': recommendedAction,
        'dueAtUtc': dueAtUtc?.toIso8601String(),
      };

  factory SetupTrigger.fromJson(Map<String, dynamic> json) => SetupTrigger(
        triggerType: json['triggerType'] as String,
        description: json['description'] as String,
        condition: json['condition'] as String,
        recommendedAction: json['recommendedAction'] as String,
        dueAtUtc: json['dueAtUtc'] != null
            ? DateTime.parse(json['dueAtUtc'] as String)
            : null,
      );
}

/// The complete session data for a Setup session.
class SetupSessionData {
  /// Current state in the state machine.
  final SetupState currentState;

  /// Whether abstraction mode is enabled.
  final bool abstractionMode;

  /// Problems being collected (0-5).
  final List<SetupProblem> problems;

  /// Currently editing problem index.
  final int currentProblemIndex;

  /// Total time allocation percentage.
  final int totalTimeAllocation;

  /// Time allocation validation status.
  final TimeAllocationStatus? timeAllocationStatus;

  /// Portfolio health metrics.
  final SetupPortfolioHealth? portfolioHealth;

  /// Board members being created.
  final List<SetupBoardMember> boardMembers;

  /// Re-setup triggers.
  final List<SetupTrigger> triggers;

  /// Created problem IDs (after saving to DB).
  final List<String> createdProblemIds;

  /// Created board member IDs (after saving to DB).
  final List<String> createdBoardMemberIds;

  /// Created portfolio version ID.
  final String? portfolioVersionId;

  /// Generated output summary markdown.
  final String? outputMarkdown;

  const SetupSessionData({
    this.currentState = SetupState.initial,
    this.abstractionMode = false,
    this.problems = const [],
    this.currentProblemIndex = 0,
    this.totalTimeAllocation = 0,
    this.timeAllocationStatus,
    this.portfolioHealth,
    this.boardMembers = const [],
    this.triggers = const [],
    this.createdProblemIds = const [],
    this.createdBoardMemberIds = const [],
    this.portfolioVersionId,
    this.outputMarkdown,
  });

  SetupSessionData copyWith({
    SetupState? currentState,
    bool? abstractionMode,
    List<SetupProblem>? problems,
    int? currentProblemIndex,
    int? totalTimeAllocation,
    TimeAllocationStatus? timeAllocationStatus,
    SetupPortfolioHealth? portfolioHealth,
    List<SetupBoardMember>? boardMembers,
    List<SetupTrigger>? triggers,
    List<String>? createdProblemIds,
    List<String>? createdBoardMemberIds,
    String? portfolioVersionId,
    String? outputMarkdown,
  }) =>
      SetupSessionData(
        currentState: currentState ?? this.currentState,
        abstractionMode: abstractionMode ?? this.abstractionMode,
        problems: problems ?? this.problems,
        currentProblemIndex: currentProblemIndex ?? this.currentProblemIndex,
        totalTimeAllocation: totalTimeAllocation ?? this.totalTimeAllocation,
        timeAllocationStatus: timeAllocationStatus ?? this.timeAllocationStatus,
        portfolioHealth: portfolioHealth ?? this.portfolioHealth,
        boardMembers: boardMembers ?? this.boardMembers,
        triggers: triggers ?? this.triggers,
        createdProblemIds: createdProblemIds ?? this.createdProblemIds,
        createdBoardMemberIds:
            createdBoardMemberIds ?? this.createdBoardMemberIds,
        portfolioVersionId: portfolioVersionId ?? this.portfolioVersionId,
        outputMarkdown: outputMarkdown ?? this.outputMarkdown,
      );

  /// Number of problems collected.
  int get problemCount => problems.length;

  /// Whether minimum problems requirement is met (3).
  bool get hasMinimumProblems => problemCount >= 3;

  /// Whether maximum problems reached (5).
  bool get hasMaximumProblems => problemCount >= 5;

  /// Whether user can add more problems.
  bool get canAddMoreProblems => problemCount < 5;

  /// The current problem being edited.
  SetupProblem? get currentProblem =>
      currentProblemIndex < problems.length ? problems[currentProblemIndex] : null;

  /// Core board members.
  List<SetupBoardMember> get coreMembers =>
      boardMembers.where((m) => !m.isGrowthRole).toList();

  /// Growth board members (if any).
  List<SetupBoardMember> get growthMembers =>
      boardMembers.where((m) => m.isGrowthRole).toList();

  /// Whether there are appreciating problems.
  bool get hasAppreciatingProblems =>
      problems.any((p) => p.direction == ProblemDirection.appreciating);

  /// Validates time allocation.
  static TimeAllocationStatus validateTimeAllocation(int total) {
    if (total >= 95 && total <= 105) {
      return TimeAllocationStatus.valid;
    }
    if ((total >= 90 && total < 95) || (total > 105 && total <= 110)) {
      return TimeAllocationStatus.warning;
    }
    return TimeAllocationStatus.error;
  }

  /// Calculates total time allocation from problems.
  int calculateTotalAllocation() {
    return problems.fold(0, (sum, p) => sum + p.timeAllocationPercent);
  }

  Map<String, dynamic> toJson() => {
        'currentState': currentState.name,
        'abstractionMode': abstractionMode,
        'problems': problems.map((p) => p.toJson()).toList(),
        'currentProblemIndex': currentProblemIndex,
        'totalTimeAllocation': totalTimeAllocation,
        'timeAllocationStatus': timeAllocationStatus?.name,
        'portfolioHealth': portfolioHealth?.toJson(),
        'boardMembers': boardMembers.map((m) => m.toJson()).toList(),
        'triggers': triggers.map((t) => t.toJson()).toList(),
        'createdProblemIds': createdProblemIds,
        'createdBoardMemberIds': createdBoardMemberIds,
        'portfolioVersionId': portfolioVersionId,
        'outputMarkdown': outputMarkdown,
      };

  factory SetupSessionData.fromJson(Map<String, dynamic> json) =>
      SetupSessionData(
        currentState: SetupState.values.firstWhere(
          (s) => s.name == json['currentState'],
          orElse: () => SetupState.initial,
        ),
        abstractionMode: json['abstractionMode'] as bool? ?? false,
        problems: (json['problems'] as List<dynamic>?)
                ?.map((e) => SetupProblem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        currentProblemIndex: json['currentProblemIndex'] as int? ?? 0,
        totalTimeAllocation: json['totalTimeAllocation'] as int? ?? 0,
        timeAllocationStatus: json['timeAllocationStatus'] != null
            ? TimeAllocationStatus.values.firstWhere(
                (s) => s.name == json['timeAllocationStatus'],
                orElse: () => TimeAllocationStatus.error,
              )
            : null,
        portfolioHealth: json['portfolioHealth'] != null
            ? SetupPortfolioHealth.fromJson(
                json['portfolioHealth'] as Map<String, dynamic>)
            : null,
        boardMembers: (json['boardMembers'] as List<dynamic>?)
                ?.map(
                    (e) => SetupBoardMember.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        triggers: (json['triggers'] as List<dynamic>?)
                ?.map((e) => SetupTrigger.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdProblemIds: (json['createdProblemIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdBoardMemberIds: (json['createdBoardMemberIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        portfolioVersionId: json['portfolioVersionId'] as String?,
        outputMarkdown: json['outputMarkdown'] as String?,
      );
}
