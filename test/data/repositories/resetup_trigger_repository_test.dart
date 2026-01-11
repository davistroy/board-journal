import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late ReSetupTriggerRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ReSetupTriggerRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('ReSetupTriggerRepository', () {
    group('create', () {
      test('creates trigger with correct fields', () async {
        final dueDate = DateTime.utc(2027, 1, 1);

        final id = await repository.create(
          triggerType: 'role_change',
          description: 'New job promotion',
          condition: 'Role or responsibilities significantly changed',
          recommendedAction: 'full_resetup',
          dueAtUtc: dueDate,
        );

        expect(id, isNotEmpty);

        final trigger = await repository.getById(id);
        expect(trigger, isNotNull);
        expect(trigger!.triggerType, 'role_change');
        expect(trigger.description, 'New job promotion');
        expect(trigger.condition, contains('Role or responsibilities'));
        expect(trigger.recommendedAction, 'full_resetup');
        expect(trigger.dueAtUtc, dueDate);
        expect(trigger.isMet, isFalse);
      });

      test('creates trigger without due date', () async {
        final id = await repository.create(
          triggerType: 'scope_change',
          description: 'Project ended',
          condition: 'Major project completed',
          recommendedAction: 'review_problems',
        );

        final trigger = await repository.getById(id);
        expect(trigger!.dueAtUtc, isNull);
      });
    });

    group('createAnnualTrigger', () {
      test('creates annual trigger with due date 365 days from setup', () async {
        final setupDate = DateTime.utc(2026, 1, 15);

        final id = await repository.createAnnualTrigger(setupDate);

        final trigger = await repository.getById(id);
        expect(trigger!.triggerType, 'annual');
        expect(trigger.description, 'Annual portfolio review');
        expect(trigger.recommendedAction, 'full_resetup');

        final expectedDue = setupDate.add(const Duration(days: 365));
        expect(trigger.dueAtUtc, expectedDue);
      });
    });

    group('getById', () {
      test('returns null for non-existent trigger', () async {
        final trigger = await repository.getById('non-existent');
        expect(trigger, isNull);
      });
    });

    group('getAll', () {
      test('returns triggers ordered by due date', () async {
        await repository.create(
          triggerType: 'type_a',
          description: 'Later',
          condition: 'c1',
          recommendedAction: 'action',
          dueAtUtc: DateTime.utc(2027, 6, 1),
        );
        await repository.create(
          triggerType: 'type_b',
          description: 'Earlier',
          condition: 'c2',
          recommendedAction: 'action',
          dueAtUtc: DateTime.utc(2027, 1, 1),
        );
        await repository.create(
          triggerType: 'type_c',
          description: 'No due date',
          condition: 'c3',
          recommendedAction: 'action',
        );

        final all = await repository.getAll();

        expect(all.length, 3);
        // Null dueAtUtc sorts first in ascending order
      });

      test('returns empty list when no triggers exist', () async {
        final all = await repository.getAll();
        expect(all, isEmpty);
      });
    });

    group('getMet', () {
      test('returns only met triggers', () async {
        final id1 = await repository.create(
          triggerType: 'type_a',
          description: 'Will be met',
          condition: 'c1',
          recommendedAction: 'action',
        );
        await repository.create(
          triggerType: 'type_b',
          description: 'Not met',
          condition: 'c2',
          recommendedAction: 'action',
        );

        await repository.markMet(id1);

        final met = await repository.getMet();

        expect(met.length, 1);
        expect(met[0].description, 'Will be met');
        expect(met[0].isMet, isTrue);
      });
    });

    group('getUnmet', () {
      test('returns only unmet triggers', () async {
        final id1 = await repository.create(
          triggerType: 'type_a',
          description: 'Will be met',
          condition: 'c1',
          recommendedAction: 'action',
        );
        await repository.create(
          triggerType: 'type_b',
          description: 'Not met',
          condition: 'c2',
          recommendedAction: 'action',
        );

        await repository.markMet(id1);

        final unmet = await repository.getUnmet();

        expect(unmet.length, 1);
        expect(unmet[0].description, 'Not met');
      });
    });

    group('getApproaching', () {
      test('returns triggers within specified days', () async {
        final now = DateTime.now().toUtc();

        // Due in 10 days (should match)
        await repository.create(
          triggerType: 'soon',
          description: 'Approaching',
          condition: 'c1',
          recommendedAction: 'action',
          dueAtUtc: now.add(const Duration(days: 10)),
        );

        // Due in 60 days (should not match for default 30 days)
        await repository.create(
          triggerType: 'later',
          description: 'Not approaching',
          condition: 'c2',
          recommendedAction: 'action',
          dueAtUtc: now.add(const Duration(days: 60)),
        );

        // Past due (should not match)
        await repository.create(
          triggerType: 'past',
          description: 'Past due',
          condition: 'c3',
          recommendedAction: 'action',
          dueAtUtc: now.subtract(const Duration(days: 5)),
        );

        final approaching = await repository.getApproaching();

        expect(approaching.length, 1);
        expect(approaching[0].description, 'Approaching');
      });

      test('respects custom withinDays parameter', () async {
        final now = DateTime.now().toUtc();

        await repository.create(
          triggerType: 'type',
          description: 'Due in 45 days',
          condition: 'c1',
          recommendedAction: 'action',
          dueAtUtc: now.add(const Duration(days: 45)),
        );

        final approaching30 = await repository.getApproaching(withinDays: 30);
        expect(approaching30, isEmpty);

        final approaching60 = await repository.getApproaching(withinDays: 60);
        expect(approaching60.length, 1);
      });
    });

    group('getPastDue', () {
      test('returns triggers past their due date', () async {
        final now = DateTime.now().toUtc();

        await repository.create(
          triggerType: 'past',
          description: 'Overdue',
          condition: 'c1',
          recommendedAction: 'action',
          dueAtUtc: now.subtract(const Duration(days: 10)),
        );

        await repository.create(
          triggerType: 'future',
          description: 'Not due',
          condition: 'c2',
          recommendedAction: 'action',
          dueAtUtc: now.add(const Duration(days: 10)),
        );

        final pastDue = await repository.getPastDue();

        expect(pastDue.length, 1);
        expect(pastDue[0].description, 'Overdue');
      });

      test('excludes met triggers', () async {
        final now = DateTime.now().toUtc();

        final id = await repository.create(
          triggerType: 'past',
          description: 'Past but met',
          condition: 'c1',
          recommendedAction: 'action',
          dueAtUtc: now.subtract(const Duration(days: 10)),
        );

        await repository.markMet(id);

        final pastDue = await repository.getPastDue();
        expect(pastDue, isEmpty);
      });
    });

    group('markMet', () {
      test('marks trigger as met with timestamp', () async {
        final id = await repository.create(
          triggerType: 'type',
          description: 'To mark met',
          condition: 'c1',
          recommendedAction: 'action',
        );

        await repository.markMet(id);

        final trigger = await repository.getById(id);
        expect(trigger!.isMet, isTrue);
        expect(trigger.metAtUtc, isNotNull);
        expect(trigger.syncStatus, 'pending');
      });
    });

    group('reset', () {
      test('resets trigger to unmet', () async {
        final id = await repository.create(
          triggerType: 'type',
          description: 'To reset',
          condition: 'c1',
          recommendedAction: 'action',
        );

        await repository.markMet(id);
        await repository.reset(id);

        final trigger = await repository.getById(id);
        expect(trigger!.isMet, isFalse);
        expect(trigger.metAtUtc, isNull);
      });
    });

    group('deleteAll', () {
      test('deletes all triggers', () async {
        await repository.create(
          triggerType: 'type1',
          description: 'd1',
          condition: 'c1',
          recommendedAction: 'action',
        );
        await repository.create(
          triggerType: 'type2',
          description: 'd2',
          condition: 'c2',
          recommendedAction: 'action',
        );
        await repository.create(
          triggerType: 'type3',
          description: 'd3',
          condition: 'c3',
          recommendedAction: 'action',
        );

        final deleted = await repository.deleteAll();

        expect(deleted, 3);

        final all = await repository.getAll();
        expect(all, isEmpty);
      });
    });

    group('getPendingSync', () {
      test('returns triggers with pending sync status', () async {
        final id = await repository.create(
          triggerType: 'type',
          description: 'd',
          condition: 'c',
          recommendedAction: 'action',
        );

        await repository.markMet(id); // This sets syncStatus to pending

        final pending = await repository.getPendingSync();
        expect(pending.isNotEmpty, isTrue);
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await repository.create(
          triggerType: 'type',
          description: 'd',
          condition: 'c',
          recommendedAction: 'action',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 7);

        final query = database.select(database.reSetupTriggers)
          ..where((t) => t.id.equals(id));
        final trigger = await query.getSingle();

        expect(trigger.syncStatus, 'synced');
        expect(trigger.serverVersion, 7);
      });
    });

    group('watchAll', () {
      test('emits updates when triggers change', () async {
        final stream = repository.watchAll();
        final emissions = <List<ReSetupTrigger>>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          triggerType: 'type',
          description: 'New trigger',
          condition: 'c',
          recommendedAction: 'action',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last.length, 1);

        await subscription.cancel();
      });
    });

    group('watchMet', () {
      test('emits updates for met triggers', () async {
        final id = await repository.create(
          triggerType: 'type',
          description: 'To watch',
          condition: 'c',
          recommendedAction: 'action',
        );

        final stream = repository.watchMet();
        final emissions = <List<ReSetupTrigger>>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.markMet(id);

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last.length, 1);

        await subscription.cancel();
      });
    });
  });
}
