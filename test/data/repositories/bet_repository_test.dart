import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late BetRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BetRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('BetRepository', () {
    group('create', () {
      test('creates a bet with 90-day due date', () async {
        final beforeCreate = DateTime.now().toUtc();

        final id = await repository.create(
          prediction: 'I will complete the MVP',
          wrongIf: 'No working prototype exists',
        );

        final afterCreate = DateTime.now().toUtc();

        final bet = await repository.getById(id);
        expect(bet, isNotNull);
        expect(bet!.prediction, 'I will complete the MVP');
        expect(bet.wrongIf, 'No working prototype exists');
        expect(bet.status, 'open');

        // Due date should be ~90 days from creation
        final expectedDueDate = beforeCreate.add(const Duration(days: 90));
        expect(
          bet.dueAtUtc.difference(expectedDueDate).inHours.abs(),
          lessThan(1),
        );
      });

      test('stores source session ID', () async {
        final id = await repository.create(
          prediction: 'Test prediction',
          wrongIf: 'Test wrong-if',
          sourceSessionId: 'session-123',
        );

        final bet = await repository.getById(id);
        expect(bet!.sourceSessionId, 'session-123');
      });
    });

    group('getByStatus', () {
      test('returns bets filtered by status', () async {
        // Create two bets
        await repository.create(
          prediction: 'Open bet',
          wrongIf: 'Wrong if 1',
        );

        final bet2Id = await repository.create(
          prediction: 'Another bet',
          wrongIf: 'Wrong if 2',
        );

        // Evaluate one as correct
        await repository.evaluate(bet2Id, newStatus: BetStatus.correct);

        final openBets = await repository.getByStatus(BetStatus.open);
        expect(openBets.length, 1);
        expect(openBets[0].prediction, 'Open bet');

        final correctBets = await repository.getByStatus(BetStatus.correct);
        expect(correctBets.length, 1);
        expect(correctBets[0].prediction, 'Another bet');
      });
    });

    group('evaluate', () {
      test('evaluates open bet as correct', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        final result = await repository.evaluate(
          id,
          newStatus: BetStatus.correct,
          evaluationNotes: 'Prediction came true!',
          evaluationSessionId: 'quarterly-session-1',
        );

        expect(result, isTrue);

        final bet = await repository.getById(id);
        expect(bet!.status, 'correct');
        expect(bet.evaluationNotes, 'Prediction came true!');
        expect(bet.evaluationSessionId, 'quarterly-session-1');
        expect(bet.evaluatedAtUtc, isNotNull);
      });

      test('evaluates open bet as wrong', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        final result = await repository.evaluate(id, newStatus: BetStatus.wrong);

        expect(result, isTrue);

        final bet = await repository.getById(id);
        expect(bet!.status, 'wrong');
      });

      test('rejects evaluation to open status', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        final result = await repository.evaluate(id, newStatus: BetStatus.open);
        expect(result, isFalse);
      });

      test('rejects evaluation to expired status', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        final result = await repository.evaluate(id, newStatus: BetStatus.expired);
        expect(result, isFalse);
      });

      test('rejects re-evaluation of correct bet', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.evaluate(id, newStatus: BetStatus.correct);
        final result = await repository.evaluate(id, newStatus: BetStatus.wrong);

        expect(result, isFalse);

        final bet = await repository.getById(id);
        expect(bet!.status, 'correct'); // Unchanged
      });

      test('rejects re-evaluation of wrong bet', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.evaluate(id, newStatus: BetStatus.wrong);
        final result = await repository.evaluate(id, newStatus: BetStatus.correct);

        expect(result, isFalse);

        final bet = await repository.getById(id);
        expect(bet!.status, 'wrong'); // Unchanged
      });

      test('allows evaluation of expired bet (retroactive)', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        // Manually expire the bet
        await (database.update(database.bets)..where((b) => b.id.equals(id)))
            .write(const BetsCompanion(status: Value('expired')));

        final result = await repository.evaluate(id, newStatus: BetStatus.correct);

        expect(result, isTrue);

        final bet = await repository.getById(id);
        expect(bet!.status, 'correct');
      });
    });

    group('expireOverdueBets', () {
      test('expires bets past due date', () async {
        // Create bet with past due date directly in DB
        final id = 'test-bet-id';
        final now = DateTime.now().toUtc();
        final pastDue = now.subtract(const Duration(days: 1));

        await database.into(database.bets).insert(
              BetsCompanion.insert(
                id: id,
                prediction: 'Overdue bet',
                wrongIf: 'Test',
                createdAtUtc: now.subtract(const Duration(days: 91)),
                dueAtUtc: pastDue,
                updatedAtUtc: now.subtract(const Duration(days: 91)),
              ),
            );

        final expiredCount = await repository.expireOverdueBets();
        expect(expiredCount, 1);

        final bet = await repository.getById(id);
        expect(bet!.status, 'expired');
      });

      test('does not expire bets still open with future due date', () async {
        await repository.create(
          prediction: 'Future bet',
          wrongIf: 'Test',
        );

        final expiredCount = await repository.expireOverdueBets();
        expect(expiredCount, 0);

        final bets = await repository.getOpen();
        expect(bets.length, 1);
        expect(bets[0].status, 'open');
      });
    });

    group('getNeedingEvaluation', () {
      test('returns expired bets and bets due within 7 days', () async {
        // Create expired bet
        final expiredId = 'expired-bet';
        final now = DateTime.now().toUtc();

        await database.into(database.bets).insert(
              BetsCompanion.insert(
                id: expiredId,
                prediction: 'Expired bet',
                wrongIf: 'Test',
                status: const Value('expired'),
                createdAtUtc: now.subtract(const Duration(days: 91)),
                dueAtUtc: now.subtract(const Duration(days: 1)),
                updatedAtUtc: now.subtract(const Duration(days: 91)),
              ),
            );

        // Create bet due soon
        final soonId = 'soon-bet';
        await database.into(database.bets).insert(
              BetsCompanion.insert(
                id: soonId,
                prediction: 'Due soon bet',
                wrongIf: 'Test',
                createdAtUtc: now.subtract(const Duration(days: 85)),
                dueAtUtc: now.add(const Duration(days: 5)),
                updatedAtUtc: now.subtract(const Duration(days: 85)),
              ),
            );

        // Create bet due far in future
        await repository.create(
          prediction: 'Future bet',
          wrongIf: 'Test',
        );

        final needingEval = await repository.getNeedingEvaluation();
        expect(needingEval.length, 2);
        expect(needingEval.any((b) => b.id == expiredId), isTrue);
        expect(needingEval.any((b) => b.id == soonId), isTrue);
      });
    });

    group('getEvaluationStats', () {
      test('returns correct statistics', () async {
        // Create and evaluate bets
        final bet1 = await repository.create(prediction: 'Bet 1', wrongIf: 'W1');
        final bet2 = await repository.create(prediction: 'Bet 2', wrongIf: 'W2');
        final bet3 = await repository.create(prediction: 'Bet 3', wrongIf: 'W3');
        await repository.create(prediction: 'Bet 4', wrongIf: 'W4');

        await repository.evaluate(bet1, newStatus: BetStatus.correct);
        await repository.evaluate(bet2, newStatus: BetStatus.wrong);
        await repository.evaluate(bet3, newStatus: BetStatus.wrong);

        final stats = await repository.getEvaluationStats();
        expect(stats['total'], 4);
        expect(stats['open'], 1);
        expect(stats['correct'], 1);
        expect(stats['wrong'], 2);
        expect(stats['expired'], 0);
      });
    });

    group('softDelete', () {
      test('soft deletes a bet', () async {
        final id = await repository.create(
          prediction: 'To delete',
          wrongIf: 'Test',
        );

        await repository.softDelete(id);

        final bet = await repository.getById(id);
        expect(bet, isNull);

        final allBets = await database.select(database.bets).get();
        expect(allBets.length, 1);
        expect(allBets[0].deletedAtUtc, isNotNull);
      });
    });
  });
}
