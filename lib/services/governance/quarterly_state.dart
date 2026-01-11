/// Quarterly Report state machine definitions.
///
/// Per PRD Section 4.5:
/// - Full quarterly report with board interrogation
/// - Evidence enforcement with strength labeling
/// - Bet evaluation and creation
/// - Portfolio health trend analysis
/// - Each board member asks one question based on their anchoring

import 'dart:convert';

import '../../data/enums/bet_status.dart';
import '../../data/enums/board_role_type.dart';
import '../../data/enums/evidence_type.dart';
import '../../data/enums/problem_direction.dart';

/// States in the Quarterly Report state machine.
enum QuarterlyState {
  /// Initial state before starting.
  initial,

  /// Privacy reminder with abstraction mode option.
  sensitivityGate,

  /// Gate 0: Check that portfolio, board, and triggers exist.
  gate0Prerequisites,

  /// Warning if <30 days since last report (non-blocking).
  recentReportWarning,

  /// Q1: Evaluate the last bet (CORRECT/WRONG/EXPIRED).
  q1LastBetEvaluation,

  /// Q2: Commitments vs actuals review.
  q2CommitmentsVsActuals,

  /// Vagueness follow-up for Q2.
  q2Clarify,

  /// Q3: What decision have you been avoiding?
  q3AvoidedDecision,

  /// Vagueness follow-up for Q3.
  q3Clarify,

  /// Q4: Where are you doing comfort work?
  q4ComfortWork,

  /// Vagueness follow-up for Q4.
  q4Clarify,

  /// Q5: Portfolio check - direction shifts and allocation changes.
  q5PortfolioCheck,

  /// Vagueness follow-up for Q5.
  q5Clarify,

  /// Q6: Portfolio health update - trend analysis.
  q6PortfolioHealthUpdate,

  /// Q7: Protection check (if growth roles active).
  q7ProtectionCheck,

  /// Vagueness follow-up for Q7.
  q7Clarify,

  /// Q8: Opportunity check (if growth roles active).
  q8OpportunityCheck,

  /// Vagueness follow-up for Q8.
  q8Clarify,

  /// Q9: Re-setup trigger status check.
  q9TriggerCheck,

  /// Q10: Create new bet with wrong-if condition.
  q10NextBet,

  /// Core board interrogation (5 roles, one question each).
  coreBoardInterrogation,

  /// Vagueness follow-up during board interrogation.
  boardInterrogationClarify,

  /// Growth board interrogation (0-2 roles if active).
  growthBoardInterrogation,

  /// Generating final report.
  generateReport,

  /// Session completed with output.
  finalized,

  /// Session abandoned or errored.
  abandoned,
}

/// Extension methods for QuarterlyState.
extension QuarterlyStateExtension on QuarterlyState {
  /// Whether this state is a question state (requires user input).
  bool get isQuestion {
    return this == QuarterlyState.q1LastBetEvaluation ||
        this == QuarterlyState.q2CommitmentsVsActuals ||
        this == QuarterlyState.q3AvoidedDecision ||
        this == QuarterlyState.q4ComfortWork ||
        this == QuarterlyState.q5PortfolioCheck ||
        this == QuarterlyState.q6PortfolioHealthUpdate ||
        this == QuarterlyState.q7ProtectionCheck ||
        this == QuarterlyState.q8OpportunityCheck ||
        this == QuarterlyState.q9TriggerCheck ||
        this == QuarterlyState.q10NextBet ||
        this == QuarterlyState.coreBoardInterrogation ||
        this == QuarterlyState.growthBoardInterrogation;
  }

  /// Whether this state is a clarify state.
  bool get isClarify {
    return this == QuarterlyState.q2Clarify ||
        this == QuarterlyState.q3Clarify ||
        this == QuarterlyState.q4Clarify ||
        this == QuarterlyState.q5Clarify ||
        this == QuarterlyState.q7Clarify ||
        this == QuarterlyState.q8Clarify ||
        this == QuarterlyState.boardInterrogationClarify;
  }

  /// Whether this state requires vagueness checking.
  bool get requiresVaguenessCheck {
    return this == QuarterlyState.q2CommitmentsVsActuals ||
        this == QuarterlyState.q3AvoidedDecision ||
        this == QuarterlyState.q4ComfortWork ||
        this == QuarterlyState.q5PortfolioCheck ||
        this == QuarterlyState.q7ProtectionCheck ||
        this == QuarterlyState.q8OpportunityCheck ||
        this == QuarterlyState.coreBoardInterrogation ||
        this == QuarterlyState.growthBoardInterrogation;
  }

