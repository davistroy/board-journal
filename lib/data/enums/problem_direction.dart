/// Direction classification for career problems.
///
/// Per PRD Glossary (Section 9):
/// - Appreciating: Skill becoming MORE valuable over time
/// - Depreciating: Skill becoming LESS valuable over time
/// - Stable: Direction unclear, revisit next quarter
enum ProblemDirection {
  /// Skill/problem area becoming MORE valuable over time.
  ///
  /// Criteria:
  /// - AI can't easily do it (or won't for a while)
  /// - Errors are costly (high stakes)
  /// - Trust/access required (relationship-dependent)
  ///
  /// Examples: strategic decision-making, high-stakes negotiations,
  /// relationship-building.
  appreciating,

  /// Skill/problem area becoming LESS valuable over time.
  ///
  /// Criteria:
  /// - AI is getting better at it
  /// - Errors are low-impact
  /// - No special access/trust needed
  ///
  /// Examples: routine analysis, standardized reporting, data entry.
  depreciating,

  /// Direction unclear - revisit classification next quarter.
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

  String get description {
    switch (this) {
      case ProblemDirection.appreciating:
        return 'Becoming more valuable over time';
      case ProblemDirection.depreciating:
        return 'Becoming less valuable over time';
      case ProblemDirection.stable:
        return 'Direction unclear - revisit next quarter';
    }
  }

  /// Questions to evaluate direction (per PRD Section 4.3).
  static const directionQuestions = [
    'Is AI getting cheaper/better at this?',
    'What is the cost of errors?',
    'Is trust/access required?',
  ];
}
