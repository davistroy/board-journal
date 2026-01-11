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

    group('getAll', () {
      test('returns all non-deleted bets ordered by due date', () async {
        // Create bets at different times
        await repository.create(
          prediction: 'Bet 1',
          wrongIf: 'Wrong 1',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          prediction: 'Bet 2',
          wrongIf: 'Wrong 2',
        );

        final bets = await repository.getAll();
        expect(bets.length, 2);
        // Ordered by due date (ascending), so first created has earliest due
        expect(bets[0].prediction, 'Bet 1');
        expect(bets[1].prediction, 'Bet 2');
      });

      test('supports pagination', () async {
        for (var i = 0; i < 5; i++) {
          await repository.create(prediction: 'Bet $i', wrongIf: 'Wrong $i');
          await Future.delayed(const Duration(milliseconds: 50));
        }

        final page1 = await repository.getAll(limit: 2, offset: 0);
        expect(page1.length, 2);

        final page2 = await repository.getAll(limit: 2, offset: 2);
        expect(page2.length, 2);

        final page3 = await repository.getAll(limit: 2, offset: 4);
        expect(page3.length, 1);
      });

      test('excludes soft-deleted bets', () async {
        final id1 = await repository.create(
          prediction: 'To delete',
          wrongIf: 'Test',
        );
        await repository.create(
          prediction: 'Keep',
          wrongIf: 'Test',
        );

        await repository.softDelete(id1);

        final bets = await repository.getAll();
        expect(bets.length, 1);
        expect(bets[0].prediction, 'Keep');
      });
    });

    group('getMostRecentOpen', () {
      test('returns the most recently created open bet', () async {
        await repository.create(
          prediction: 'Old bet',
          wrongIf: 'Test',
        );

        await Future.delayed(const Duration(seconds: 1));

        await repository.create(
          prediction: 'New bet',
          wrongIf: 'Test',
        );

        final mostRecent = await repository.getMostRecentOpen();
        expect(mostRecent, isNotNull);
        expect(mostRecent!.prediction, 'New bet');
      });

      test('returns null when no open bets exist', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.evaluate(id, newStatus: BetStatus.correct);

        final mostRecent = await repository.getMostRecentOpen();
        expect(mostRecent, isNull);
      });

      test('excludes evaluated bets', () async {
        final id1 = await repository.create(
          prediction: 'Evaluated bet',
          wrongIf: 'Test',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          prediction: 'Open bet',
          wrongIf: 'Test',
        );

        await repository.evaluate(id1, newStatus: BetStatus.correct);

        final mostRecent = await repository.getMostRecentOpen();
        expect(mostRecent, isNotNull);
        expect(mostRecent!.prediction, 'Open bet');
      });
    });

    group('getBetForQuarterlyReview', () {
      test('returns the oldest open bet', () async {
        await repository.create(
          prediction: 'Oldest bet',
          wrongIf: 'Test',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          prediction: 'Newer bet',
          wrongIf: 'Test',
        );

        final forReview = await repository.getBetForQuarterlyReview();
        expect(forReview, isNotNull);
        expect(forReview!.prediction, 'Oldest bet');
      });

      test('returns expired bet if no open bets', () async {
        final now = DateTime.now().toUtc();

        // Create expired bet directly
        await database.into(database.bets).insert(
              BetsCompanion.insert(
                id: 'expired-bet',
                prediction: 'Expired bet',
                wrongIf: 'Test',
                status: const Value('expired'),
                createdAtUtc: now.subtract(const Duration(days: 91)),
                dueAtUtc: now.subtract(const Duration(days: 1)),
                updatedAtUtc: now.subtract(const Duration(days: 91)),
              ),
            );

        final forReview = await repository.getBetForQuarterlyReview();
        expect(forReview, isNotNull);
        expect(forReview!.prediction, 'Expired bet');
      });

      test('returns null when all bets are evaluated', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.evaluate(id, newStatus: BetStatus.correct);

        final forReview = await repository.getBetForQuarterlyReview();
        expect(forReview, isNull);
      });
    });

    group('getPendingSync', () {
      test('returns bets with pending sync status', () async {
        await repository.create(
          prediction: 'Pending bet',
          wrongIf: 'Test',
        );

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });

      test('excludes synced bets', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final pending = await repository.getPendingSync();
        expect(pending, isEmpty);
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 5);

        final bet = await (database.select(database.bets)
              ..where((b) => b.id.equals(id)))
            .getSingle();

        expect(bet.syncStatus, 'synced');
        expect(bet.serverVersion, 5);
      });

      test('can set conflict status', () async {
        final id = await repository.create(
          prediction: 'Test',
          wrongIf: 'Test',
        );

        await repository.updateSyncStatus(id, SyncStatus.conflict);

        final bet = await (database.select(database.bets)
              ..where((b) => b.id.equals(id)))
            .getSingle();

        expect(bet.syncStatus, 'conflict');
      });
    });

    group('watchAll', () {
      test('emits updates when bets change', () async {
        final stream = repository.watchAll();

        // Initial state
        expect(await stream.first, isEmpty);

        // After adding bet
        await repository.create(
          prediction: 'New bet',
          wrongIf: 'Test',
        );

        final bets = await stream.first;
        expect(bets.length, 1);
        expect(bets[0].prediction, 'New bet');
      });
    });

    group('watchOpen', () {
      test('emits only open bets', () async {
        final stream = repository.watchOpen();

        // Initial state
        expect(await stream.first, isEmpty);

        // Add open bet
        final id = await repository.create(
          prediction: 'Open bet',
          wrongIf: 'Test',
        );

        var bets = await stream.first;
        expect(bets.length, 1);

        // Evaluate it
        await repository.evaluate(id, newStatus: BetStatus.correct);

        bets = await stream.first;
        expect(bets, isEmpty);
      });
    });

    group('watchById', () {
      test('emits updates for specific bet', () async {
        final id = await repository.create(
          prediction: 'Watched bet',
          wrongIf: 'Test',
        );

        final stream = repository.watchById(id);

        var bet = await stream.first;
        expect(bet, isNotNull);
        expect(bet!.status, 'open');

        // Evaluate it
        await repository.evaluate(id, newStatus: BetStatus.wrong);

        bet = await stream.first;
        expect(bet!.status, 'wrong');
      });

      test('emits null for deleted bet', () async {
        final id = await repository.create(
          prediction: 'To delete',
          wrongIf: 'Test',
        );

        final stream = repository.watchById(id);

        var bet = await stream.first;
        expect(bet, isNotNull);

        await repository.softDelete(id);

        bet = await stream.first;
        expect(bet, isNull);
      });
    });
  });
}