  /// Gets the clarify state for this question state.
  QuarterlyState? get clarifyState {
    switch (this) {
      case QuarterlyState.q2CommitmentsVsActuals:
        return QuarterlyState.q2Clarify;
      case QuarterlyState.q3AvoidedDecision:
        return QuarterlyState.q3Clarify;
      case QuarterlyState.q4ComfortWork:
        return QuarterlyState.q4Clarify;
      case QuarterlyState.q5PortfolioCheck:
        return QuarterlyState.q5Clarify;
      case QuarterlyState.q7ProtectionCheck:
        return QuarterlyState.q7Clarify;
      case QuarterlyState.q8OpportunityCheck:
        return QuarterlyState.q8Clarify;
      case QuarterlyState.coreBoardInterrogation:
      case QuarterlyState.growthBoardInterrogation:
        return QuarterlyState.boardInterrogationClarify;
      default:
        return null;
    }
  }

  /// Gets the parent question state for a clarify state.
  QuarterlyState? get parentQuestionState {
    switch (this) {
      case QuarterlyState.q2Clarify:
        return QuarterlyState.q2CommitmentsVsActuals;
      case QuarterlyState.q3Clarify:
        return QuarterlyState.q3AvoidedDecision;
      case QuarterlyState.q4Clarify:
        return QuarterlyState.q4ComfortWork;
      case QuarterlyState.q5Clarify:
        return QuarterlyState.q5PortfolioCheck;
      case QuarterlyState.q7Clarify:
        return QuarterlyState.q7ProtectionCheck;
      case QuarterlyState.q8Clarify:
        return QuarterlyState.q8OpportunityCheck;
      case QuarterlyState.boardInterrogationClarify:
        return null; // Can be core or growth, determined by context
      default:
        return null;
    }
  }

  /// Gets the next state in the normal flow.
  QuarterlyState get nextState {
    switch (this) {
      case QuarterlyState.initial:
        return QuarterlyState.sensitivityGate;
      case QuarterlyState.sensitivityGate:
        return QuarterlyState.gate0Prerequisites;
      case QuarterlyState.gate0Prerequisites:
        return QuarterlyState.recentReportWarning;
      case QuarterlyState.recentReportWarning:
        return QuarterlyState.q1LastBetEvaluation;
      case QuarterlyState.q1LastBetEvaluation:
        return QuarterlyState.q2CommitmentsVsActuals;
      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        return QuarterlyState.q3AvoidedDecision;
      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        return QuarterlyState.q4ComfortWork;
      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        return QuarterlyState.q5PortfolioCheck;
      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        return QuarterlyState.q6PortfolioHealthUpdate;
      case QuarterlyState.q6PortfolioHealthUpdate:
        return QuarterlyState.q7ProtectionCheck;
      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        return QuarterlyState.q8OpportunityCheck;
      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        return QuarterlyState.q9TriggerCheck;
      case QuarterlyState.q9TriggerCheck:
        return QuarterlyState.q10NextBet;
      case QuarterlyState.q10NextBet:
        return QuarterlyState.coreBoardInterrogation;
      case QuarterlyState.coreBoardInterrogation:
      case QuarterlyState.boardInterrogationClarify:
        return QuarterlyState.growthBoardInterrogation;
      case QuarterlyState.growthBoardInterrogation:
        return QuarterlyState.generateReport;
      case QuarterlyState.generateReport:
        return QuarterlyState.finalized;
      case QuarterlyState.finalized:
      case QuarterlyState.abandoned:
        return this;
      default:
        return QuarterlyState.finalized;
    }
  }

