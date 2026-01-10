/// Types of governance sessions.
///
/// Per PRD Section 3.1 and Section 4:
/// - Quick: 15-minute audit (5 questions)
/// - Setup: Portfolio + Board Roles + Personas creation
/// - Quarterly: Full quarterly report with board interrogation
enum GovernanceSessionType {
  /// 15-minute audit with 5 questions.
  /// Per PRD Section 4.3.
  quick,

  /// Portfolio + Board Roles + Personas setup.
  /// Per PRD Section 4.4.
  setup,

  /// Quarterly report with full board interrogation.
  /// Per PRD Section 4.5.
  quarterly,
}

extension GovernanceSessionTypeExtension on GovernanceSessionType {
  String get displayName {
    switch (this) {
      case GovernanceSessionType.quick:
        return 'Quick Version';
      case GovernanceSessionType.setup:
        return 'Setup';
      case GovernanceSessionType.quarterly:
        return 'Quarterly Report';
    }
  }

  String get description {
    switch (this) {
      case GovernanceSessionType.quick:
        return '15-minute audit';
      case GovernanceSessionType.setup:
        return 'Problem Portfolio + Board Roles + Personas';
      case GovernanceSessionType.quarterly:
        return 'Full quarterly review with board interrogation';
    }
  }

  /// Whether this session type requires a portfolio to exist.
  bool get requiresPortfolio {
    return this == GovernanceSessionType.quarterly;
  }

  /// Estimated duration in minutes.
  int get estimatedMinutes {
    switch (this) {
      case GovernanceSessionType.quick:
        return 15;
      case GovernanceSessionType.setup:
        return 30;
      case GovernanceSessionType.quarterly:
        return 45;
    }
  }
}
