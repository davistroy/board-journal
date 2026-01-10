/// Quick Version (15-min Audit) state machine definitions.
///
/// Per PRD Section 4.3:
/// - 5-question audit with anti-vagueness enforcement
/// - Sensitivity gate first
/// - One question at a time
/// - Vague response triggers concrete example follow-up
/// - Max 2 skips per session

/// States in the Quick Version state machine.
enum QuickVersionState {
  /// Initial state before starting.
  initial,

  /// Privacy reminder with abstraction mode option.
  sensitivityGate,

  /// Q1: What is your current role and context?
  q1RoleContext,

  /// Vagueness follow-up for Q1.
  q1Clarify,

  /// Q2: What are the 3 problems you're paid to solve?
  q2PaidProblems,

  /// Vagueness follow-up for Q2.
  q2Clarify,

  /// Q3: Problem direction evaluation loop.
  /// Iterates through each problem from Q2.
  q3DirectionLoop,

  /// Vagueness follow-up for Q3.
  q3Clarify,

  /// Q4: What decision have you been avoiding?
  q4AvoidedDecision,

  /// Vagueness follow-up for Q4.
  q4Clarify,

  /// Q5: Where are you doing comfort work?
  q5ComfortWork,

  /// Vagueness follow-up for Q5.
  q5Clarify,

  /// Generating final output and bet.
  generateOutput,

  /// Session completed with output.
  finalized,

  /// Session abandoned or errored.
  abandoned,
}

/// Extension methods for QuickVersionState.
extension QuickVersionStateExtension on QuickVersionState {
  /// Whether this state is a question state.
  bool get isQuestion {
    return this == QuickVersionState.q1RoleContext ||
        this == QuickVersionState.q2PaidProblems ||
        this == QuickVersionState.q3DirectionLoop ||
        this == QuickVersionState.q4AvoidedDecision ||
        this == QuickVersionState.q5ComfortWork;
  }

  /// Whether this state is a clarify state.
  bool get isClarify {
    return this == QuickVersionState.q1Clarify ||
        this == QuickVersionState.q2Clarify ||
        this == QuickVersionState.q3Clarify ||
        this == QuickVersionState.q4Clarify ||
        this == QuickVersionState.q5Clarify;
  }

  /// Gets the clarify state for this question state.
  QuickVersionState? get clarifyState {
    switch (this) {
      case QuickVersionState.q1RoleContext:
        return QuickVersionState.q1Clarify;
      case QuickVersionState.q2PaidProblems:
        return QuickVersionState.q2Clarify;
      case QuickVersionState.q3DirectionLoop:
        return QuickVersionState.q3Clarify;
      case QuickVersionState.q4AvoidedDecision:
        return QuickVersionState.q4Clarify;
      case QuickVersionState.q5ComfortWork:
        return QuickVersionState.q5Clarify;
      default:
        return null;
    }
  }

  /// Gets the parent question state for a clarify state.
  QuickVersionState? get parentQuestionState {
    switch (this) {
      case QuickVersionState.q1Clarify:
        return QuickVersionState.q1RoleContext;
      case QuickVersionState.q2Clarify:
        return QuickVersionState.q2PaidProblems;
      case QuickVersionState.q3Clarify:
        return QuickVersionState.q3DirectionLoop;
      case QuickVersionState.q4Clarify:
        return QuickVersionState.q4AvoidedDecision;
      case QuickVersionState.q5Clarify:
        return QuickVersionState.q5ComfortWork;
      default:
        return null;
    }
  }

  /// Gets the next state after answering this question.
  QuickVersionState get nextState {
    switch (this) {
      case QuickVersionState.initial:
        return QuickVersionState.sensitivityGate;
      case QuickVersionState.sensitivityGate:
        return QuickVersionState.q1RoleContext;
      case QuickVersionState.q1RoleContext:
      case QuickVersionState.q1Clarify:
        return QuickVersionState.q2PaidProblems;
      case QuickVersionState.q2PaidProblems:
      case QuickVersionState.q2Clarify:
        return QuickVersionState.q3DirectionLoop;
      case QuickVersionState.q3DirectionLoop:
      case QuickVersionState.q3Clarify:
        return QuickVersionState.q4AvoidedDecision;
      case QuickVersionState.q4AvoidedDecision:
      case QuickVersionState.q4Clarify:
        return QuickVersionState.q5ComfortWork;
      case QuickVersionState.q5ComfortWork:
      case QuickVersionState.q5Clarify:
        return QuickVersionState.generateOutput;
      case QuickVersionState.generateOutput:
        return QuickVersionState.finalized;
      case QuickVersionState.finalized:
      case QuickVersionState.abandoned:
        return this;
    }
  }

