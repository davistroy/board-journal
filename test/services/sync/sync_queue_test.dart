import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boardroom_journal/services/sync/sync_queue.dart';

@GenerateMocks([SharedPreferences])
import 'sync_queue_test.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    when(mockPrefs.getString('sync_queue')).thenReturn(null);
  });

  group('SyncQueueItem', () {
    test('serializes to JSON correctly', () {
      final item = SyncQueueItem(
        id: 'item-123',
        entityId: 'entry-456',
        entityType: SyncEntityType.dailyEntry,
        operationType: SyncOperationType.create,
        priority: SyncPriority.localEdits,
        payload: {'content': 'test'},
        queuedAt: DateTime(2026, 1, 15, 12, 0),
        attempts: 2,
        lastError: 'Network error',
        lastAttemptAt: DateTime(2026, 1, 15, 11, 0),
      );

      final json = item.toJson();

      expect(json['id'], 'item-123');
      expect(json['entityId'], 'entry-456');
      expect(json['entityType'], 'dailyEntry');
      expect(json['operationType'], 'create');
      expect(json['priority'], 4);
      expect(json['payload'], {'content': 'test'});
      expect(json['queuedAt'], '2026-01-15T12:00:00.000');
      expect(json['attempts'], 2);
      expect(json['lastError'], 'Network error');
      expect(json['lastAttemptAt'], '2026-01-15T11:00:00.000');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'item-123',
        'entityId': 'entry-456',
        'entityType': 'dailyEntry',
        'operationType': 'update',
        'priority': 2,
        'payload': {'content': 'test'},
        'queuedAt': '2026-01-15T12:00:00.000',
        'attempts': 1,
        'lastError': 'Timeout',
        'lastAttemptAt': '2026-01-15T11:30:00.000',
      };

      final item = SyncQueueItem.fromJson(json);

      expect(item.id, 'item-123');
      expect(item.entityId, 'entry-456');
      expect(item.entityType, SyncEntityType.dailyEntry);
      expect(item.operationType, SyncOperationType.update);
      expect(item.priority, SyncPriority.transcription);
      expect(item.payload, {'content': 'test'});
      expect(item.queuedAt, DateTime(2026, 1, 15, 12, 0));
      expect(item.attempts, 1);
      expect(item.lastError, 'Timeout');
      expect(item.lastAttemptAt, DateTime(2026, 1, 15, 11, 30));
    });

    test('copyWith creates new instance with updated fields', () {
      final item = SyncQueueItem(
        id: 'item-123',
        entityId: 'entry-456',
        entityType: SyncEntityType.dailyEntry,
        operationType: SyncOperationType.create,
        priority: SyncPriority.localEdits,
        queuedAt: DateTime(2026, 1, 15, 12, 0),
      );

      final updated = item.copyWith(
        attempts: 3,
        lastError: 'Server error',
        lastAttemptAt: DateTime(2026, 1, 15, 13, 0),
      );

      expect(updated.id, item.id);
      expect(updated.entityId, item.entityId);
      expect(updated.attempts, 3);
      expect(updated.lastError, 'Server error');
      expect(updated.lastAttemptAt, DateTime(2026, 1, 15, 13, 0));
    });
  });

  group('SyncPriority', () {
    test('has correct priority values', () {
      expect(SyncPriority.authRefresh.value, 1);
      expect(SyncPriority.transcription.value, 2);
      expect(SyncPriority.signalExtraction.value, 3);
      expect(SyncPriority.localEdits.value, 4);
      expect(SyncPriority.serverDownload.value, 5);
    });
  });

  group('SyncQueue', () {
    group('enqueue', () {
      test('adds item to queue and persists', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final item = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        );

        await queue.enqueue(item);

        expect(queue.pendingCount, 1);
        verify(mockPrefs.setString('sync_queue', any)).called(1);
      });

      test('replaces existing item with same entity', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final item1 = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime(2026, 1, 15, 12, 0),
        );
        final item2 = SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.update,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime(2026, 1, 15, 13, 0),
        );

        await queue.enqueue(item1);
        await queue.enqueue(item2);

        expect(queue.pendingCount, 1);
        expect(queue.getNext()?.id, 'item-2');
      });
    });

    group('dequeue', () {
      test('removes item from queue', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final item = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        );

        await queue.enqueue(item);
        await queue.dequeue('item-1');

        expect(queue.isEmpty, isTrue);
      });
    });

    group('getNext', () {
      test('returns highest priority item', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final lowPriority = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.serverDownload,
          queuedAt: DateTime(2026, 1, 15, 12, 0),
        );
        final highPriority = SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-2',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.aiProcess,
          priority: SyncPriority.transcription,
          queuedAt: DateTime(2026, 1, 15, 12, 1),
        );

        await queue.enqueue(lowPriority);
        await queue.enqueue(highPriority);

        final next = queue.getNext();
        expect(next?.id, 'item-2');
      });

      test('returns null when queue is empty', () {
        final queue = SyncQueue(mockPrefs);
        expect(queue.getNext(), isNull);
      });

      test('skips items that exceeded max attempts', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final failedItem = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.transcription,
          queuedAt: DateTime.now(),
          attempts: 5,
        );
        final validItem = SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-2',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        );

        await queue.enqueue(failedItem);
        await queue.enqueue(validItem);

        expect(queue.getNext()?.id, 'item-2');
      });
    });

    group('markFailed', () {
      test('increments attempt count and stores error', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        final item = SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        );

        await queue.enqueue(item);
        await queue.markFailed('item-1', 'Connection timeout');

        final updated = queue.getAll().first;
        expect(updated.attempts, 1);
        expect(updated.lastError, 'Connection timeout');
        expect(updated.lastAttemptAt, isNotNull);
      });
    });

    group('clear', () {
      test('removes all items from queue', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        await queue.enqueue(SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));
        await queue.enqueue(SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-2',
          entityType: SyncEntityType.weeklyBrief,
          operationType: SyncOperationType.update,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));

        await queue.clear();

        expect(queue.isEmpty, isTrue);
        expect(queue.pendingCount, 0);
      });
    });

    group('clearFailedItems', () {
      test('removes items that exceeded max attempts', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        await queue.enqueue(SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
          attempts: 5,
        ));
        await queue.enqueue(SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-2',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
          attempts: 2,
        ));

        final cleared = await queue.clearFailedItems();

        expect(cleared.length, 1);
        expect(cleared.first.id, 'item-1');
        expect(queue.pendingCount, 1);
      });
    });

    group('getByEntityType', () {
      test('returns only items of specified type', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        await queue.enqueue(SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));
        await queue.enqueue(SyncQueueItem(
          id: 'item-2',
          entityId: 'brief-1',
          entityType: SyncEntityType.weeklyBrief,
          operationType: SyncOperationType.update,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));

        final entries = queue.getByEntityType(SyncEntityType.dailyEntry);

        expect(entries.length, 1);
        expect(entries.first.id, 'item-1');
      });
    });

    group('getFailedItems', () {
      test('returns items with max attempts reached', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        await queue.enqueue(SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
          attempts: 5,
        ));
        await queue.enqueue(SyncQueueItem(
          id: 'item-2',
          entityId: 'entry-2',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));

        final failed = queue.getFailedItems();

        expect(failed.length, 1);
        expect(failed.first.id, 'item-1');
      });
    });

    group('hasItemsToSync', () {
      test('returns true when pending items exist', () async {
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final queue = SyncQueue(mockPrefs);
        await queue.enqueue(SyncQueueItem(
          id: 'item-1',
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          operationType: SyncOperationType.create,
          priority: SyncPriority.localEdits,
          queuedAt: DateTime.now(),
        ));

        expect(queue.hasItemsToSync, isTrue);
      });

      test('returns false when queue is empty', () {
        final queue = SyncQueue(mockPrefs);
        expect(queue.hasItemsToSync, isFalse);
      });
    });

    group('persistence', () {
      test('loads queue from storage on creation', () {
        final storedItems = [
          {
            'id': 'item-1',
            'entityId': 'entry-1',
            'entityType': 'dailyEntry',
            'operationType': 'create',
            'priority': 4,
            'queuedAt': '2026-01-15T12:00:00.000',
            'attempts': 0,
          },
        ];
        when(mockPrefs.getString('sync_queue'))
            .thenReturn(jsonEncode(storedItems));

        final queue = SyncQueue(mockPrefs);

        expect(queue.pendingCount, 1);
        expect(queue.getNext()?.id, 'item-1');
      });

      test('handles corrupted storage gracefully', () {
        when(mockPrefs.getString('sync_queue')).thenReturn('invalid json');

        final queue = SyncQueue(mockPrefs);

        expect(queue.isEmpty, isTrue);
      });
    });
  });

  group('SyncQueue factory methods', () {
    test('createEntryItem creates correct item', () {
      final item = SyncQueue.createEntryItem(
        id: 'item-1',
        entityId: 'entry-123',
        operationType: SyncOperationType.create,
        payload: {'content': 'test entry'},
      );

      expect(item.entityType, SyncEntityType.dailyEntry);
      expect(item.priority, SyncPriority.localEdits);
      expect(item.payload?['content'], 'test entry');
    });

    test('createBriefItem creates correct item', () {
      final item = SyncQueue.createBriefItem(
        id: 'item-1',
        entityId: 'brief-123',
        operationType: SyncOperationType.update,
      );

      expect(item.entityType, SyncEntityType.weeklyBrief);
      expect(item.priority, SyncPriority.localEdits);
    });

    test('createTranscriptionItem creates high priority item', () {
      final item = SyncQueue.createTranscriptionItem(
        id: 'item-1',
        entityId: 'entry-123',
        payload: {'audioPath': '/path/to/audio'},
      );

      expect(item.entityType, SyncEntityType.dailyEntry);
      expect(item.operationType, SyncOperationType.aiProcess);
      expect(item.priority, SyncPriority.transcription);
    });

    test('createSignalExtractionItem creates correct priority', () {
      final item = SyncQueue.createSignalExtractionItem(
        id: 'item-1',
        entityId: 'entry-123',
        payload: {'transcript': 'test content'},
      );

      expect(item.entityType, SyncEntityType.dailyEntry);
      expect(item.operationType, SyncOperationType.aiProcess);
      expect(item.priority, SyncPriority.signalExtraction);
    });
  });
}
