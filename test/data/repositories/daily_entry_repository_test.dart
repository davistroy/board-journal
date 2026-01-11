import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late DailyEntryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DailyEntryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('DailyEntryRepository', () {
    group('create', () {
      test('creates a new entry with correct fields', () async {
        final id = await repository.create(
          transcriptRaw: 'Raw transcript text',
          transcriptEdited: 'Edited transcript text',
          entryType: EntryType.text,
          timezone: 'America/New_York',
        );

        expect(id, isNotEmpty);

        final entry = await repository.getById(id);
        expect(entry, isNotNull);
        expect(entry!.transcriptRaw, 'Raw transcript text');
        expect(entry.transcriptEdited, 'Edited transcript text');
        expect(entry.entryType, 'text');
        expect(entry.createdAtTimezone, 'America/New_York');
        expect(entry.wordCount, 3); // "Edited transcript text"
      });

      test('creates a voice entry with duration', () async {
        final id = await repository.create(
          transcriptRaw: 'Voice transcript',
          transcriptEdited: 'Voice transcript',
          entryType: EntryType.voice,
          timezone: 'America/New_York',
          durationSeconds: 120,
        );

        final entry = await repository.getById(id);
        expect(entry!.entryType, 'voice');
        expect(entry.durationSeconds, 120);
      });

      test('stores extracted signals JSON', () async {
        final signalsJson = '{"wins": ["Completed project"], "blockers": []}';
        final id = await repository.create(
          transcriptRaw: 'Test',
          transcriptEdited: 'Test',
          entryType: EntryType.text,
          timezone: 'UTC',
          extractedSignalsJson: signalsJson,
        );

        final entry = await repository.getById(id);
        expect(entry!.extractedSignalsJson, signalsJson);
      });
    });

    group('getById', () {
      test('returns null for non-existent entry', () async {
        final entry = await repository.getById('non-existent-id');
        expect(entry, isNull);
      });

      test('returns null for soft-deleted entry', () async {
        final id = await repository.create(
          transcriptRaw: 'To be deleted',
          transcriptEdited: 'To be deleted',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.softDelete(id);

        final entry = await repository.getById(id);
        expect(entry, isNull);
      });
    });

    group('getAll', () {
      test('returns entries in reverse chronological order', () async {
        await repository.create(
          transcriptRaw: 'First',
          transcriptEdited: 'First',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await Future.delayed(const Duration(seconds: 1));

        await repository.create(
          transcriptRaw: 'Second',
          transcriptEdited: 'Second',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final entries = await repository.getAll();
        expect(entries.length, 2);
        expect(entries[0].transcriptRaw, 'Second');
        expect(entries[1].transcriptRaw, 'First');
      });

      test('excludes soft-deleted entries', () async {
        final id = await repository.create(
          transcriptRaw: 'To delete',
          transcriptEdited: 'To delete',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.create(
          transcriptRaw: 'Keep',
          transcriptEdited: 'Keep',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.softDelete(id);

        final entries = await repository.getAll();
        expect(entries.length, 1);
        expect(entries[0].transcriptRaw, 'Keep');
      });

      test('supports pagination', () async {
        for (var i = 0; i < 5; i++) {
          await repository.create(
            transcriptRaw: 'Entry $i',
            transcriptEdited: 'Entry $i',
            entryType: EntryType.text,
            timezone: 'UTC',
          );
          await Future.delayed(const Duration(seconds: 1));
        }

        final page1 = await repository.getAll(limit: 2, offset: 0);
        expect(page1.length, 2);

        final page2 = await repository.getAll(limit: 2, offset: 2);
        expect(page2.length, 2);

        final page3 = await repository.getAll(limit: 2, offset: 4);
        expect(page3.length, 1);
      });
    });

    group('getByDateRange', () {
      test('returns entries within date range', () async {
        final now = DateTime.now().toUtc();
        final yesterday = now.subtract(const Duration(days: 1));
        final twoDaysAgo = now.subtract(const Duration(days: 2));

        // Create entry "today"
        await repository.create(
          transcriptRaw: 'Today entry',
          transcriptEdited: 'Today entry',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final range = DateRange(
          start: yesterday,
          end: now.add(const Duration(hours: 1)),
        );

        final entries = await repository.getByDateRange(range);
        expect(entries.length, 1);
        expect(entries[0].transcriptRaw, 'Today entry');
      });
    });

    group('getEntryCountForDay', () {
      test('counts entries for a specific day', () async {
        final today = DateTime.now().toUtc();

        await repository.create(
          transcriptRaw: 'Entry 1',
          transcriptEdited: 'Entry 1',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.create(
          transcriptRaw: 'Entry 2',
          transcriptEdited: 'Entry 2',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final count = await repository.getEntryCountForDay(today);
        expect(count, 2);
      });
    });

    group('updateTranscript', () {
      test('updates edited transcript and word count', () async {
        final id = await repository.create(
          transcriptRaw: 'Original',
          transcriptEdited: 'Original',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.updateTranscript(id, 'Updated edited transcript');

        final entry = await repository.getById(id);
        expect(entry!.transcriptEdited, 'Updated edited transcript');
        expect(entry.wordCount, 3);
        expect(entry.transcriptRaw, 'Original'); // Raw unchanged
        expect(entry.syncStatus, 'pending');
      });
    });

    group('updateExtractedSignals', () {
      test('updates signals JSON', () async {
        final id = await repository.create(
          transcriptRaw: 'Test',
          transcriptEdited: 'Test',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final newSignals = '{"wins": ["New win"]}';
        await repository.updateExtractedSignals(id, newSignals);

        final entry = await repository.getById(id);
        expect(entry!.extractedSignalsJson, newSignals);
      });
    });

    group('softDelete', () {
      test('sets deletedAtUtc timestamp', () async {
        final id = await repository.create(
          transcriptRaw: 'To delete',
          transcriptEdited: 'To delete',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.softDelete(id);

        // Entry is not returned by getById
        final entry = await repository.getById(id);
        expect(entry, isNull);

        // But entry still exists in database
        final allEntries = await database.select(database.dailyEntries).get();
        expect(allEntries.length, 1);
        expect(allEntries[0].deletedAtUtc, isNotNull);
      });
    });

    group('restore', () {
      test('clears deletedAtUtc timestamp', () async {
        final id = await repository.create(
          transcriptRaw: 'To restore',
          transcriptEdited: 'To restore',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.softDelete(id);
        expect(await repository.getById(id), isNull);

        await repository.restore(id);

        final entry = await repository.getById(id);
        expect(entry, isNotNull);
        expect(entry!.deletedAtUtc, isNull);
      });
    });

    group('getPendingSync', () {
      test('returns entries with pending sync status', () async {
        await repository.create(
          transcriptRaw: 'Pending',
          transcriptEdited: 'Pending',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status', () async {
        final id = await repository.create(
          transcriptRaw: 'Test',
          transcriptEdited: 'Test',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final entry = await (database.select(database.dailyEntries)
              ..where((e) => e.id.equals(id)))
            .getSingle();

        expect(entry.syncStatus, 'synced');
        expect(entry.serverVersion, 1);
      });
    });

    group('watchAll', () {
      test('emits updates when entries change', () async {
        final stream = repository.watchAll();

        // Initial state
        expect(await stream.first, isEmpty);

        // After adding entry
        await repository.create(
          transcriptRaw: 'New entry',
          transcriptEdited: 'New entry',
          entryType: EntryType.text,
          timezone: 'UTC',
        );

        final entries = await stream.first;
        expect(entries.length, 1);
      });
    });
  });
}