  /// Display name for progress indicator.
  String get displayName {
    switch (this) {
      case QuarterlyState.initial:
        return 'Starting';
      case QuarterlyState.sensitivityGate:
        return 'Privacy Settings';
      case QuarterlyState.gate0Prerequisites:
        return 'Prerequisites Check';
      case QuarterlyState.recentReportWarning:
        return 'Recent Report Warning';
      case QuarterlyState.q1LastBetEvaluation:
        return 'Bet Evaluation';
      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        return 'Commitments Review';
      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        return 'Avoided Decision';
      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        return 'Comfort Work';
      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        return 'Portfolio Check';
      case QuarterlyState.q6PortfolioHealthUpdate:
        return 'Portfolio Health';
      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        return 'Protection Check';
      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        return 'Opportunity Check';
      case QuarterlyState.q9TriggerCheck:
        return 'Trigger Check';
      case QuarterlyState.q10NextBet:
        return 'New Bet';
      case QuarterlyState.coreBoardInterrogation:
      case QuarterlyState.boardInterrogationClarify:
        return 'Core Board Review';
      case QuarterlyState.growthBoardInterrogation:
        return 'Growth Board Review';
      case QuarterlyState.generateReport:
        return 'Generating Report';
      case QuarterlyState.finalized:
        return 'Complete';
      case QuarterlyState.abandoned:
        return 'Abandoned';
    }
  }

  /// Question number (1-10) or 0 if not a numbered question state.
  int get questionNumber {
    switch (this) {
      case QuarterlyState.q1LastBetEvaluation:
        return 1;
      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        return 2;
      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        return 3;
      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        return 4;
      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        return 5;
      case QuarterlyState.q6PortfolioHealthUpdate:
        return 6;
      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        return 7;
      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        return 8;
      case QuarterlyState.q9TriggerCheck:
        return 9;
      case QuarterlyState.q10NextBet:
        return 10;
      default:
        return 0;
    }
  }

  /// Progress percentage (0-100).
  int get progressPercent {
    switch (this) {
      case QuarterlyState.initial:
        return 0;
      case QuarterlyState.sensitivityGate:
        return 2;
      case QuarterlyState.gate0Prerequisites:
        return 4;
      case QuarterlyState.recentReportWarning:
        return 5;
      case QuarterlyState.q1LastBetEvaluation:
        return 8;
      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        return 14;
      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        return 20;
      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        return 26;
      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        return 32;
      case QuarterlyState.q6PortfolioHealthUpdate:
        return 38;
      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        return 44;
      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        return 50;
      case QuarterlyState.q9TriggerCheck:
        return 56;
      case QuarterlyState.q10NextBet:
        return 62;
      case QuarterlyState.coreBoardInterrogation:
      case QuarterlyState.boardInterrogationClarify:
        return 75;
      case QuarterlyState.growthBoardInterrogation:
        return 88;
      case QuarterlyState.generateReport:
        return 95;
      case QuarterlyState.finalized:
        return 100;
      case QuarterlyState.abandoned:
        return 0;
    }
  }
}

/// A single Q&A entry in the quarterly session transcript.
class QuarterlyQA {
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
  final QuarterlyState state;

  /// For board interrogation: which role asked this question.
  final BoardRoleType? roleType;

  /// For board interrogation: the persona name asking.
  final String? personaName;

  const QuarterlyQA({
    required this.question,
    required this.answer,
    this.wasVague = false,
    this.concreteExample,
    this.skipped = false,
    required this.state,
    this.roleType,
    this.personaName,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'wasVague': wasVague,
        'concreteExample': concreteExample,
        'skipped': skipped,
        'state': state.name,
        'roleType': roleType?.name,
        'personaName': personaName,
      };

  factory QuarterlyQA.fromJson(Map<String, dynamic> json) => QuarterlyQA(
        question: json['question'] as String,
        answer: json['answer'] as String,
        wasVague: json['wasVague'] as bool? ?? false,
        concreteExample: json['concreteExample'] as String?,
        skipped: json['skipped'] as bool? ?? false,
        state: QuarterlyState.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => QuarterlyState.initial,
        ),
        roleType: json['roleType'] != null
            ? BoardRoleType.values.firstWhere(
                (r) => r.name == json['roleType'],
                orElse: () => BoardRoleType.accountability,
              )
            : null,
        personaName: json['personaName'] as String?,
      );
}

/// Bet evaluation data.
class BetEvaluation {
  /// ID of the bet being evaluated.
  final String betId;

  /// The bet prediction text.
  final String prediction;

  /// The wrong-if condition.
  final String wrongIf;

  /// Evaluated status.
  final BetStatus status;

  /// User's rationale for the evaluation.
  final String? rationale;

  /// Evidence items supporting the evaluation.
  final List<QuarterlyEvidence> evidence;

  const BetEvaluation({
    required this.betId,
    required this.prediction,
    required this.wrongIf,
    required this.status,
    this.rationale,
    this.evidence = const [],
  });

