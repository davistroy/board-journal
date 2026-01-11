import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  // ==========================================
  // BetStatus Tests - MUST-TEST (100% coverage)
  // ==========================================
  group('BetStatus', () {
    group('canTransitionTo', () {
      // Per PRD Section 4.6: Test all 16 possible transitions (4x4 matrix)

      group('from OPEN', () {
        test('OPEN -> OPEN: not allowed', () {
          expect(BetStatus.open.canTransitionTo(BetStatus.open), isFalse);
        });

        test('OPEN -> CORRECT: allowed', () {
          expect(BetStatus.open.canTransitionTo(BetStatus.correct), isTrue);
        });

        test('OPEN -> WRONG: allowed', () {
          expect(BetStatus.open.canTransitionTo(BetStatus.wrong), isTrue);
        });

        test('OPEN -> EXPIRED: allowed', () {
          expect(BetStatus.open.canTransitionTo(BetStatus.expired), isTrue);
        });
      });

      group('from CORRECT', () {
        test('CORRECT -> OPEN: not allowed', () {
          expect(BetStatus.correct.canTransitionTo(BetStatus.open), isFalse);
        });

        test('CORRECT -> CORRECT: not allowed (no change)', () {
          expect(BetStatus.correct.canTransitionTo(BetStatus.correct), isFalse);
        });

        test('CORRECT -> WRONG: not allowed (final state)', () {
          expect(BetStatus.correct.canTransitionTo(BetStatus.wrong), isFalse);
        });

        test('CORRECT -> EXPIRED: not allowed (final state)', () {
          expect(BetStatus.correct.canTransitionTo(BetStatus.expired), isFalse);
        });
      });

      group('from WRONG', () {
        test('WRONG -> OPEN: not allowed', () {
          expect(BetStatus.wrong.canTransitionTo(BetStatus.open), isFalse);
        });

        test('WRONG -> CORRECT: not allowed (final state)', () {
          expect(BetStatus.wrong.canTransitionTo(BetStatus.correct), isFalse);
        });

        test('WRONG -> WRONG: not allowed (no change)', () {
          expect(BetStatus.wrong.canTransitionTo(BetStatus.wrong), isFalse);
        });

        test('WRONG -> EXPIRED: not allowed (final state)', () {
          expect(BetStatus.wrong.canTransitionTo(BetStatus.expired), isFalse);
        });
      });

      group('from EXPIRED', () {
        test('EXPIRED -> OPEN: not allowed', () {
          expect(BetStatus.expired.canTransitionTo(BetStatus.open), isFalse);
        });

        test('EXPIRED -> CORRECT: allowed (retroactive evaluation)', () {
          expect(BetStatus.expired.canTransitionTo(BetStatus.correct), isTrue);
        });

        test('EXPIRED -> WRONG: allowed (retroactive evaluation)', () {
          expect(BetStatus.expired.canTransitionTo(BetStatus.wrong), isTrue);
        });

        test('EXPIRED -> EXPIRED: allowed (no-op but valid)', () {
          expect(BetStatus.expired.canTransitionTo(BetStatus.expired), isTrue);
        });
      });
    });

    group('isEvaluated', () {
      test('OPEN is not evaluated', () {
        expect(BetStatus.open.isEvaluated, isFalse);
      });

      test('CORRECT is evaluated', () {
        expect(BetStatus.correct.isEvaluated, isTrue);
      });

      test('WRONG is evaluated', () {
        expect(BetStatus.wrong.isEvaluated, isTrue);
      });

      test('EXPIRED is not evaluated', () {
        expect(BetStatus.expired.isEvaluated, isFalse);
      });
    });

    group('canEvaluate', () {
      test('OPEN can be evaluated', () {
        expect(BetStatus.open.canEvaluate, isTrue);
      });

      test('CORRECT cannot be evaluated again', () {
        expect(BetStatus.correct.canEvaluate, isFalse);
      });

      test('WRONG cannot be evaluated again', () {
        expect(BetStatus.wrong.canEvaluate, isFalse);
      });

      test('EXPIRED can be evaluated (retroactive)', () {
        expect(BetStatus.expired.canEvaluate, isTrue);
      });
    });

    group('displayName', () {
      test('all statuses have display names', () {
        expect(BetStatus.open.displayName, 'Open');
        expect(BetStatus.correct.displayName, 'Correct');
        expect(BetStatus.wrong.displayName, 'Wrong');
        expect(BetStatus.expired.displayName, 'Expired');
      });
    });
  });

  // ==========================================
  // BoardRoleType Tests
  // ==========================================
  group('BoardRoleType', () {
    group('isCoreRole and isGrowthRole', () {
      test('accountability is core role', () {
        expect(BoardRoleType.accountability.isCoreRole, isTrue);
        expect(BoardRoleType.accountability.isGrowthRole, isFalse);
      });

      test('marketReality is core role', () {
        expect(BoardRoleType.marketReality.isCoreRole, isTrue);
        expect(BoardRoleType.marketReality.isGrowthRole, isFalse);
      });

      test('avoidance is core role', () {
        expect(BoardRoleType.avoidance.isCoreRole, isTrue);
        expect(BoardRoleType.avoidance.isGrowthRole, isFalse);
      });

      test('longTermPositioning is core role', () {
        expect(BoardRoleType.longTermPositioning.isCoreRole, isTrue);
        expect(BoardRoleType.longTermPositioning.isGrowthRole, isFalse);
      });

      test('devilsAdvocate is core role', () {
        expect(BoardRoleType.devilsAdvocate.isCoreRole, isTrue);
        expect(BoardRoleType.devilsAdvocate.isGrowthRole, isFalse);
      });

      test('portfolioDefender is growth role', () {
        expect(BoardRoleType.portfolioDefender.isCoreRole, isFalse);
        expect(BoardRoleType.portfolioDefender.isGrowthRole, isTrue);
      });

      test('opportunityScout is growth role', () {
        expect(BoardRoleType.opportunityScout.isCoreRole, isFalse);
        expect(BoardRoleType.opportunityScout.isGrowthRole, isTrue);
      });
    });

    group('coreRoles static list', () {
      test('contains exactly 5 core roles', () {
        expect(BoardRoleTypeExtension.coreRoles.length, 5);
      });

      test('contains all expected core roles', () {
        final coreRoles = BoardRoleTypeExtension.coreRoles;
        expect(coreRoles, contains(BoardRoleType.accountability));
        expect(coreRoles, contains(BoardRoleType.marketReality));
        expect(coreRoles, contains(BoardRoleType.avoidance));
        expect(coreRoles, contains(BoardRoleType.longTermPositioning));
        expect(coreRoles, contains(BoardRoleType.devilsAdvocate));
      });

      test('does not contain growth roles', () {
        final coreRoles = BoardRoleTypeExtension.coreRoles;
        expect(coreRoles, isNot(contains(BoardRoleType.portfolioDefender)));
        expect(coreRoles, isNot(contains(BoardRoleType.opportunityScout)));
      });
    });

    group('growthRoles static list', () {
      test('contains exactly 2 growth roles', () {
        expect(BoardRoleTypeExtension.growthRoles.length, 2);
      });

      test('contains all expected growth roles', () {
        final growthRoles = BoardRoleTypeExtension.growthRoles;
        expect(growthRoles, contains(BoardRoleType.portfolioDefender));
        expect(growthRoles, contains(BoardRoleType.opportunityScout));
      });
    });

    group('displayName', () {
      test('all roles have display names', () {
        expect(BoardRoleType.accountability.displayName, 'Accountability');
        expect(BoardRoleType.marketReality.displayName, 'Market Reality');
        expect(BoardRoleType.avoidance.displayName, 'Avoidance');
        expect(BoardRoleType.longTermPositioning.displayName, 'Long-term Positioning');
        expect(BoardRoleType.devilsAdvocate.displayName, "Devil's Advocate");
        expect(BoardRoleType.portfolioDefender.displayName, 'Portfolio Defender');
        expect(BoardRoleType.opportunityScout.displayName, 'Opportunity Scout');
      });
    });

    group('function', () {
      test('all roles have function descriptions', () {
        for (final role in BoardRoleType.values) {
          expect(role.function, isNotEmpty);
        }
      });
    });

    group('interactionStyle', () {
      test('all roles have interaction styles', () {
        for (final role in BoardRoleType.values) {
          expect(role.interactionStyle, isNotEmpty);
        }
      });
    });

    group('signatureQuestion', () {
      test('all roles have signature questions', () {
        for (final role in BoardRoleType.values) {
          expect(role.signatureQuestion, isNotEmpty);
          expect(role.signatureQuestion, endsWith('?') | endsWith('.'));
        }
      });

      test('signature questions match PRD specifications', () {
        expect(BoardRoleType.accountability.signatureQuestion, 'Show me the proof.');
        expect(BoardRoleType.marketReality.signatureQuestion, 'Is this actually true?');
        expect(BoardRoleType.avoidance.signatureQuestion, 'Have you actually done this?');
        expect(BoardRoleType.portfolioDefender.signatureQuestion,
            'What would cause you to lose this edge?');
        expect(BoardRoleType.opportunityScout.signatureQuestion,
            'What adjacent skill would 2x this value?');
      });
    });
  });

  // ==========================================
  // SignalType Tests
  // ==========================================
  group('SignalType', () {
    group('displayName', () {
      test('all signal types have display names', () {
        expect(SignalType.wins.displayName, 'Wins');
        expect(SignalType.blockers.displayName, 'Blockers');
        expect(SignalType.risks.displayName, 'Risks');
        expect(SignalType.avoidedDecision.displayName, 'Avoided Decision');
        expect(SignalType.comfortWork.displayName, 'Comfort Work');
        expect(SignalType.actions.displayName, 'Actions');
        expect(SignalType.learnings.displayName, 'Learnings/Insights');
      });
    });

    group('description', () {
      test('all signal types have descriptions', () {
        for (final type in SignalType.values) {
          expect(type.description, isNotEmpty);
        }
      });

      test('descriptions match PRD glossary', () {
        expect(SignalType.wins.description, 'Completed accomplishments');
        expect(SignalType.blockers.description, 'Current obstacles');
        expect(SignalType.risks.description, 'Potential future problems');
        expect(SignalType.avoidedDecision.description, 'Decisions being put off');
        expect(SignalType.actions.description, 'Forward commitments');
        expect(SignalType.learnings.description, 'Realizations and reflections');
      });
    });

    test('exactly 7 signal types per PRD', () {
      expect(SignalType.values.length, 7);
    });
  });

  // ==========================================
  // ProblemDirection Tests
  // ==========================================
  group('ProblemDirection', () {
    group('displayName', () {
      test('all directions have display names', () {
        expect(ProblemDirection.appreciating.displayName, 'Appreciating');
        expect(ProblemDirection.depreciating.displayName, 'Depreciating');
        expect(ProblemDirection.stable.displayName, 'Stable');
      });
    });

    group('description', () {
      test('all directions have descriptions', () {
        for (final direction in ProblemDirection.values) {
          expect(direction.description, isNotEmpty);
        }
      });

      test('descriptions convey value trajectory', () {
        expect(ProblemDirection.appreciating.description,
            contains('more valuable'));
        expect(ProblemDirection.depreciating.description,
            contains('less valuable'));
        expect(ProblemDirection.stable.description,
            contains('unclear'));
      });
    });

    group('directionQuestions', () {
      test('has exactly 3 direction evaluation questions', () {
        expect(ProblemDirectionExtension.directionQuestions.length, 3);
      });

      test('questions match PRD Section 4.3', () {
        final questions = ProblemDirectionExtension.directionQuestions;
        expect(questions, contains('Is AI getting cheaper/better at this?'));
        expect(questions, contains('What is the cost of errors?'));
        expect(questions, contains('Is trust/access required?'));
      });
    });

    test('exactly 3 directions per PRD', () {
      expect(ProblemDirection.values.length, 3);
    });
  });

  // ==========================================
  // EvidenceType Tests (supplement existing tests)
  // ==========================================
  group('EvidenceType', () {
    group('defaultStrength mapping', () {
      test('decision has strong default strength', () {
        expect(EvidenceType.decision.defaultStrength, EvidenceStrength.strong);
      });

      test('artifact has strong default strength', () {
        expect(EvidenceType.artifact.defaultStrength, EvidenceStrength.strong);
      });

      test('calendar has medium default strength', () {
        expect(EvidenceType.calendar.defaultStrength, EvidenceStrength.medium);
      });

      test('proxy has medium default strength', () {
        expect(EvidenceType.proxy.defaultStrength, EvidenceStrength.medium);
      });

      test('none has none default strength', () {
        expect(EvidenceType.none.defaultStrength, EvidenceStrength.none);
      });
    });

    test('exactly 5 evidence types', () {
      expect(EvidenceType.values.length, 5);
    });
  });

  // ==========================================
  // EvidenceStrength Tests
  // ==========================================
  group('EvidenceStrength', () {
    group('displayName', () {
      test('all strengths have display names', () {
        expect(EvidenceStrength.strong.displayName, 'Strong');
        expect(EvidenceStrength.medium.displayName, 'Medium');
        expect(EvidenceStrength.weak.displayName, 'Weak');
        expect(EvidenceStrength.none.displayName, 'None');
      });
    });

    test('exactly 4 evidence strengths', () {
      expect(EvidenceStrength.values.length, 4);
    });
  });
}
