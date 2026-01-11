import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late PortfolioVersionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PortfolioVersionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('PortfolioVersionRepository', () {
    group('create', () {
      test('creates new version with correct fields', () async {
        final id = await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{"problems": [{"name": "API Design"}]}',
          healthSnapshotJson: '{"appreciating": 30}',
          boardAnchoringSnapshotJson: '{"roles": ["Accountability"]}',
          triggersSnapshotJson: '{"triggers": ["annual"]}',
          triggerReason: 'Initial setup',
        );

        expect(id, isNotEmpty);

        final version = await repository.getById(id);
        expect(version, isNotNull);
        expect(version!.versionNumber, 1);
        expect(version.problemsSnapshotJson, contains('API Design'));
        expect(version.healthSnapshotJson, contains('appreciating'));
        expect(version.boardAnchoringSnapshotJson, contains('Accountability'));
        expect(version.triggersSnapshotJson, contains('annual'));
        expect(version.triggerReason, 'Initial setup');
      });

      test('creates multiple versions with incrementing numbers', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Version 1',
        );
        await repository.create(
          versionNumber: 2,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Version 2',
        );
        await repository.create(
          versionNumber: 3,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Version 3',
        );

        final all = await repository.getAll();
        expect(all.length, 3);
        expect(all[0].versionNumber, 3); // Newest first
        expect(all[1].versionNumber, 2);
        expect(all[2].versionNumber, 1);
      });
    });

    group('getById', () {
      test('returns null for non-existent ID', () async {
        final version = await repository.getById('non-existent');
        expect(version, isNull);
      });
    });

    group('getByNumber', () {
      test('retrieves version by version number', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'First',
        );
        await repository.create(
          versionNumber: 2,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Second',
        );

        final version = await repository.getByNumber(1);
        expect(version, isNotNull);
        expect(version!.triggerReason, 'First');
      });

      test('returns null for non-existent version number', () async {
        final version = await repository.getByNumber(999);
        expect(version, isNull);
      });
    });

    group('getAll', () {
      test('returns versions in descending order by version number', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v1',
        );
        await repository.create(
          versionNumber: 3,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v3',
        );
        await repository.create(
          versionNumber: 2,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v2',
        );

        final all = await repository.getAll();

        expect(all.length, 3);
        expect(all[0].versionNumber, 3);
        expect(all[1].versionNumber, 2);
        expect(all[2].versionNumber, 1);
      });

      test('returns empty list when no versions exist', () async {
        final all = await repository.getAll();
        expect(all, isEmpty);
      });
    });

    group('getCurrent', () {
      test('returns the latest version', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Old',
        );
        await repository.create(
          versionNumber: 2,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Current',
        );

        final current = await repository.getCurrent();
        expect(current!.versionNumber, 2);
        expect(current.triggerReason, 'Current');
      });

      test('returns null when no versions exist', () async {
        final current = await repository.getCurrent();
        expect(current, isNull);
      });
    });

    group('getCurrentVersionNumber', () {
      test('returns current version number', () async {
        await repository.create(
          versionNumber: 5,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v5',
        );

        final number = await repository.getCurrentVersionNumber();
        expect(number, 5);
      });

      test('returns 0 when no versions exist', () async {
        final number = await repository.getCurrentVersionNumber();
        expect(number, 0);
      });
    });

    group('getNextVersionNumber', () {
      test('returns current version + 1', () async {
        await repository.create(
          versionNumber: 3,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v3',
        );

        final next = await repository.getNextVersionNumber();
        expect(next, 4);
      });

      test('returns 1 when no versions exist', () async {
        final next = await repository.getNextVersionNumber();
        expect(next, 1);
      });
    });

    group('hasPortfolio', () {
      test('returns true when portfolio exists', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'Initial',
        );

        final hasPortfolio = await repository.hasPortfolio();
        expect(hasPortfolio, isTrue);
      });

      test('returns false when no portfolio exists', () async {
        final hasPortfolio = await repository.hasPortfolio();
        expect(hasPortfolio, isFalse);
      });
    });

    group('getForComparison', () {
      test('returns both versions when they exist', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{"v": 1}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v1',
        );
        await repository.create(
          versionNumber: 2,
          problemsSnapshotJson: '{"v": 2}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v2',
        );

        final comparison = await repository.getForComparison(1, 2);

        expect(comparison.length, 2);
      });

      test('returns partial list when one version is missing', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v1',
        );

        final comparison = await repository.getForComparison(1, 99);

        expect(comparison.length, 1);
        expect(comparison[0].versionNumber, 1);
      });

      test('returns empty list when both versions are missing', () async {
        final comparison = await repository.getForComparison(98, 99);
        expect(comparison, isEmpty);
      });
    });

    group('getPendingSync', () {
      test('returns versions with pending sync status', () async {
        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v1',
        );

        final pending = await repository.getPendingSync();
        expect(pending, isA<List<PortfolioVersion>>());
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'v1',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 10);

        final query = database.select(database.portfolioVersions)
          ..where((v) => v.id.equals(id));
        final version = await query.getSingle();

        expect(version.syncStatus, 'synced');
        expect(version.serverVersion, 10);
      });
    });

    group('watchAll', () {
      test('emits updates when versions change', () async {
        final stream = repository.watchAll();
        final emissions = <List<PortfolioVersion>>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'New',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last.length, 1);

        await subscription.cancel();
      });
    });

    group('watchCurrent', () {
      test('emits updates for current version', () async {
        final stream = repository.watchCurrent();
        final emissions = <PortfolioVersion?>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          versionNumber: 1,
          problemsSnapshotJson: '{}',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '{}',
          triggerReason: 'First',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isNull);
        expect(emissions.last!.versionNumber, 1);

        await subscription.cancel();
      });
    });
  });
}