  /// Display name for progress indicator.
  String get displayName {
    switch (this) {
      case QuickVersionState.initial:
        return 'Starting';
      case QuickVersionState.sensitivityGate:
        return 'Privacy Settings';
      case QuickVersionState.q1RoleContext:
      case QuickVersionState.q1Clarify:
        return 'Role Context';
      case QuickVersionState.q2PaidProblems:
      case QuickVersionState.q2Clarify:
        return 'Paid Problems';
      case QuickVersionState.q3DirectionLoop:
      case QuickVersionState.q3Clarify:
        return 'Problem Directions';
      case QuickVersionState.q4AvoidedDecision:
      case QuickVersionState.q4Clarify:
        return 'Avoided Decision';
      case QuickVersionState.q5ComfortWork:
      case QuickVersionState.q5Clarify:
        return 'Comfort Work';
      case QuickVersionState.generateOutput:
        return 'Generating Output';
      case QuickVersionState.finalized:
        return 'Complete';
      case QuickVersionState.abandoned:
        return 'Abandoned';
    }
  }

  /// Question number (1-5) or 0 if not a question state.
  int get questionNumber {
    switch (this) {
      case QuickVersionState.q1RoleContext:
      case QuickVersionState.q1Clarify:
        return 1;
      case QuickVersionState.q2PaidProblems:
      case QuickVersionState.q2Clarify:
        return 2;
      case QuickVersionState.q3DirectionLoop:
      case QuickVersionState.q3Clarify:
        return 3;
      case QuickVersionState.q4AvoidedDecision:
      case QuickVersionState.q4Clarify:
        return 4;
      case QuickVersionState.q5ComfortWork:
      case QuickVersionState.q5Clarify:
        return 5;
      default:
        return 0;
    }
  }

  /// Progress percentage (0-100).
  int get progressPercent {
    switch (this) {
      case QuickVersionState.initial:
        return 0;
      case QuickVersionState.sensitivityGate:
        return 5;
      case QuickVersionState.q1RoleContext:
      case QuickVersionState.q1Clarify:
        return 15;
      case QuickVersionState.q2PaidProblems:
      case QuickVersionState.q2Clarify:
        return 30;
      case QuickVersionState.q3DirectionLoop:
      case QuickVersionState.q3Clarify:
        return 50;
      case QuickVersionState.q4AvoidedDecision:
      case QuickVersionState.q4Clarify:
        return 70;
      case QuickVersionState.q5ComfortWork:
      case QuickVersionState.q5Clarify:
        return 85;
      case QuickVersionState.generateOutput:
        return 95;
      case QuickVersionState.finalized:
        return 100;
      case QuickVersionState.abandoned:
        return 0;
    }
  }
}

/// A single Q&A entry in the session transcript.
class QuickVersionQA {
  /// The question asked.
  final String question;

  /// The user's answer.
  final String answer;

  /// Whether the answer was flagged as vague.
  final bool wasVague;

  /// The concrete example provided (if wasVague).
  final String? concreteExample;

  /// Whether the user skipped providing an example.
  final bool skipped;

  /// The state this Q&A belongs to.
  final QuickVersionState state;

  /// For Q3 direction loop: which problem index (0-2).
  final int? problemIndex;

  const QuickVersionQA({
    required this.question,
    required this.answer,
    this.wasVague = false,
    this.concreteExample,
    this.skipped = false,
    required this.state,
    this.problemIndex,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'wasVague': wasVague,
        'concreteExample': concreteExample,
        'skipped': skipped,
        'state': state.name,
        'problemIndex': problemIndex,
      };

  factory QuickVersionQA.fromJson(Map<String, dynamic> json) => QuickVersionQA(
        question: json['question'] as String,
        answer: json['answer'] as String,
        wasVague: json['wasVague'] as bool? ?? false,
        concreteExample: json['concreteExample'] as String?,
        skipped: json['skipped'] as bool? ?? false,
        state: QuickVersionState.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => QuickVersionState.initial,
        ),
        problemIndex: json['problemIndex'] as int?,
      );
}

