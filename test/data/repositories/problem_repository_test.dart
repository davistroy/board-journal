import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late ProblemRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ProblemRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> createProblem({
    String name = 'Test Problem',
    ProblemDirection direction = ProblemDirection.stable,
    int timeAllocation = 30,
    int? displayOrder,
  }) async {
    return repository.create(
      name: name,
      whatBreaks: 'Things break if not solved',
      scarcitySignalsJson: '["signal1", "signal2"]',
      direction: direction,
      directionRationale: 'Test rationale',
      evidenceAiCheaper: 'AI evidence',
      evidenceErrorCost: 'Error cost evidence',
      evidenceTrustRequired: 'Trust evidence',
      timeAllocationPercent: timeAllocation,
      displayOrder: displayOrder,
    );
  }

  group('ProblemRepository', () {
    group('create', () {
      test('creates a problem with correct fields', () async {
        final id = await createProblem(
          name: 'Strategic Planning',
          direction: ProblemDirection.appreciating,
          timeAllocation: 35,
        );

        final problem = await repository.getById(id);
        expect(problem, isNotNull);
        expect(problem!.name, 'Strategic Planning');
        expect(problem.direction, 'appreciating');
        expect(problem.timeAllocationPercent, 35);
        expect(problem.displayOrder, 0); // First problem gets order 0
      });

      test('assigns incremental display orders', () async {
        await createProblem(name: 'First');
        await createProblem(name: 'Second');
        await createProblem(name: 'Third');

        final problems = await repository.getAll();
        expect(problems[0].displayOrder, 0);
        expect(problems[1].displayOrder, 1);
        expect(problems[2].displayOrder, 2);
      });
    });

    group('getAll', () {
      test('returns problems ordered by display order', () async {
        await createProblem(name: 'First', displayOrder: 0);
        await createProblem(name: 'Second', displayOrder: 1);
        await createProblem(name: 'Third', displayOrder: 2);

        final problems = await repository.getAll();
        expect(problems.length, 3);
        expect(problems[0].name, 'First');
        expect(problems[1].name, 'Second');
        expect(problems[2].name, 'Third');
      });
    });

    group('getByDirection', () {
      test('filters problems by direction', () async {
        await createProblem(name: 'Appreciating 1', direction: ProblemDirection.appreciating);
        await createProblem(name: 'Depreciating 1', direction: ProblemDirection.depreciating);
        await createProblem(name: 'Appreciating 2', direction: ProblemDirection.appreciating);
        await createProblem(name: 'Stable 1', direction: ProblemDirection.stable);

        final appreciating = await repository.getByDirection(ProblemDirection.appreciating);
        expect(appreciating.length, 2);
        expect(appreciating.every((p) => p.direction == 'appreciating'), isTrue);

        final depreciating = await repository.getByDirection(ProblemDirection.depreciating);
        expect(depreciating.length, 1);
      });
    });

    group('hasAppreciatingProblems', () {
      test('returns true when appreciating problems exist', () async {
        await createProblem(direction: ProblemDirection.appreciating);
        await createProblem(direction: ProblemDirection.stable);

        final result = await repository.hasAppreciatingProblems();
        expect(result, isTrue);
      });

      test('returns false when no appreciating problems exist', () async {
        await createProblem(direction: ProblemDirection.depreciating);
        await createProblem(direction: ProblemDirection.stable);

        final result = await repository.hasAppreciatingProblems();
        expect(result, isFalse);
      });
    });

    group('getHighestAppreciating', () {
      test('returns appreciating problem with highest time allocation', () async {
        await createProblem(
          name: 'Low allocation',
          direction: ProblemDirection.appreciating,
          timeAllocation: 20,
        );
        await createProblem(
          name: 'High allocation',
          direction: ProblemDirection.appreciating,
          timeAllocation: 40,
        );
        await createProblem(
          name: 'Medium allocation',
          direction: ProblemDirection.appreciating,
          timeAllocation: 30,
        );

        final highest = await repository.getHighestAppreciating();
        expect(highest, isNotNull);
        expect(highest!.name, 'High allocation');
        expect(highest.timeAllocationPercent, 40);
      });

      test('returns null when no appreciating problems exist', () async {
        await createProblem(direction: ProblemDirection.stable);

        final highest = await repository.getHighestAppreciating();
        expect(highest, isNull);
      });
    });

    group('getTotalAllocation', () {
      test('sums time allocation across all problems', () async {
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 40);
        await createProblem(timeAllocation: 25);

        final total = await repository.getTotalAllocation();
        expect(total, 95);
      });
    });

    group('validateAllocation', () {
      test('returns null for valid allocation (95-105%)', () async {
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 40);
        await createProblem(timeAllocation: 30); // Total: 100%

        final error = await repository.validateAllocation();
        expect(error, isNull);
      });

      test('returns warning for slightly off allocation (90-94% or 106-110%)', () async {
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 32); // Total: 92%

        final error = await repository.validateAllocation();
        expect(error, contains('92%'));
        expect(error, contains('Ideal range'));
      });

      test('returns error for allocation below 90%', () async {
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 30);
        await createProblem(timeAllocation: 25); // Total: 85%

        final error = await repository.validateAllocation();
        expect(error, contains('too low'));
        expect(error, contains('85%'));
      });

      test('returns error for allocation above 110%', () async {
        await createProblem(timeAllocation: 40);
        await createProblem(timeAllocation: 40);
        await createProblem(timeAllocation: 35); // Total: 115%

        final error = await repository.validateAllocation();
        expect(error, contains('too high'));
        expect(error, contains('115%'));
      });
    });

    group('softDelete', () {
      test('prevents deletion below minimum problems', () async {
        // Create exactly 3 problems (minimum)
        final id1 = await createProblem(name: 'Problem 1', timeAllocation: 34);
        await createProblem(name: 'Problem 2', timeAllocation: 33);
        await createProblem(name: 'Problem 3', timeAllocation: 33);

        // Try to delete one - should fail
        final result = await repository.softDelete(id1);
        expect(result, isFalse);

        // All problems should still exist
        final count = await repository.getCount();
        expect(count, 3);
      });

      test('allows deletion when above minimum', () async {
        // Create 4 problems
        final id1 = await createProblem(name: 'Problem 1', timeAllocation: 25);
        await createProblem(name: 'Problem 2', timeAllocation: 25);
        await createProblem(name: 'Problem 3', timeAllocation: 25);
        await createProblem(name: 'Problem 4', timeAllocation: 25);

        // Delete one - should succeed
        final result = await repository.softDelete(id1);
        expect(result, isTrue);

        final count = await repository.getCount();
        expect(count, 3);
      });
    });

    group('update', () {
      test('updates editable fields', () async {
        final id = await createProblem(name: 'Original', timeAllocation: 30);

        await repository.update(
          id,
          name: 'Updated Name',
          timeAllocationPercent: 35,
        );

        final problem = await repository.getById(id);
        expect(problem!.name, 'Updated Name');
        expect(problem.timeAllocationPercent, 35);
      });
    });

    group('updateDirection', () {
      test('updates direction and evidence', () async {
        final id = await createProblem(direction: ProblemDirection.stable);

        await repository.updateDirection(
          id,
          direction: ProblemDirection.appreciating,
          rationale: 'New rationale',
          evidenceAiCheaper: 'New AI evidence',
          evidenceErrorCost: 'New error cost evidence',
          evidenceTrustRequired: 'New trust evidence',
        );

        final problem = await repository.getById(id);
        expect(problem!.direction, 'appreciating');
        expect(problem.directionRationale, 'New rationale');
        expect(problem.evidenceAiCheaper, 'New AI evidence');
      });
    });

    group('reorder', () {
      test('updates display order for all problems', () async {
        final id1 = await createProblem(name: 'First', displayOrder: 0);
        final id2 = await createProblem(name: 'Second', displayOrder: 1);
        final id3 = await createProblem(name: 'Third', displayOrder: 2);

        // Reverse order
        await repository.reorder([id3, id2, id1]);

        final problems = await repository.getAll();
        expect(problems[0].name, 'Third');
        expect(problems[1].name, 'Second');
        expect(problems[2].name, 'First');
      });
    });

    group('watchAll', () {
      test('emits updates when problems change', () async {
        final stream = repository.watchAll();

        // Initial state
        expect(await stream.first, isEmpty);

        // After adding problem
        await createProblem(name: 'New Problem');

        final problems = await stream.first;
        expect(problems.length, 1);
        expect(problems[0].name, 'New Problem');
      });
    });

    group('getPendingSync', () {
      test('returns problems with pending sync status', () async {
        await createProblem(name: 'Pending problem');

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });

      test('excludes synced problems', () async {
        final id = await createProblem(name: 'Test');

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final pending = await repository.getPendingSync();
        expect(pending, isEmpty);
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await createProblem(name: 'Test');

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 5);

        final problem = await (database.select(database.problems)
              ..where((p) => p.id.equals(id)))
            .getSingle();

        expect(problem.syncStatus, 'synced');
        expect(problem.serverVersion, 5);
      });

      test('can set conflict status', () async {
        final id = await createProblem(name: 'Test');

        await repository.updateSyncStatus(id, SyncStatus.conflict);

        final problem = await (database.select(database.problems)
              ..where((p) => p.id.equals(id)))
            .getSingle();

        expect(problem.syncStatus, 'conflict');
      });
    });

    group('watchById', () {
      test('emits updates for specific problem', () async {
        final id = await createProblem(name: 'Watched problem');

        final stream = repository.watchById(id);

        var problem = await stream.first;
        expect(problem, isNotNull);
        expect(problem!.name, 'Watched problem');

        // Update it
        await repository.update(id, name: 'Updated name');

        problem = await stream.first;
        expect(problem!.name, 'Updated name');
      });

      test('emits null for non-existent id', () async {
        final stream = repository.watchById('non-existent-id');

        final problem = await stream.first;
        expect(problem, isNull);
      });
    });

    group('getCount', () {
      test('returns count of active problems', () async {
        await createProblem(name: 'Problem 1');
        await createProblem(name: 'Problem 2');
        await createProblem(name: 'Problem 3');

        final count = await repository.getCount();
        expect(count, 3);
      });

      test('returns zero for empty database', () async {
        final count = await repository.getCount();
        expect(count, 0);
      });
    });

    group('getAppreciating', () {
      test('returns only appreciating problems', () async {
        await createProblem(name: 'Appreciating 1', direction: ProblemDirection.appreciating);
        await createProblem(name: 'Stable', direction: ProblemDirection.stable);
        await createProblem(name: 'Appreciating 2', direction: ProblemDirection.appreciating);

        final appreciating = await repository.getAppreciating();
        expect(appreciating.length, 2);
        expect(appreciating.every((p) => p.direction == 'appreciating'), isTrue);
      });

      test('returns empty list when no appreciating problems', () async {
        await createProblem(name: 'Stable', direction: ProblemDirection.stable);
        await createProblem(name: 'Depreciating', direction: ProblemDirection.depreciating);

        final appreciating = await repository.getAppreciating();
        expect(appreciating, isEmpty);
      });
    });
  });
}
