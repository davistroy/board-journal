/// Types of board roles in the governance system.
///
/// Per PRD Section 3.3:
/// - 5 core roles (always active)
/// - 2 growth roles (activated when appreciating problems exist)
enum BoardRoleType {
  // ==================
  // Core Roles (Always Active)
  // ==================

  /// Demands receipts for stated commitments.
  /// Interaction: Direct, evidence-focused. Asks "Show me the proof."
  accountability,

  /// Challenges direction classifications.
  /// Interaction: Skeptical, data-driven. Asks "Is this actually true?"
  marketReality,

  /// Probes avoided decisions.
  /// Interaction: Persistent, uncomfortable. Asks "Have you actually done this?"
  avoidance,

  /// Asks 5-year strategic questions.
  /// Interaction: Forward-looking, strategic. Asks "What are you doing to own more of this?"
  longTermPositioning,

  /// Argues against the user's path.
  /// Interaction: Contrarian, challenging. Asks "What if you're wrong about this?"
  devilsAdvocate,

  // ==================
  // Growth Roles (Anchor to Appreciating Problems)
  // ==================

  /// Protects and compounds strengths.
  /// Interaction: Protective, growth-focused. Asks "What would cause you to lose this edge?"
  portfolioDefender,

  /// Identifies adjacent opportunities.
  /// Interaction: Exploratory, curious. Asks "What adjacent skill would 2x this value?"
  opportunityScout,
}

extension BoardRoleTypeExtension on BoardRoleType {
  String get displayName {
    switch (this) {
      case BoardRoleType.accountability:
        return 'Accountability';
      case BoardRoleType.marketReality:
        return 'Market Reality';
      case BoardRoleType.avoidance:
        return 'Avoidance';
      case BoardRoleType.longTermPositioning:
        return 'Long-term Positioning';
      case BoardRoleType.devilsAdvocate:
        return "Devil's Advocate";
      case BoardRoleType.portfolioDefender:
        return 'Portfolio Defender';
      case BoardRoleType.opportunityScout:
        return 'Opportunity Scout';
    }
  }

  /// The function/purpose of this role.
  String get function {
    switch (this) {
      case BoardRoleType.accountability:
        return 'Demands receipts for stated commitments';
      case BoardRoleType.marketReality:
        return 'Challenges direction classifications';
      case BoardRoleType.avoidance:
        return 'Probes avoided decisions';
      case BoardRoleType.longTermPositioning:
        return 'Asks 5-year strategic questions';
      case BoardRoleType.devilsAdvocate:
        return "Argues against the user's path";
      case BoardRoleType.portfolioDefender:
        return 'Protects and compounds strengths';
      case BoardRoleType.opportunityScout:
        return 'Identifies adjacent opportunities';
    }
  }

  /// The interaction style of this role.
  String get interactionStyle {
    switch (this) {
      case BoardRoleType.accountability:
        return 'Direct, evidence-focused';
      case BoardRoleType.marketReality:
        return 'Skeptical, data-driven';
      case BoardRoleType.avoidance:
        return 'Persistent, uncomfortable';
      case BoardRoleType.longTermPositioning:
        return 'Forward-looking, strategic';
      case BoardRoleType.devilsAdvocate:
        return 'Contrarian, challenging';
      case BoardRoleType.portfolioDefender:
        return 'Protective, growth-focused';
      case BoardRoleType.opportunityScout:
        return 'Exploratory, curious';
    }
  }

  /// The signature question this role asks.
  String get signatureQuestion {
    switch (this) {
      case BoardRoleType.accountability:
        return 'Show me the proof.';
      case BoardRoleType.marketReality:
        return 'Is this actually true?';
      case BoardRoleType.avoidance:
        return 'Have you actually done this?';
      case BoardRoleType.longTermPositioning:
        return 'What are you doing to own more of this?';
      case BoardRoleType.devilsAdvocate:
        return 'What if you\'re wrong about this?';
      case BoardRoleType.portfolioDefender:
        return 'What would cause you to lose this edge?';
      case BoardRoleType.opportunityScout:
        return 'What adjacent skill would 2x this value?';
    }
  }

  /// Whether this is a growth role (requires appreciating problems).
  bool get isGrowthRole {
    return this == BoardRoleType.portfolioDefender ||
        this == BoardRoleType.opportunityScout;
  }

  /// Whether this is a core role (always active).
  bool get isCoreRole => !isGrowthRole;

  /// All core roles (always active).
  static List<BoardRoleType> get coreRoles => [
        BoardRoleType.accountability,
        BoardRoleType.marketReality,
        BoardRoleType.avoidance,
        BoardRoleType.longTermPositioning,
        BoardRoleType.devilsAdvocate,
      ];

  /// All growth roles (require appreciating problems).
  static List<BoardRoleType> get growthRoles => [
        BoardRoleType.portfolioDefender,
        BoardRoleType.opportunityScout,
      ];
}