/// A problem identified in Q2 with its direction evaluation from Q3.
class IdentifiedProblem {
  /// The problem name/description.
  final String name;

  /// User's answer to "Is AI getting cheaper at this?"
  final String? aiCheaper;

  /// User's answer to "What's the cost of errors?"
  final String? errorCost;

  /// User's answer to "Is trust/access required?"
  final String? trustRequired;

  /// Evaluated direction: Appreciating, Depreciating, or Stable.
  final ProblemDirection? direction;

  /// One-sentence rationale for the direction.
  final String? directionRationale;

  const IdentifiedProblem({
    required this.name,
    this.aiCheaper,
    this.errorCost,
    this.trustRequired,
    this.direction,
    this.directionRationale,
  });

  IdentifiedProblem copyWith({
    String? name,
    String? aiCheaper,
    String? errorCost,
    String? trustRequired,
    ProblemDirection? direction,
    String? directionRationale,
  }) =>
      IdentifiedProblem(
        name: name ?? this.name,
        aiCheaper: aiCheaper ?? this.aiCheaper,
        errorCost: errorCost ?? this.errorCost,
        trustRequired: trustRequired ?? this.trustRequired,
        direction: direction ?? this.direction,
        directionRationale: directionRationale ?? this.directionRationale,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'aiCheaper': aiCheaper,
        'errorCost': errorCost,
        'trustRequired': trustRequired,
        'direction': direction?.name,
        'directionRationale': directionRationale,
      };

  factory IdentifiedProblem.fromJson(Map<String, dynamic> json) =>
      IdentifiedProblem(
        name: json['name'] as String,
        aiCheaper: json['aiCheaper'] as String?,
        errorCost: json['errorCost'] as String?,
        trustRequired: json['trustRequired'] as String?,
        direction: json['direction'] != null
            ? ProblemDirection.values.firstWhere(
                (d) => d.name == json['direction'],
                orElse: () => ProblemDirection.stable,
              )
            : null,
        directionRationale: json['directionRationale'] as String?,
      );

  /// Whether the direction evaluation is complete.
  bool get hasDirection =>
      aiCheaper != null &&
      errorCost != null &&
      trustRequired != null &&
      direction != null;
}

/// Problem direction classification.
enum ProblemDirection {
  /// Skill/problem becoming more valuable.
  appreciating,

  /// Skill/problem becoming less valuable.
  depreciating,

  /// Direction unclear, revisit next quarter.
  stable,
}

extension ProblemDirectionExtension on ProblemDirection {
  String get displayName {
    switch (this) {
      case ProblemDirection.appreciating:
        return 'Appreciating';
      case ProblemDirection.depreciating:
        return 'Depreciating';
      case ProblemDirection.stable:
        return 'Stable';
    }
  }
}

/// The complete session data for a Quick Version audit.
class QuickVersionSessionData {
  /// Current state in the state machine.
  final QuickVersionState currentState;

  /// Whether abstraction mode is enabled.
  final bool abstractionMode;

  /// Number of vagueness skips used.
  final int vaguenessSkipCount;

  /// All Q&A entries.
  final List<QuickVersionQA> transcript;

  /// Role context from Q1.
  final String? roleContext;

  /// Problems identified in Q2.
  final List<IdentifiedProblem> problems;

  /// Current problem index for Q3 loop.
  final int currentProblemIndex;

  /// Current sub-question in Q3 (0=AI, 1=error, 2=trust).
  final int currentDirectionSubQuestion;

  /// Avoided decision from Q4.
  final String? avoidedDecision;

  /// Cost of avoiding from Q4.
  final String? avoidedDecisionCost;

  /// Comfort work from Q5.
  final String? comfortWork;

  /// Generated output markdown.
  final String? outputMarkdown;

  /// Generated bet prediction.
  final String? betPrediction;

  /// Generated bet wrong-if condition.
  final String? betWrongIf;

  /// Two-sentence honest assessment.
  final String? assessment;

  const QuickVersionSessionData({
    this.currentState = QuickVersionState.initial,
    this.abstractionMode = false,
    this.vaguenessSkipCount = 0,
    this.transcript = const [],
    this.roleContext,
    this.problems = const [],
    this.currentProblemIndex = 0,
    this.currentDirectionSubQuestion = 0,
    this.avoidedDecision,
    this.avoidedDecisionCost,
    this.comfortWork,
    this.outputMarkdown,
    this.betPrediction,
    this.betWrongIf,
    this.assessment,
  });

