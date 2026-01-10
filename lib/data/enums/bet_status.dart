/// Status values for bet tracking.
///
/// Per PRD Section 4.6 (Bet Tracking):
/// - OPEN: Active bet, due date not reached
/// - CORRECT: User verified prediction came true
/// - WRONG: User verified prediction was wrong
/// - EXPIRED: Due date passed without evaluation
///
/// No "partially correct" - forces clear accountability.
enum BetStatus {
  /// Active bet, due date not reached
  open,

  /// User verified prediction came true
  correct,

  /// User verified prediction was wrong
  wrong,

  /// Due date passed without evaluation
  expired,
}

extension BetStatusExtension on BetStatus {
  String get displayName {
    switch (this) {
      case BetStatus.open:
        return 'Open';
      case BetStatus.correct:
        return 'Correct';
      case BetStatus.wrong:
        return 'Wrong';
      case BetStatus.expired:
        return 'Expired';
    }
  }

  /// Whether this status represents a final evaluation
  bool get isEvaluated {
    return this == BetStatus.correct || this == BetStatus.wrong;
  }

  /// Whether the bet can still be evaluated
  bool get canEvaluate {
    return this == BetStatus.open || this == BetStatus.expired;
  }

  /// Returns true if transition to [newStatus] is allowed.
  ///
  /// Per PRD Section 4.6 transition rules:
  /// - OPEN → CORRECT, WRONG, EXPIRED: Yes
  /// - EXPIRED → CORRECT, WRONG: Yes (retroactive evaluation)
  /// - CORRECT ↔ WRONG: No
  /// - Any → OPEN: No
  bool canTransitionTo(BetStatus newStatus) {
    if (newStatus == BetStatus.open) return false;
    if (this == BetStatus.correct || this == BetStatus.wrong) return false;
    return true;
  }
}
