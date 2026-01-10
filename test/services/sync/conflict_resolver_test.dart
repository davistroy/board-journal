import 'dart:async';

import 'package:boardroom_journal/services/sync/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictResolver', () {
    late ConflictResolver resolver;
    late List<String> notifications;

    setUp(() {
      notifications = [];
      resolver = ConflictResolver(
        onConflictNotification: (message) {
          notifications.add(message);
        },
      );
    });

    tearDown(() {
      resolver.dispose();
    });

    test('resolves conflict in favor of local when local is newer', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {
          'id': 'entry-1',
          'content': 'Local version',
          'updatedAtUtc': DateTime(2024, 1, 15, 12, 0).toIso8601String(),
          'serverVersion': 1,
        },
        serverData: {
          'id': 'entry-1',
          'content': 'Server version',
          'updatedAtUtc': DateTime(2024, 1, 15, 10, 0).toIso8601String(),
          'serverVersion': 2,
        },
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      final result = resolver.resolve(conflict);

      expect(result.localWon, isTrue);
      expect(result.winningData['content'], equals('Local version'));
      expect(result.losingData['content'], equals('Server version'));
    });

    test('resolves conflict in favor of server when server is newer', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {
          'id': 'entry-1',
          'content': 'Local version',
          'updatedAtUtc': DateTime(2024, 1, 15, 10, 0).toIso8601String(),
          'serverVersion': 1,
        },
        serverData: {
          'id': 'entry-1',
          'content': 'Server version',
          'updatedAtUtc': DateTime(2024, 1, 15, 12, 0).toIso8601String(),
          'serverVersion': 2,
        },
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 10, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 12, 0),
      );

      final result = resolver.resolve(conflict);

      expect(result.localWon, isFalse);
      expect(result.winningData['content'], equals('Server version'));
      expect(result.losingData['content'], equals('Local version'));
    });

    test('sends notification on conflict resolution', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {'content': 'local'},
        serverData: {'content': 'server'},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      resolver.resolve(conflict);

      expect(notifications, hasLength(1));
      expect(
        notifications.first,
        contains('This entry was also edited on another device'),
      );
    });

    test('logs conflict for recovery', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {'content': 'local'},
        serverData: {'content': 'server'},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      resolver.resolve(conflict);

      final log = resolver.getConflictLog();
      expect(log, hasLength(1));
      expect(log.first.entityId, equals('entry-1'));
      expect(log.first.overwrittenData['content'], equals('server'));
      expect(log.first.winningData['content'], equals('local'));
    });

    test('emits conflict to stream', () async {
      final conflicts = <SyncConflict>[];
      final subscription = resolver.conflictStream.listen(conflicts.add);

      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {'content': 'local'},
        serverData: {'content': 'server'},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      resolver.resolve(conflict);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(conflicts, hasLength(1));
      expect(conflicts.first.entityId, equals('entry-1'));

      await subscription.cancel();
    });

    test('resolves multiple conflicts', () {
      final conflicts = [
        SyncConflict(
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          localData: {'content': 'local-1'},
          serverData: {'content': 'server-1'},
          localVersion: 1,
          serverVersion: 2,
          localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
          serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
        ),
        SyncConflict(
          entityId: 'entry-2',
          entityType: SyncEntityType.dailyEntry,
          localData: {'content': 'local-2'},
          serverData: {'content': 'server-2'},
          localVersion: 1,
          serverVersion: 2,
          localUpdatedAt: DateTime(2024, 1, 15, 10, 0),
          serverUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        ),
      ];

      final results = resolver.resolveAll(conflicts);

      expect(results, hasLength(2));
      expect(results[0].localWon, isTrue);
      expect(results[1].localWon, isFalse);
    });

    test('getMostRecentConflict returns latest conflict for entity', () {
      // Resolve multiple conflicts for the same entity
      for (var i = 0; i < 3; i++) {
        resolver.resolve(SyncConflict(
          entityId: 'entry-1',
          entityType: SyncEntityType.dailyEntry,
          localData: {'version': i},
          serverData: {'version': 'server-$i'},
          localVersion: i,
          serverVersion: i + 1,
          localUpdatedAt: DateTime(2024, 1, 15, 12, i),
          serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
        ));
      }

      final mostRecent = resolver.getMostRecentConflict('entry-1');

      expect(mostRecent, isNotNull);
      expect(mostRecent!.winningData['version'], equals(2));
    });

    test('clearLog removes all logged conflicts', () {
      resolver.resolve(SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {'content': 'local'},
        serverData: {'content': 'server'},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      ));

      expect(resolver.getConflictLog(), hasLength(1));

      resolver.clearLog();

      expect(resolver.getConflictLog(), isEmpty);
    });

    test('limits conflict log to 100 entries', () {
      for (var i = 0; i < 150; i++) {
        resolver.resolve(SyncConflict(
          entityId: 'entry-$i',
          entityType: SyncEntityType.dailyEntry,
          localData: {'index': i},
          serverData: {'index': 'server-$i'},
          localVersion: 1,
          serverVersion: 2,
          localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
          serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
        ));
      }

      expect(resolver.getConflictLog().length, lessThanOrEqualTo(100));
    });
  });

  group('SyncConflict', () {
    test('localWins is true when local is newer', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {},
        serverData: {},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      expect(conflict.localWins, isTrue);
    });

    test('localWins is false when server is newer', () {
      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {},
        serverData: {},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 10, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 12, 0),
      );

      expect(conflict.localWins, isFalse);
    });

    test('entityTypeName returns correct names', () {
      expect(
        SyncConflict(
          entityId: 'id',
          entityType: SyncEntityType.dailyEntry,
          localData: {},
          serverData: {},
          localVersion: 1,
          serverVersion: 2,
          localUpdatedAt: DateTime.now(),
          serverUpdatedAt: DateTime.now(),
        ).entityTypeName,
        equals('entry'),
      );

      expect(
        SyncConflict(
          entityId: 'id',
          entityType: SyncEntityType.weeklyBrief,
          localData: {},
          serverData: {},
          localVersion: 1,
          serverVersion: 2,
          localUpdatedAt: DateTime.now(),
          serverUpdatedAt: DateTime.now(),
        ).entityTypeName,
        equals('brief'),
      );
    });
  });

  group('ConflictResolver.createConflict', () {
    test('extracts version and timestamps from data', () {
      final conflict = ConflictResolver.createConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {
          'serverVersion': 1,
          'updatedAtUtc': '2024-01-15T12:00:00.000Z',
        },
        serverData: {
          'serverVersion': 2,
          'updatedAtUtc': '2024-01-15T10:00:00.000Z',
        },
      );

      expect(conflict.localVersion, equals(1));
      expect(conflict.serverVersion, equals(2));
      expect(conflict.localWins, isTrue);
    });

    test('handles missing version and timestamps', () {
      final conflict = ConflictResolver.createConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {},
        serverData: {},
      );

      expect(conflict.localVersion, equals(0));
      expect(conflict.serverVersion, equals(0));
    });
  });

  group('ConflictResolver.hasVersionConflict', () {
    test('returns true when versions differ', () {
      expect(
        ConflictResolver.hasVersionConflict(
          localVersion: 1,
          serverVersion: 2,
        ),
        isTrue,
      );
    });

    test('returns false when versions match', () {
      expect(
        ConflictResolver.hasVersionConflict(
          localVersion: 2,
          serverVersion: 2,
        ),
        isFalse,
      );
    });
  });

  group('ConflictLogEntry', () {
    test('serializes and deserializes correctly', () {
      final entry = ConflictLogEntry(
        id: 'log-1',
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        overwrittenData: {'content': 'old'},
        winningData: {'content': 'new'},
        localWon: true,
        resolvedAt: DateTime(2024, 1, 15, 12, 0),
      );

      final json = entry.toJson();
      final restored = ConflictLogEntry.fromJson(json);

      expect(restored.id, equals(entry.id));
      expect(restored.entityId, equals(entry.entityId));
      expect(restored.entityType, equals(entry.entityType));
      expect(restored.overwrittenData, equals(entry.overwrittenData));
      expect(restored.winningData, equals(entry.winningData));
      expect(restored.localWon, equals(entry.localWon));
      expect(restored.resolvedAt, equals(entry.resolvedAt));
    });
  });

  group('ConflictResolutionResult', () {
    test('contains correct notification message format', () {
      final resolver = ConflictResolver();

      final conflict = SyncConflict(
        entityId: 'entry-1',
        entityType: SyncEntityType.dailyEntry,
        localData: {'content': 'local'},
        serverData: {'content': 'server'},
        localVersion: 1,
        serverVersion: 2,
        localUpdatedAt: DateTime(2024, 1, 15, 12, 0),
        serverUpdatedAt: DateTime(2024, 1, 15, 10, 0),
      );

      final result = resolver.resolve(conflict);

      expect(
        result.notificationMessage,
        equals(
          'This entry was also edited on another device. '
          'Showing most recent version.',
        ),
      );

      resolver.dispose();
    });
  });
}