  BetEvaluation copyWith({
    String? betId,
    String? prediction,
    String? wrongIf,
    BetStatus? status,
    String? rationale,
    List<QuarterlyEvidence>? evidence,
  }) =>
      BetEvaluation(
        betId: betId ?? this.betId,
        prediction: prediction ?? this.prediction,
        wrongIf: wrongIf ?? this.wrongIf,
        status: status ?? this.status,
        rationale: rationale ?? this.rationale,
        evidence: evidence ?? this.evidence,
      );

  Map<String, dynamic> toJson() => {
        'betId': betId,
        'prediction': prediction,
        'wrongIf': wrongIf,
        'status': status.name,
        'rationale': rationale,
        'evidence': evidence.map((e) => e.toJson()).toList(),
      };

  factory BetEvaluation.fromJson(Map<String, dynamic> json) => BetEvaluation(
        betId: json['betId'] as String,
        prediction: json['prediction'] as String,
        wrongIf: json['wrongIf'] as String,
        status: BetStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => BetStatus.open,
        ),
        rationale: json['rationale'] as String?,
        evidence: (json['evidence'] as List<dynamic>?)
                ?.map(
                    (e) => QuarterlyEvidence.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Evidence item for quarterly review.
class QuarterlyEvidence {
  /// Description of the evidence.
  final String description;

  /// Type of evidence.
  final EvidenceType type;

  /// Strength of the evidence.
  final EvidenceStrength strength;

  /// Context where this evidence applies.
  final String? context;

  const QuarterlyEvidence({
    required this.description,
    required this.type,
    required this.strength,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'type': type.name,
        'strength': strength.name,
        'context': context,
      };

  factory QuarterlyEvidence.fromJson(Map<String, dynamic> json) =>
      QuarterlyEvidence(
        description: json['description'] as String,
        type: EvidenceType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => EvidenceType.none,
        ),
        strength: EvidenceStrength.values.firstWhere(
          (s) => s.name == json['strength'],
          orElse: () => EvidenceStrength.none,
        ),
        context: json['context'] as String?,
      );
}

/// Portfolio problem direction update.
class DirectionUpdate {
  /// Problem ID.
  final String problemId;

  /// Problem name.
  final String problemName;

  /// Previous direction.
  final ProblemDirection previousDirection;

  /// New direction.
  final ProblemDirection newDirection;

  /// Rationale for the change.
  final String? rationale;

  const DirectionUpdate({
    required this.problemId,
    required this.problemName,
    required this.previousDirection,
    required this.newDirection,
    this.rationale,
  });

  /// Whether the direction has changed.
  bool get hasChanged => previousDirection != newDirection;

  Map<String, dynamic> toJson() => {
        'problemId': problemId,
        'problemName': problemName,
        'previousDirection': previousDirection.name,
        'newDirection': newDirection.name,
        'rationale': rationale,
      };

  factory DirectionUpdate.fromJson(Map<String, dynamic> json) =>
      DirectionUpdate(
        problemId: json['problemId'] as String,
        problemName: json['problemName'] as String,
        previousDirection: ProblemDirection.values.firstWhere(
          (d) => d.name == json['previousDirection'],
          orElse: () => ProblemDirection.stable,
        ),
        newDirection: ProblemDirection.values.firstWhere(
          (d) => d.name == json['newDirection'],
          orElse: () => ProblemDirection.stable,
        ),
        rationale: json['rationale'] as String?,
      );
}

/// Time allocation update.
class AllocationUpdate {
  /// Problem ID.
  final String problemId;

  /// Problem name.
  final String problemName;

  /// Previous allocation percentage.
  final int previousPercent;

  /// New allocation percentage.
  final int newPercent;

  const AllocationUpdate({
    required this.problemId,
    required this.problemName,
    required this.previousPercent,
    required this.newPercent,
  });

  /// Whether the allocation has changed.
  bool get hasChanged => previousPercent != newPercent;

  /// Change amount.
  int get changeAmount => newPercent - previousPercent;

  Map<String, dynamic> toJson() => {
        'problemId': problemId,
        'problemName': problemName,
        'previousPercent': previousPercent,
        'newPercent': newPercent,
      };

  factory AllocationUpdate.fromJson(Map<String, dynamic> json) =>
      AllocationUpdate(
        problemId: json['problemId'] as String,
        problemName: json['problemName'] as String,
        previousPercent: json['previousPercent'] as int,
        newPercent: json['newPercent'] as int,
      );
}

/// Portfolio health trend data.
class HealthTrend {
  /// Previous appreciating percentage.
  final int previousAppreciating;

  /// Current appreciating percentage.
  final int currentAppreciating;

  /// Previous depreciating percentage.
  final int previousDepreciating;

  /// Current depreciating percentage.
  final int currentDepreciating;

  /// Previous stable percentage.
  final int previousStable;

  /// Current stable percentage.
  final int currentStable;

  /// Trend description.
  final String? trendDescription;

  const HealthTrend({
    required this.previousAppreciating,
    required this.currentAppreciating,
    required this.previousDepreciating,
    required this.currentDepreciating,
    required this.previousStable,
    required this.currentStable,
    this.trendDescription,
  });

  /// Change in appreciating allocation.
  int get appreciatingChange => currentAppreciating - previousAppreciating;

  /// Change in depreciating allocation.
  int get depreciatingChange => currentDepreciating - previousDepreciating;

  /// Change in stable allocation.
  int get stableChange => currentStable - previousStable;

  Map<String, dynamic> toJson() => {
        'previousAppreciating': previousAppreciating,
        'currentAppreciating': currentAppreciating,
        'previousDepreciating': previousDepreciating,
        'currentDepreciating': currentDepreciating,
        'previousStable': previousStable,
        'currentStable': currentStable,
        'trendDescription': trendDescription,
      };

  factory HealthTrend.fromJson(Map<String, dynamic> json) => HealthTrend(
        previousAppreciating: json['previousAppreciating'] as int? ?? 0,
        currentAppreciating: json['currentAppreciating'] as int? ?? 0,
        previousDepreciating: json['previousDepreciating'] as int? ?? 0,
        currentDepreciating: json['currentDepreciating'] as int? ?? 0,
        previousStable: json['previousStable'] as int? ?? 0,
        currentStable: json['currentStable'] as int? ?? 0,
        trendDescription: json['trendDescription'] as String?,
      );
}

/// Trigger status for re-setup check.
class TriggerStatus {
  /// Trigger ID.
  final String triggerId;

  /// Trigger type.
  final String triggerType;

  /// Trigger description.
  final String description;

  /// Whether the trigger condition is met.
  final bool isMet;

  /// Details about why it is/isn't met.
  final String? details;

  const TriggerStatus({
    required this.triggerId,
    required this.triggerType,
    required this.description,
    required this.isMet,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'triggerId': triggerId,
        'triggerType': triggerType,
        'description': description,
        'isMet': isMet,
        'details': details,
      };

  factory TriggerStatus.fromJson(Map<String, dynamic> json) => TriggerStatus(
        triggerId: json['triggerId'] as String,
        triggerType: json['triggerType'] as String,
        description: json['description'] as String,
        isMet: json['isMet'] as bool? ?? false,
        details: json['details'] as String?,
      );
}

/// Board interrogation response.
class BoardInterrogationResponse {
  /// The board member's role type.
  final BoardRoleType roleType;

  /// The persona name.
  final String personaName;

  /// The anchored problem ID.
  final String? anchoredProblemId;

  /// The anchored demand.
  final String? anchoredDemand;

  /// The question asked by the board member.
  final String question;

  /// The user's response.
  final String response;

  /// Whether the response was flagged as vague.
  final bool wasVague;

  /// Concrete example if vague.
  final String? concreteExample;

  /// Whether skipped.
  final bool skipped;

  const BoardInterrogationResponse({
    required this.roleType,
    required this.personaName,
    this.anchoredProblemId,
    this.anchoredDemand,
    required this.question,
    required this.response,
    this.wasVague = false,
    this.concreteExample,
    this.skipped = false,
  });

  BoardInterrogationResponse copyWith({
    BoardRoleType? roleType,
    String? personaName,
    String? anchoredProblemId,
    String? anchoredDemand,
    String? question,
    String? response,
    bool? wasVague,
    String? concreteExample,
    bool? skipped,
  }) =>
      BoardInterrogationResponse(
        roleType: roleType ?? this.roleType,
        personaName: personaName ?? this.personaName,
        anchoredProblemId: anchoredProblemId ?? this.anchoredProblemId,
        anchoredDemand: anchoredDemand ?? this.anchoredDemand,
        question: question ?? this.question,
        response: response ?? this.response,
        wasVague: wasVague ?? this.wasVague,
        concreteExample: concreteExample ?? this.concreteExample,
        skipped: skipped ?? this.skipped,
      );

  Map<String, dynamic> toJson() => {
        'roleType': roleType.name,
        'personaName': personaName,
        'anchoredProblemId': anchoredProblemId,
        'anchoredDemand': anchoredDemand,
        'question': question,
        'response': response,
        'wasVague': wasVague,
        'concreteExample': concreteExample,
        'skipped': skipped,
      };

  factory BoardInterrogationResponse.fromJson(Map<String, dynamic> json) =>
      BoardInterrogationResponse(
        roleType: BoardRoleType.values.firstWhere(
          (r) => r.name == json['roleType'],
          orElse: () => BoardRoleType.accountability,
        ),
        personaName: json['personaName'] as String,
        anchoredProblemId: json['anchoredProblemId'] as String?,
        anchoredDemand: json['anchoredDemand'] as String?,
        question: json['question'] as String,
        response: json['response'] as String,
        wasVague: json['wasVague'] as bool? ?? false,
        concreteExample: json['concreteExample'] as String?,
        skipped: json['skipped'] as bool? ?? false,
      );
}

/// New bet data.
class NewBet {
  /// The prediction.
  final String prediction;

  /// The wrong-if condition.
  final String wrongIf;

  /// Duration in days (default 90).
  final int durationDays;

  const NewBet({
    required this.prediction,
    required this.wrongIf,
    this.durationDays = 90,
  });

  Map<String, dynamic> toJson() => {
        'prediction': prediction,
        'wrongIf': wrongIf,
        'durationDays': durationDays,
      };

  factory NewBet.fromJson(Map<String, dynamic> json) => NewBet(
        prediction: json['prediction'] as String,
        wrongIf: json['wrongIf'] as String,
        durationDays: json['durationDays'] as int? ?? 90,
      );
}

/// The complete session data for a Quarterly Report.
class QuarterlySessionData {
  /// Current state in the state machine.
  final QuarterlyState currentState;

  /// Whether abstraction mode is enabled.
  final bool abstractionMode;

  /// Number of vagueness skips used.
  final int vaguenessSkipCount;

  /// All Q&A entries.
  final List<QuarterlyQA> transcript;

  /// Whether prerequisites check passed.
  final bool prerequisitesPassed;

  /// Whether there was a recent report warning.
  final bool showedRecentWarning;

  /// Days since last report (if warning shown).
  final int? daysSinceLastReport;

  /// Last bet evaluation data.
  final BetEvaluation? betEvaluation;

  /// Commitments vs actuals response.
  final String? commitmentsResponse;

  /// Evidence for commitments.
  final List<QuarterlyEvidence> commitmentsEvidence;

  /// Avoided decision response.
  final String? avoidedDecision;

  /// Comfort work response.
  final String? comfortWork;

  /// Direction updates for problems.
  final List<DirectionUpdate> directionUpdates;

  /// Allocation updates for problems.
  final List<AllocationUpdate> allocationUpdates;

  /// Portfolio health trend.
  final HealthTrend? healthTrend;

  /// Protection check response (if growth roles active).
  final String? protectionResponse;

  /// Opportunity check response (if growth roles active).
  final String? opportunityResponse;

  /// Whether growth roles are active.
  final bool growthRolesActive;

  /// Trigger statuses.
  final List<TriggerStatus> triggerStatuses;

  /// Whether any trigger is met.
  final bool anyTriggerMet;

  /// New bet data.
  final NewBet? newBet;

  /// Core board interrogation responses.
  final List<BoardInterrogationResponse> coreBoardResponses;

  /// Growth board interrogation responses.
  final List<BoardInterrogationResponse> growthBoardResponses;

  /// Current board member index for interrogation.
  final int currentBoardMemberIndex;

  /// Whether currently in board clarification.
  final bool inBoardClarification;

  /// Generated output markdown.
  final String? outputMarkdown;

  /// Created bet ID.
  final String? createdBetId;

  const QuarterlySessionData({
    this.currentState = QuarterlyState.initial,
    this.abstractionMode = false,
    this.vaguenessSkipCount = 0,
    this.transcript = const [],
    this.prerequisitesPassed = false,
    this.showedRecentWarning = false,
    this.daysSinceLastReport,
    this.betEvaluation,
    this.commitmentsResponse,
    this.commitmentsEvidence = const [],
    this.avoidedDecision,
    this.comfortWork,
    this.directionUpdates = const [],
    this.allocationUpdates = const [],
    this.healthTrend,
    this.protectionResponse,
    this.opportunityResponse,
    this.growthRolesActive = false,
    this.triggerStatuses = const [],
    this.anyTriggerMet = false,
    this.newBet,
    this.coreBoardResponses = const [],
    this.growthBoardResponses = const [],
    this.currentBoardMemberIndex = 0,
    this.inBoardClarification = false,
    this.outputMarkdown,
    this.createdBetId,
  });

  QuarterlySessionData copyWith({
    QuarterlyState? currentState,
    bool? abstractionMode,
    int? vaguenessSkipCount,
    List<QuarterlyQA>? transcript,
    bool? prerequisitesPassed,
    bool? showedRecentWarning,
    int? daysSinceLastReport,
    BetEvaluation? betEvaluation,
    String? commitmentsResponse,
    List<QuarterlyEvidence>? commitmentsEvidence,
    String? avoidedDecision,
    String? comfortWork,
    List<DirectionUpdate>? directionUpdates,
    List<AllocationUpdate>? allocationUpdates,
    HealthTrend? healthTrend,
    String? protectionResponse,
    String? opportunityResponse,
    bool? growthRolesActive,
    List<TriggerStatus>? triggerStatuses,
    bool? anyTriggerMet,
    NewBet? newBet,
    List<BoardInterrogationResponse>? coreBoardResponses,
    List<BoardInterrogationResponse>? growthBoardResponses,
    int? currentBoardMemberIndex,
    bool? inBoardClarification,
    String? outputMarkdown,
    String? createdBetId,
  }) =>
      QuarterlySessionData(
        currentState: currentState ?? this.currentState,
        abstractionMode: abstractionMode ?? this.abstractionMode,
        vaguenessSkipCount: vaguenessSkipCount ?? this.vaguenessSkipCount,
        transcript: transcript ?? this.transcript,
        prerequisitesPassed: prerequisitesPassed ?? this.prerequisitesPassed,
        showedRecentWarning: showedRecentWarning ?? this.showedRecentWarning,
        daysSinceLastReport: daysSinceLastReport ?? this.daysSinceLastReport,
        betEvaluation: betEvaluation ?? this.betEvaluation,
        commitmentsResponse: commitmentsResponse ?? this.commitmentsResponse,
        commitmentsEvidence: commitmentsEvidence ?? this.commitmentsEvidence,
        avoidedDecision: avoidedDecision ?? this.avoidedDecision,
        comfortWork: comfortWork ?? this.comfortWork,
        directionUpdates: directionUpdates ?? this.directionUpdates,
        allocationUpdates: allocationUpdates ?? this.allocationUpdates,
        healthTrend: healthTrend ?? this.healthTrend,
        protectionResponse: protectionResponse ?? this.protectionResponse,
        opportunityResponse: opportunityResponse ?? this.opportunityResponse,
        growthRolesActive: growthRolesActive ?? this.growthRolesActive,
        triggerStatuses: triggerStatuses ?? this.triggerStatuses,
        anyTriggerMet: anyTriggerMet ?? this.anyTriggerMet,
        newBet: newBet ?? this.newBet,
        coreBoardResponses: coreBoardResponses ?? this.coreBoardResponses,
        growthBoardResponses: growthBoardResponses ?? this.growthBoardResponses,
        currentBoardMemberIndex:
            currentBoardMemberIndex ?? this.currentBoardMemberIndex,
        inBoardClarification: inBoardClarification ?? this.inBoardClarification,
        outputMarkdown: outputMarkdown ?? this.outputMarkdown,
        createdBetId: createdBetId ?? this.createdBetId,
      );

  /// Whether another skip is allowed.
  bool get canSkip => vaguenessSkipCount < 2;

  /// Whether all core board members have responded.
  bool get allCoreBoardResponded =>
      coreBoardResponses.length >= 5; // 5 core roles

  /// Whether all active growth board members have responded.
  bool get allGrowthBoardResponded {
    if (!growthRolesActive) return true;
    return growthBoardResponses.length >= 2; // 2 growth roles
  }

  Map<String, dynamic> toJson() => {
        'currentState': currentState.name,
        'abstractionMode': abstractionMode,
        'vaguenessSkipCount': vaguenessSkipCount,
        'transcript': transcript.map((qa) => qa.toJson()).toList(),
        'prerequisitesPassed': prerequisitesPassed,
        'showedRecentWarning': showedRecentWarning,
        'daysSinceLastReport': daysSinceLastReport,
        'betEvaluation': betEvaluation?.toJson(),
        'commitmentsResponse': commitmentsResponse,
        'commitmentsEvidence':
            commitmentsEvidence.map((e) => e.toJson()).toList(),
        'avoidedDecision': avoidedDecision,
        'comfortWork': comfortWork,
        'directionUpdates': directionUpdates.map((d) => d.toJson()).toList(),
        'allocationUpdates': allocationUpdates.map((a) => a.toJson()).toList(),
        'healthTrend': healthTrend?.toJson(),
        'protectionResponse': protectionResponse,
        'opportunityResponse': opportunityResponse,
        'growthRolesActive': growthRolesActive,
        'triggerStatuses': triggerStatuses.map((t) => t.toJson()).toList(),
        'anyTriggerMet': anyTriggerMet,
        'newBet': newBet?.toJson(),
        'coreBoardResponses':
            coreBoardResponses.map((r) => r.toJson()).toList(),
        'growthBoardResponses':
            growthBoardResponses.map((r) => r.toJson()).toList(),
        'currentBoardMemberIndex': currentBoardMemberIndex,
        'inBoardClarification': inBoardClarification,
        'outputMarkdown': outputMarkdown,
        'createdBetId': createdBetId,
      };

  factory QuarterlySessionData.fromJson(Map<String, dynamic> json) =>
      QuarterlySessionData(
        currentState: QuarterlyState.values.firstWhere(
          (s) => s.name == json['currentState'],
          orElse: () => QuarterlyState.initial,
        ),
        abstractionMode: json['abstractionMode'] as bool? ?? false,
        vaguenessSkipCount: json['vaguenessSkipCount'] as int? ?? 0,
        transcript: (json['transcript'] as List<dynamic>?)
                ?.map((e) => QuarterlyQA.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        prerequisitesPassed: json['prerequisitesPassed'] as bool? ?? false,
        showedRecentWarning: json['showedRecentWarning'] as bool? ?? false,
        daysSinceLastReport: json['daysSinceLastReport'] as int?,
        betEvaluation: json['betEvaluation'] != null
            ? BetEvaluation.fromJson(
                json['betEvaluation'] as Map<String, dynamic>)
            : null,
        commitmentsResponse: json['commitmentsResponse'] as String?,
        commitmentsEvidence: (json['commitmentsEvidence'] as List<dynamic>?)
                ?.map((e) =>
                    QuarterlyEvidence.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        avoidedDecision: json['avoidedDecision'] as String?,
        comfortWork: json['comfortWork'] as String?,
        directionUpdates: (json['directionUpdates'] as List<dynamic>?)
                ?.map(
                    (e) => DirectionUpdate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        allocationUpdates: (json['allocationUpdates'] as List<dynamic>?)
                ?.map(
                    (e) => AllocationUpdate.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        healthTrend: json['healthTrend'] != null
            ? HealthTrend.fromJson(json['healthTrend'] as Map<String, dynamic>)
            : null,
        protectionResponse: json['protectionResponse'] as String?,
        opportunityResponse: json['opportunityResponse'] as String?,
        growthRolesActive: json['growthRolesActive'] as bool? ?? false,
        triggerStatuses: (json['triggerStatuses'] as List<dynamic>?)
                ?.map((e) => TriggerStatus.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        anyTriggerMet: json['anyTriggerMet'] as bool? ?? false,
        newBet: json['newBet'] != null
            ? NewBet.fromJson(json['newBet'] as Map<String, dynamic>)
            : null,
        coreBoardResponses: (json['coreBoardResponses'] as List<dynamic>?)
                ?.map((e) => BoardInterrogationResponse.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
        growthBoardResponses: (json['growthBoardResponses'] as List<dynamic>?)
                ?.map((e) => BoardInterrogationResponse.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [],
        currentBoardMemberIndex: json['currentBoardMemberIndex'] as int? ?? 0,
        inBoardClarification: json['inBoardClarification'] as bool? ?? false,
        outputMarkdown: json['outputMarkdown'] as String?,
        createdBetId: json['createdBetId'] as String?,
      );
}