  QuickVersionSessionData copyWith({
    QuickVersionState? currentState,
    bool? abstractionMode,
    int? vaguenessSkipCount,
    List<QuickVersionQA>? transcript,
    String? roleContext,
    List<IdentifiedProblem>? problems,
    int? currentProblemIndex,
    int? currentDirectionSubQuestion,
    String? avoidedDecision,
    String? avoidedDecisionCost,
    String? comfortWork,
    String? outputMarkdown,
    String? betPrediction,
    String? betWrongIf,
    String? assessment,
  }) =>
      QuickVersionSessionData(
        currentState: currentState ?? this.currentState,
        abstractionMode: abstractionMode ?? this.abstractionMode,
        vaguenessSkipCount: vaguenessSkipCount ?? this.vaguenessSkipCount,
        transcript: transcript ?? this.transcript,
        roleContext: roleContext ?? this.roleContext,
        problems: problems ?? this.problems,
        currentProblemIndex: currentProblemIndex ?? this.currentProblemIndex,
        currentDirectionSubQuestion:
            currentDirectionSubQuestion ?? this.currentDirectionSubQuestion,
        avoidedDecision: avoidedDecision ?? this.avoidedDecision,
        avoidedDecisionCost: avoidedDecisionCost ?? this.avoidedDecisionCost,
        comfortWork: comfortWork ?? this.comfortWork,
        outputMarkdown: outputMarkdown ?? this.outputMarkdown,
        betPrediction: betPrediction ?? this.betPrediction,
        betWrongIf: betWrongIf ?? this.betWrongIf,
        assessment: assessment ?? this.assessment,
      );

  /// Whether another skip is allowed.
  bool get canSkip => vaguenessSkipCount < 2;

  /// Whether all problems have been evaluated.
  bool get allProblemsEvaluated =>
      problems.isNotEmpty && problems.every((p) => p.hasDirection);

  /// The current problem being evaluated in Q3.
  IdentifiedProblem? get currentProblem =>
      currentProblemIndex < problems.length
          ? problems[currentProblemIndex]
          : null;

  Map<String, dynamic> toJson() => {
        'currentState': currentState.name,
        'abstractionMode': abstractionMode,
        'vaguenessSkipCount': vaguenessSkipCount,
        'transcript': transcript.map((qa) => qa.toJson()).toList(),
        'roleContext': roleContext,
        'problems': problems.map((p) => p.toJson()).toList(),
        'currentProblemIndex': currentProblemIndex,
        'currentDirectionSubQuestion': currentDirectionSubQuestion,
        'avoidedDecision': avoidedDecision,
        'avoidedDecisionCost': avoidedDecisionCost,
        'comfortWork': comfortWork,
        'outputMarkdown': outputMarkdown,
        'betPrediction': betPrediction,
        'betWrongIf': betWrongIf,
        'assessment': assessment,
      };

  factory QuickVersionSessionData.fromJson(Map<String, dynamic> json) =>
      QuickVersionSessionData(
        currentState: QuickVersionState.values.firstWhere(
          (s) => s.name == json['currentState'],
          orElse: () => QuickVersionState.initial,
        ),
        abstractionMode: json['abstractionMode'] as bool? ?? false,
        vaguenessSkipCount: json['vaguenessSkipCount'] as int? ?? 0,
        transcript: (json['transcript'] as List<dynamic>?)
                ?.map((e) => QuickVersionQA.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        roleContext: json['roleContext'] as String?,
        problems: (json['problems'] as List<dynamic>?)
                ?.map(
                    (e) => IdentifiedProblem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        currentProblemIndex: json['currentProblemIndex'] as int? ?? 0,
        currentDirectionSubQuestion:
            json['currentDirectionSubQuestion'] as int? ?? 0,
        avoidedDecision: json['avoidedDecision'] as String?,
        avoidedDecisionCost: json['avoidedDecisionCost'] as String?,
        comfortWork: json['comfortWork'] as String?,
        outputMarkdown: json['outputMarkdown'] as String?,
        betPrediction: json['betPrediction'] as String?,
        betWrongIf: json['betWrongIf'] as String?,
        assessment: json['assessment'] as String?,
      );
}
