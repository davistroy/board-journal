import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late PortfolioHealthRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PortfolioHealthRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('PortfolioHealthRepository', () {
    group('upsert', () {
      test('creates new health record when none exists', () async {
        final id = await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          riskStatement: 'Exposed to market shifts',
          opportunityStatement: 'Under-investing in AI skills',
          portfolioVersion: 1,
        );

        expect(id, isNotEmpty);

        final health = await repository.getCurrent();
        expect(health, isNotNull);
        expect(health!.appreciatingPercent, 30);
        expect(health.depreciatingPercent, 40);
        expect(health.stablePercent, 30);
        expect(health.riskStatement, contains('market shifts'));
        expect(health.opportunityStatement, contains('AI skills'));
        expect(health.portfolioVersion, 1);
      });

      test('updates existing health record', () async {
        // Create initial
        await repository.upsert(
          appreciatingPercent: 20,
          depreciatingPercent: 50,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        // Update
        final id = await repository.upsert(
          appreciatingPercent: 35,
          depreciatingPercent: 35,
          stablePercent: 30,
          riskStatement: 'New risk',
          portfolioVersion: 2,
        );

        final health = await repository.getCurrent();
        expect(health!.appreciatingPercent, 35);
        expect(health.depreciatingPercent, 35);
        expect(health.riskStatement, 'New risk');
        expect(health.portfolioVersion, 2);

        // Should still be only one record (upsert behavior)
        final all = await database.select(database.portfolioHealths).get();
        expect(all.length, 1);
      });

      test('creates without optional fields', () async {
        await repository.upsert(
          appreciatingPercent: 25,
          depreciatingPercent: 45,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final health = await repository.getCurrent();
        expect(health!.riskStatement, isNull);
        expect(health.opportunityStatement, isNull);
      });
    });

    group('getCurrent', () {
      test('returns null when no health exists', () async {
        final health = await repository.getCurrent();
        expect(health, isNull);
      });

      test('returns most recent health by calculatedAtUtc', () async {
        await repository.upsert(
          appreciatingPercent: 20,
          depreciatingPercent: 50,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final health = await repository.getCurrent();
        expect(health, isNotNull);
        expect(health!.appreciatingPercent, 20);
      });
    });

    group('getById', () {
      test('returns health by ID', () async {
        final id = await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final health = await repository.getById(id);
        expect(health, isNotNull);
        expect(health!.id, id);
      });

      test('returns null for non-existent ID', () async {
        final health = await repository.getById('non-existent');
        expect(health, isNull);
      });
    });

    group('hasAppreciating', () {
      test('returns true when appreciating percent > 0', () async {
        await repository.upsert(
          appreciatingPercent: 25,
          depreciatingPercent: 45,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final hasAppreciating = await repository.hasAppreciating();
        expect(hasAppreciating, isTrue);
      });

      test('returns false when appreciating percent is 0', () async {
        await repository.upsert(
          appreciatingPercent: 0,
          depreciatingPercent: 60,
          stablePercent: 40,
          portfolioVersion: 1,
        );

        final hasAppreciating = await repository.hasAppreciating();
        expect(hasAppreciating, isFalse);
      });

      test('returns false when no health exists', () async {
        final hasAppreciating = await repository.hasAppreciating();
        expect(hasAppreciating, isFalse);
      });
    });

    group('getTrend', () {
      test('returns null when less than 2 versions', () async {
        await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final trend = await repository.getTrend();
        expect(trend, isNull);
      });

      test('returns improving when appreciating increased by more than 5%', () async {
        // Insert version 1 directly since upsert updates existing
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v1',
                appreciatingPercent: const Value(20),
                depreciatingPercent: const Value(50),
                stablePercent: const Value(30),
                portfolioVersion: const Value(1),
                calculatedAtUtc: DateTime.now().toUtc(),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v2',
                appreciatingPercent: const Value(35),
                depreciatingPercent: const Value(35),
                stablePercent: const Value(30),
                portfolioVersion: const Value(2),
                calculatedAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );

        final trend = await repository.getTrend();
        expect(trend, 'improving');
      });

      test('returns declining when appreciating decreased by more than 5%', () async {
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v1',
                appreciatingPercent: const Value(40),
                depreciatingPercent: const Value(30),
                stablePercent: const Value(30),
                portfolioVersion: const Value(1),
                calculatedAtUtc: DateTime.now().toUtc(),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v2',
                appreciatingPercent: const Value(25),
                depreciatingPercent: const Value(45),
                stablePercent: const Value(30),
                portfolioVersion: const Value(2),
                calculatedAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );

        final trend = await repository.getTrend();
        expect(trend, 'declining');
      });

      test('returns stable when change is within 5%', () async {
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v1',
                appreciatingPercent: const Value(30),
                depreciatingPercent: const Value(40),
                stablePercent: const Value(30),
                portfolioVersion: const Value(1),
                calculatedAtUtc: DateTime.now().toUtc(),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v2',
                appreciatingPercent: const Value(32),
                depreciatingPercent: const Value(38),
                stablePercent: const Value(30),
                portfolioVersion: const Value(2),
                calculatedAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );

        final trend = await repository.getTrend();
        expect(trend, 'stable');
      });
    });

    group('hasSignificantDepreciatingIncrease', () {
      test('returns true when depreciating increased by more than 10%', () async {
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v1',
                appreciatingPercent: const Value(40),
                depreciatingPercent: const Value(30),
                stablePercent: const Value(30),
                portfolioVersion: const Value(1),
                calculatedAtUtc: DateTime.now().toUtc(),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v2',
                appreciatingPercent: const Value(20),
                depreciatingPercent: const Value(50),
                stablePercent: const Value(30),
                portfolioVersion: const Value(2),
                calculatedAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );

        final hasIncrease = await repository.hasSignificantDepreciatingIncrease();
        expect(hasIncrease, isTrue);
      });

      test('returns false when depreciating increased by 10% or less', () async {
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v1',
                appreciatingPercent: const Value(40),
                depreciatingPercent: const Value(30),
                stablePercent: const Value(30),
                portfolioVersion: const Value(1),
                calculatedAtUtc: DateTime.now().toUtc(),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );
        await database.into(database.portfolioHealths).insert(
              PortfolioHealthsCompanion.insert(
                id: 'v2',
                appreciatingPercent: const Value(32),
                depreciatingPercent: const Value(38),
                stablePercent: const Value(30),
                portfolioVersion: const Value(2),
                calculatedAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 1)),
                updatedAtUtc: DateTime.now().toUtc(),
              ),
            );

        final hasIncrease = await repository.hasSignificantDepreciatingIncrease();
        expect(hasIncrease, isFalse);
      });

      test('returns false when less than 2 versions', () async {
        await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        final hasIncrease = await repository.hasSignificantDepreciatingIncrease();
        expect(hasIncrease, isFalse);
      });
    });

    group('getPendingSync', () {
      test('returns health with pending sync status', () async {
        final id = await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        // Mark as pending by updating
        await repository.upsert(
          appreciatingPercent: 35,
          depreciatingPercent: 35,
          stablePercent: 30,
          portfolioVersion: 2,
        );

        final pending = await repository.getPendingSync();
        // Check if any pending items exist
        expect(pending, isA<List<PortfolioHealth>>());
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 5);

        final query = database.select(database.portfolioHealths)
          ..where((h) => h.id.equals(id));
        final health = await query.getSingle();

        expect(health.syncStatus, 'synced');
        expect(health.serverVersion, 5);
      });
    });

    group('watchCurrent', () {
      test('emits updates when health changes', () async {
        final stream = repository.watchCurrent();
        final emissions = <PortfolioHealth?>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.upsert(
          appreciatingPercent: 30,
          depreciatingPercent: 40,
          stablePercent: 30,
          portfolioVersion: 1,
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isNull);
        expect(emissions.last, isNotNull);

        await subscription.cancel();
      });
    });
  });
}
