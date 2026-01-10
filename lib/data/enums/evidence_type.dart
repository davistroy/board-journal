/// Types of evidence ("receipts") that back up claims.
///
/// Per PRD Section 3.2 and Glossary:
/// "Receipts" = concrete evidence that backs up claims.
/// "Receipts over rhetoric" means proving progress with artifacts and actions.
enum EvidenceType {
  /// A decision that was made
  decision,

  /// An artifact that was created (document, code, deliverable)
  artifact,

  /// Calendar entry showing time allocated
  calendar,

  /// Indirect evidence (testimonial, metrics, etc.)
  proxy,

  /// No evidence provided
  none,
}

extension EvidenceTypeExtension on EvidenceType {
  String get displayName {
    switch (this) {
      case EvidenceType.decision:
        return 'Decision Made';
      case EvidenceType.artifact:
        return 'Artifact Created';
      case EvidenceType.calendar:
        return 'Calendar Evidence';
      case EvidenceType.proxy:
        return 'Proxy Evidence';
      case EvidenceType.none:
        return 'No Receipt';
    }
  }

  /// The default strength for this evidence type.
  ///
  /// Per PRD Glossary:
  /// - Decision/Artifact = Strong
  /// - Calendar/Proxy = Medium
  /// - None = None
  EvidenceStrength get defaultStrength {
    switch (this) {
      case EvidenceType.decision:
      case EvidenceType.artifact:
        return EvidenceStrength.strong;
      case EvidenceType.calendar:
      case EvidenceType.proxy:
        return EvidenceStrength.medium;
      case EvidenceType.none:
        return EvidenceStrength.none;
    }
  }
}

/// Strength rating for evidence items.
///
/// Per PRD Section 3.2:
/// - Strong: Decision/Artifact
/// - Medium: Calendar/Proxy
/// - Weak: Calendar-only (explicitly called out)
/// - None: No receipt (recorded as such)
enum EvidenceStrength {
  strong,
  medium,
  weak,
  none,
}

extension EvidenceStrengthExtension on EvidenceStrength {
  String get displayName {
    switch (this) {
      case EvidenceStrength.strong:
        return 'Strong';
      case EvidenceStrength.medium:
        return 'Medium';
      case EvidenceStrength.weak:
        return 'Weak';
      case EvidenceStrength.none:
        return 'None';
    }
  }
}
