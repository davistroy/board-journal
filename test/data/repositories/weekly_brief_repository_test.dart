import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late WeeklyBriefRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WeeklyBriefRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('WeeklyBriefRepository', () {
    group('create', () {
      test('creates a new brief with correct fields', () async {
        final weekStart = DateTime.utc(2026, 1, 6); // Monday
        final weekEnd = DateTime.utc(2026, 1, 12, 23, 59, 59); // Sunday

        final id = await repository.create(
          weekStartUtc: weekStart,
          weekEndUtc: weekEnd,
          weekTimezone: 'America/New_York',
          briefMarkdown: '# Weekly Brief\n\nThis was a productive week.',
          boardMicroReviewMarkdown: 'Board review content',
          entryCount: 5,
        );

        expect(id, isNotEmpty);

        final brief = await repository.getById(id);
        expect(brief, isNotNull);
        expect(brief!.weekStartUtc, weekStart);
        expect(brief.weekEndUtc, weekEnd);
        expect(brief.weekTimezone, 'America/New_York');
        expect(brief.briefMarkdown, contains('productive week'));
        expect(brief.boardMicroReviewMarkdown, 'Board review content');
        expect(brief.entryCount, 5);
        expect(brief.regenCount, 0);
      });

      test('creates brief without optional fields', () async {
        final weekStart = DateTime.utc(2026, 1, 6);
        final weekEnd = DateTime.utc(2026, 1, 12, 23, 59, 59);

        final id = await repository.create(
          weekStartUtc: weekStart,
          weekEndUtc: weekEnd,
          weekTimezone: 'UTC',
          briefMarkdown: 'Minimal brief',
        );

        final brief = await repository.getById(id);
        expect(brief!.boardMicroReviewMarkdown, isNull);
        expect(brief.entryCount, 0);
      });
    });

    group('getById', () {
      test('returns null for non-existent brief', () async {
        final brief = await repository.getById('non-existent-id');
        expect(brief, isNull);
      });

      test('returns null for soft-deleted brief', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'To be deleted',
        );

        await repository.softDelete(id);

        final brief = await repository.getById(id);
        expect(brief, isNull);
      });
    });

    group('getByWeek', () {
      test('retrieves brief for specific week', () async {
        final weekStart = DateTime.utc(2026, 1, 6);
        final weekEnd = DateTime.utc(2026, 1, 12, 23, 59, 59);

        await repository.create(
          weekStartUtc: weekStart,
          weekEndUtc: weekEnd,
          weekTimezone: 'UTC',
          briefMarkdown: 'Week 2 brief',
        );

        // Query using a Wednesday in that week
        final brief = await repository.getByWeek(DateTime.utc(2026, 1, 8));
        expect(brief, isNotNull);
        expect(brief!.briefMarkdown, 'Week 2 brief');
      });

      test('returns null when no brief exists for week', () async {
        final brief = await repository.getByWeek(DateTime.utc(2026, 1, 15));
        expect(brief, isNull);
      });
    });

    group('getAll', () {
      test('returns briefs in reverse chronological order', () async {
        // Create briefs for different weeks
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Week 1',
        );
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 13),
          weekEndUtc: DateTime.utc(2026, 1, 19, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Week 2',
        );
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 20),
          weekEndUtc: DateTime.utc(2026, 1, 26, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Week 3',
        );

        final briefs = await repository.getAll();

        expect(briefs.length, 3);
        expect(briefs[0].briefMarkdown, 'Week 3'); // Most recent first
        expect(briefs[1].briefMarkdown, 'Week 2');
        expect(briefs[2].briefMarkdown, 'Week 1');
      });

      test('respects limit and offset', () async {
        for (int i = 1; i <= 5; i++) {
          await repository.create(
            weekStartUtc: DateTime.utc(2026, 1, i * 7),
            weekEndUtc: DateTime.utc(2026, 1, i * 7 + 6, 23, 59, 59),
            weekTimezone: 'UTC',
            briefMarkdown: 'Week $i',
          );
        }

        final briefs = await repository.getAll(limit: 2, offset: 1);

        expect(briefs.length, 2);
      });

      test('excludes soft-deleted briefs', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Deleted',
        );
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 13),
          weekEndUtc: DateTime.utc(2026, 1, 19, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Active',
        );

        await repository.softDelete(id);

        final briefs = await repository.getAll();
        expect(briefs.length, 1);
        expect(briefs[0].briefMarkdown, 'Active');
      });
    });

    group('getMostRecent', () {
      test('returns the most recent brief', () async {
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Old brief',
        );
        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 13),
          weekEndUtc: DateTime.utc(2026, 1, 19, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'New brief',
        );

        final brief = await repository.getMostRecent();
        expect(brief!.briefMarkdown, 'New brief');
      });

      test('returns null when no briefs exist', () async {
        final brief = await repository.getMostRecent();
        expect(brief, isNull);
      });
    });

    group('updateBrief', () {
      test('updates brief content', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Original content',
        );

        await repository.updateBrief(id, 'Updated content');

        final brief = await repository.getById(id);
        expect(brief!.briefMarkdown, 'Updated content');
        expect(brief.syncStatus, 'pending');
      });
    });

    group('updateMicroReview', () {
      test('updates micro review content', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        await repository.updateMicroReview(id, 'New micro review');

        final brief = await repository.getById(id);
        expect(brief!.boardMicroReviewMarkdown, 'New micro review');
      });
    });

    group('incrementRegenCount', () {
      test('increments regeneration count', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        final result = await repository.incrementRegenCount(id);

        expect(result, isTrue);
        final brief = await repository.getById(id);
        expect(brief!.regenCount, 1);
      });

      test('stores regen options when provided', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        await repository.incrementRegenCount(
          id,
          regenOptionsJson: '{"shorter": true}',
        );

        final brief = await repository.getById(id);
        expect(brief!.regenOptionsJson, '{"shorter": true}');
      });

      test('returns false when max regenerations reached', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        // Increment to max (5)
        for (int i = 0; i < 5; i++) {
          await repository.incrementRegenCount(id);
        }

        final result = await repository.incrementRegenCount(id);
        expect(result, isFalse);

        final brief = await repository.getById(id);
        expect(brief!.regenCount, 5); // Should stay at 5
      });

      test('returns false for non-existent brief', () async {
        final result = await repository.incrementRegenCount('non-existent');
        expect(result, isFalse);
      });
    });

    group('getRemainingRegenerations', () {
      test('returns correct remaining count', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        expect(await repository.getRemainingRegenerations(id), 5);

        await repository.incrementRegenCount(id);
        await repository.incrementRegenCount(id);

        expect(await repository.getRemainingRegenerations(id), 3);
      });

      test('returns 0 for non-existent brief', () async {
        final remaining = await repository.getRemainingRegenerations('non-existent');
        expect(remaining, 0);
      });
    });

    group('setMicroReviewCollapsed', () {
      test('updates collapsed state', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        await repository.setMicroReviewCollapsed(id, true);

        final brief = await repository.getById(id);
        expect(brief!.microReviewCollapsed, isTrue);

        await repository.setMicroReviewCollapsed(id, false);

        final brief2 = await repository.getById(id);
        expect(brief2!.microReviewCollapsed, isFalse);
      });
    });

    group('softDelete', () {
      test('soft deletes a brief', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        await repository.softDelete(id);

        final brief = await repository.getById(id);
        expect(brief, isNull);

        // But it still exists in database with deletedAtUtc set
        final deletedQuery = database.select(database.weeklyBriefs)
          ..where((b) => b.id.equals(id));
        final deletedBrief = await deletedQuery.getSingleOrNull();
        expect(deletedBrief, isNotNull);
        expect(deletedBrief!.deletedAtUtc, isNotNull);
      });
    });

    group('getPendingSync', () {
      test('returns briefs with pending sync status', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        // Update to create pending status
        await repository.updateBrief(id, 'Updated');

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Brief',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final query = database.select(database.weeklyBriefs)
          ..where((b) => b.id.equals(id));
        final brief = await query.getSingle();

        expect(brief.syncStatus, 'synced');
        expect(brief.serverVersion, 1);
      });
    });

    group('watchAll', () {
      test('emits updates when briefs change', () async {
        final stream = repository.watchAll();
        final emissions = <List<WeeklyBrief>>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'New brief',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last.length, 1);

        await subscription.cancel();
      });
    });

    group('watchById', () {
      test('emits updates for specific brief', () async {
        final id = await repository.create(
          weekStartUtc: DateTime.utc(2026, 1, 6),
          weekEndUtc: DateTime.utc(2026, 1, 12, 23, 59, 59),
          weekTimezone: 'UTC',
          briefMarkdown: 'Original',
        );

        final stream = repository.watchById(id);
        final emissions = <WeeklyBrief?>[];
        final subscription = stream.listen(emissions.add);

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.updateBrief(id, 'Updated');

        await Future.delayed(const Duration(milliseconds: 100));

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.last!.briefMarkdown, 'Updated');

        await subscription.cancel();
      });
    });
  });
}
