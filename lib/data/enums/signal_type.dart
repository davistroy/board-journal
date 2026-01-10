/// Signal types extracted from daily journal entries.
///
/// Per PRD Section 3.1 and Glossary (Section 9):
/// - Wins: Completed accomplishments (done)
/// - Blockers: Current obstacles (now)
/// - Risks: Potential future problems (upcoming)
/// - Avoided Decision: Decisions being put off
/// - Comfort Work: Tasks that feel productive but don't advance goals
/// - Actions: Forward commitments (to do)
/// - Learnings: Realizations and reflections
enum SignalType {
  /// Completed accomplishments
  wins,

  /// Current obstacles
  blockers,

  /// Potential future problems
  risks,

  /// Decisions being put off
  avoidedDecision,

  /// Tasks that feel productive but don't advance goals
  comfortWork,

  /// Forward commitments
  actions,

  /// Realizations and reflections
  learnings,
}

extension SignalTypeExtension on SignalType {
  String get displayName {
    switch (this) {
      case SignalType.wins:
        return 'Wins';
      case SignalType.blockers:
        return 'Blockers';
      case SignalType.risks:
        return 'Risks';
      case SignalType.avoidedDecision:
        return 'Avoided Decision';
      case SignalType.comfortWork:
        return 'Comfort Work';
      case SignalType.actions:
        return 'Actions';
      case SignalType.learnings:
        return 'Learnings/Insights';
    }
  }

  String get description {
    switch (this) {
      case SignalType.wins:
        return 'Completed accomplishments';
      case SignalType.blockers:
        return 'Current obstacles';
      case SignalType.risks:
        return 'Potential future problems';
      case SignalType.avoidedDecision:
        return 'Decisions being put off';
      case SignalType.comfortWork:
        return 'Tasks that feel productive but don\'t advance goals';
      case SignalType.actions:
        return 'Forward commitments';
      case SignalType.learnings:
        return 'Realizations and reflections';
    }
  }
}
