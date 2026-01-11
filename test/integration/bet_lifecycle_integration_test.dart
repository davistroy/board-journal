import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

/// Integration tests for bet lifecycle management.
///
/// Per PRD Section 4.6 (Bet Tracking):
/// - 90-day duration, auto-expire without grace period
/// - Status: OPEN → CORRECT/WRONG/EXPIRED
/// - No "partially correct" - forces clear accountability
/// - Retroactive evaluation allowed for expired bets
void main() {
  late AppDatabase database;
  late BetRepository betRepository;
  late GovernanceSessionRepository sessionRepository;
  late EvidenceItemRepository evidenceRepository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    betRepository = BetRepository(database);
    sessionRepository = GovernanceSessionRepository(database);
    evidenceRepository = EvidenceItemRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Bet Creation', () {
    test('bet created with 90-day due date', () async {
      // Use a small tolerance window for timing
      final beforeCreate = DateTime.now().toUtc().subtract(const Duration(seconds: 1));

      final betId = await betRepository.create(
        prediction: 'Product launch by end of Q2',
        wrongIf: 'Product not in app stores by June 30',
      );

      final afterCreate = DateTime.now().toUtc().add(const Duration(seconds: 1));

      final bet = await betRepository.getById(betId);
      expect(bet, isNotNull);
      expect(bet!.status, 'open');

      // Due date should be approximately 90 days from creation (with tolerance)
      final expectedMin = beforeCreate.add(const Duration(days: 90));
      final expectedMax = afterCreate.add(const Duration(days: 90));

      expect(bet.dueAtUtc.isAfter(expectedMin) || bet.dueAtUtc.isAtSameMomentAs(expectedMin), isTrue);
      expect(bet.dueAtUtc.isBefore(expectedMax) || bet.dueAtUtc.isAtSameMomentAs(expectedMax), isTrue);
    });

    test('bet created from quarterly session has source reference', () async {
      // Create quarterly session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );

      // Create bet from session
      final betId = await betRepository.create(
        prediction: 'Revenue target met',
        wrongIf: 'Revenue below threshold',
        sourceSessionId: sessionId,
      );

      final bet = await betRepository.getById(betId);
      expect(bet!.sourceSessionId, sessionId);
    });
  });

  group('Bet Evaluation', () {
    test('open bet can be evaluated as correct', () async {
      final betId = await betRepository.create(
        prediction: 'Feature shipped',
        wrongIf: 'Feature not deployed',
      );

      final result = await betRepository.evaluate(
        betId,
        newStatus: BetStatus.correct,
        evaluationNotes: 'Feature deployed successfully on schedule',
      );

      expect(result, isTrue);

      final bet = await betRepository.getById(betId);
      expect(bet!.status, 'correct');
      expect(bet.evaluationNotes, contains('deployed successfully'));
      expect(bet.evaluatedAtUtc, isNotNull);
    });

    test('open bet can be evaluated as wrong', () async {
      final betId = await betRepository.create(
        prediction: 'User target reached',
        wrongIf: 'Users below 1000',
      );

      final result = await betRepository.evaluate(
        betId,
        newStatus: BetStatus.wrong,
        evaluationNotes: 'Only reached 800 users',
      );

      expect(result, isTrue);

      final bet = await betRepository.getById(betId);
      expect(bet!.status, 'wrong');
    });

    test('evaluated bet cannot be re-evaluated', () async {
      final betId = await betRepository.create(
        prediction: 'Test',
        wrongIf: 'Test',
      );

      // First evaluation
      await betRepository.evaluate(betId, newStatus: BetStatus.correct);

      // Second evaluation should fail
      final result = await betRepository.evaluate(betId, newStatus: BetStatus.wrong);
      expect(result, isFalse);

      // Status unchanged
      final bet = await betRepository.getById(betId);
      expect(bet!.status, 'correct');
    });

    test('expired bet can be retroactively evaluated', () async {
      // Create bet with past due date
      final now = DateTime.now().toUtc();
      final pastDue = now.subtract(const Duration(days: 1));

      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'expired-bet',
              prediction: 'Expired prediction',
              wrongIf: 'Expired wrong-if',
              status: const Value('expired'),
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: pastDue,
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );

      // Evaluate expired bet
      final result = await betRepository.evaluate(
        'expired-bet',
        newStatus: BetStatus.correct,
        evaluationNotes: 'Retroactive evaluation',
      );

      expect(result, isTrue);

      final bet = await betRepository.getById('expired-bet');
      expect(bet!.status, 'correct');
    });
  });

  group('Bet Expiration', () {
    test('overdue bets auto-expire', () async {
      final now = DateTime.now().toUtc();

      // Create bet with past due date directly
      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'overdue-bet-1',
              prediction: 'Overdue bet 1',
              wrongIf: 'Test',
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: now.subtract(const Duration(days: 1)),
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );

      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'overdue-bet-2',
              prediction: 'Overdue bet 2',
              wrongIf: 'Test',
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: now.subtract(const Duration(days: 2)),
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );

      // Create bet with future due date (should not expire)
      await betRepository.create(
        prediction: 'Future bet',
        wrongIf: 'Test',
      );

      // Expire overdue bets
      final expiredCount = await betRepository.expireOverdueBets();
      expect(expiredCount, 2);

      // Verify expired status
      final bet1 = await betRepository.getById('overdue-bet-1');
      final bet2 = await betRepository.getById('overdue-bet-2');
      expect(bet1!.status, 'expired');
      expect(bet2!.status, 'expired');

      // Future bet should still be open
      final openBets = await betRepository.getOpen();
      expect(openBets.length, 1);
      expect(openBets[0].status, 'open');
    });
  });

  group('Bet Queries', () {
    test('get bets needing evaluation', () async {
      final now = DateTime.now().toUtc();

      // Create expired bet
      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'expired-needs-eval',
              prediction: 'Expired bet',
              wrongIf: 'Test',
              status: const Value('expired'),
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: now.subtract(const Duration(days: 1)),
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );

      // Create bet due within 7 days
      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'due-soon',
              prediction: 'Due soon bet',
              wrongIf: 'Test',
              createdAtUtc: now.subtract(const Duration(days: 85)),
              dueAtUtc: now.add(const Duration(days: 5)),
              updatedAtUtc: now.subtract(const Duration(days: 85)),
            ),
          );

      // Create bet with distant due date (should not be in results)
      await betRepository.create(
        prediction: 'Future bet',
        wrongIf: 'Test',
      );

      final needingEval = await betRepository.getNeedingEvaluation();
      expect(needingEval.length, 2);
      expect(needingEval.any((b) => b.id == 'expired-needs-eval'), isTrue);
      expect(needingEval.any((b) => b.id == 'due-soon'), isTrue);
    });

    test('get bet for quarterly review returns oldest', () async {
      await betRepository.create(
        prediction: 'First bet',
        wrongIf: 'Test',
      );

      await Future.delayed(const Duration(milliseconds: 100));

      await betRepository.create(
        prediction: 'Second bet',
        wrongIf: 'Test',
      );

      final forReview = await betRepository.getBetForQuarterlyReview();
      expect(forReview, isNotNull);
      expect(forReview!.prediction, 'First bet');
    });

    test('evaluation stats calculation', () async {
      // Create and evaluate multiple bets
      final bet1 = await betRepository.create(prediction: 'Bet 1', wrongIf: 'W1');
      final bet2 = await betRepository.create(prediction: 'Bet 2', wrongIf: 'W2');
      final bet3 = await betRepository.create(prediction: 'Bet 3', wrongIf: 'W3');
      await betRepository.create(prediction: 'Bet 4', wrongIf: 'W4'); // Open

      await betRepository.evaluate(bet1, newStatus: BetStatus.correct);
      await betRepository.evaluate(bet2, newStatus: BetStatus.correct);
      await betRepository.evaluate(bet3, newStatus: BetStatus.wrong);

      final stats = await betRepository.getEvaluationStats();
      expect(stats['total'], 4);
      expect(stats['open'], 1);
      expect(stats['correct'], 2);
      expect(stats['wrong'], 1);
      expect(stats['expired'], 0);
    });
  });

  group('Bet with Governance Session', () {
    test('quarterly session links to evaluated and created bets', () async {
      // Create existing bet
      final oldBetId = await betRepository.create(
        prediction: 'Old prediction',
        wrongIf: 'Old wrong-if',
      );

      // Start quarterly session
      final sessionId = await sessionRepository.create(
        sessionType: GovernanceSessionType.quarterly,
        initialState: 'intro',
      );

      // Evaluate old bet in session
      await betRepository.evaluate(
        oldBetId,
        newStatus: BetStatus.correct,
        evaluationSessionId: sessionId,
      );

      // Create new bet in session
      final newBetId = await betRepository.create(
        prediction: 'New prediction',
        wrongIf: 'New wrong-if',
        sourceSessionId: sessionId,
      );

      // Complete session with bet references
      await sessionRepository.complete(
        sessionId,
        outputMarkdown: '# Quarterly',
        evaluatedBetId: oldBetId,
        createdBetId: newBetId,
      );

      // Verify relationships
      final session = await sessionRepository.getById(sessionId);
      expect(session!.evaluatedBetId, oldBetId);
      expect(session.createdBetId, newBetId);

      final oldBet = await betRepository.getById(oldBetId);
      expect(oldBet!.evaluationSessionId, sessionId);

      final newBet = await betRepository.getById(newBetId);
      expect(newBet!.sourceSessionId, sessionId);
    });
  });

  group('Bet State Transitions', () {
    test('valid state transitions', () async {
      // open -> correct: allowed
      final bet1 = await betRepository.create(prediction: 'B1', wrongIf: 'W1');
      expect(await betRepository.evaluate(bet1, newStatus: BetStatus.correct), isTrue);

      // open -> wrong: allowed
      final bet2 = await betRepository.create(prediction: 'B2', wrongIf: 'W2');
      expect(await betRepository.evaluate(bet2, newStatus: BetStatus.wrong), isTrue);

      // expired -> correct: allowed (retroactive)
      final now = DateTime.now().toUtc();
      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'expired-for-transition',
              prediction: 'Expired',
              wrongIf: 'Test',
              status: const Value('expired'),
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: now.subtract(const Duration(days: 1)),
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );
      expect(await betRepository.evaluate('expired-for-transition', newStatus: BetStatus.correct), isTrue);

      // expired -> wrong: allowed (retroactive)
      await database.into(database.bets).insert(
            BetsCompanion.insert(
              id: 'expired-for-transition-2',
              prediction: 'Expired 2',
              wrongIf: 'Test',
              status: const Value('expired'),
              createdAtUtc: now.subtract(const Duration(days: 91)),
              dueAtUtc: now.subtract(const Duration(days: 1)),
              updatedAtUtc: now.subtract(const Duration(days: 91)),
            ),
          );
      expect(await betRepository.evaluate('expired-for-transition-2', newStatus: BetStatus.wrong), isTrue);
    });

    test('invalid state transitions blocked', () async {
      // correct -> wrong: blocked
      final bet1 = await betRepository.create(prediction: 'B1', wrongIf: 'W1');
      await betRepository.evaluate(bet1, newStatus: BetStatus.correct);
      expect(await betRepository.evaluate(bet1, newStatus: BetStatus.wrong), isFalse);

      // wrong -> correct: blocked
      final bet2 = await betRepository.create(prediction: 'B2', wrongIf: 'W2');
      await betRepository.evaluate(bet2, newStatus: BetStatus.wrong);
      expect(await betRepository.evaluate(bet2, newStatus: BetStatus.correct), isFalse);

      // open -> open: not allowed via evaluate
      final bet3 = await betRepository.create(prediction: 'B3', wrongIf: 'W3');
      expect(await betRepository.evaluate(bet3, newStatus: BetStatus.open), isFalse);

      // open -> expired: not allowed via evaluate
      expect(await betRepository.evaluate(bet3, newStatus: BetStatus.expired), isFalse);
    });
  });
}
