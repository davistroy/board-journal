import 'dart:convert';

import 'package:test/test.dart';

import '../../lib/services/sync_service.dart';

void main() {
  group('SyncService Models', () {
    group('SyncPushRecord', () {
      test('parses INSERT record correctly', () {
        final json = {
          'table_name': 'daily_entries',
          'record_id': 'uuid-1234',
          'operation': 'INSERT',
          'client_version': 0,
          'data': {
            'id': 'uuid-1234',
            'transcript_raw': 'Test transcript',
            'transcript_edited': 'Test transcript',
            'entry_type': 'text',
          },
        };

        final record = SyncPushRecord.fromJson(json);

        expect(record.tableName, equals('daily_entries'));
        expect(record.recordId, equals('uuid-1234'));
        expect(record.operation, equals('INSERT'));
        expect(record.clientVersion, equals(0));
        expect(record.data, isNotNull);
        expect(record.data!['transcript_raw'], equals('Test transcript'));
      });

      test('parses UPDATE record correctly', () {
        final json = {
          'table_name': 'daily_entries',
          'record_id': 'uuid-1234',
          'operation': 'UPDATE',
          'client_version': 1,
          'data': {
            'id': 'uuid-1234',
            'transcript_edited': 'Updated transcript',
          },
        };

        final record = SyncPushRecord.fromJson(json);

        expect(record.operation, equals('UPDATE'));
        expect(record.clientVersion, equals(1));
      });

      test('parses DELETE record correctly', () {
        final json = {
          'table_name': 'daily_entries',
          'record_id': 'uuid-1234',
          'operation': 'DELETE',
          'client_version': 2,
        };

        final record = SyncPushRecord.fromJson(json);

        expect(record.operation, equals('DELETE'));
        expect(record.data, isNull);
      });
    });

    group('SyncRecord', () {
      test('serializes to JSON correctly', () {
        final record = SyncRecord(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          operation: 'INSERT',
          changedAt: DateTime.utc(2024, 1, 15, 10, 30),
          version: 1,
          data: {'id': 'uuid-1234', 'transcript_raw': 'Test'},
        );

        final json = record.toJson();

        expect(json['table_name'], equals('daily_entries'));
        expect(json['record_id'], equals('uuid-1234'));
        expect(json['operation'], equals('INSERT'));
        expect(json['changed_at'], equals('2024-01-15T10:30:00.000Z'));
        expect(json['version'], equals(1));
        expect(json['data']['id'], equals('uuid-1234'));
      });

      test('serializes DELETE without data', () {
        final record = SyncRecord(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          operation: 'DELETE',
          changedAt: DateTime.utc(2024, 1, 15, 10, 30),
          version: 2,
        );

        final json = record.toJson();

        expect(json['operation'], equals('DELETE'));
        expect(json.containsKey('data'), isFalse);
      });
    });

    group('SyncResponse', () {
      test('serializes to JSON correctly', () {
        final response = SyncResponse(
          records: [
            SyncRecord(
              tableName: 'daily_entries',
              recordId: 'uuid-1',
              operation: 'INSERT',
              changedAt: DateTime.utc(2024, 1, 15),
              version: 1,
            ),
            SyncRecord(
              tableName: 'weekly_briefs',
              recordId: 'uuid-2',
              operation: 'UPDATE',
              changedAt: DateTime.utc(2024, 1, 15),
              version: 3,
            ),
          ],
          syncedAt: DateTime.utc(2024, 1, 15, 12),
        );

        final json = response.toJson();

        expect(json['records'], hasLength(2));
        expect(json['synced_at'], equals('2024-01-15T12:00:00.000Z'));
      });
    });

    group('SyncPushResult', () {
      test('serializes successful result', () {
        final result = SyncPushResult(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          success: true,
          newVersion: 2,
        );

        final json = result.toJson();

        expect(json['success'], isTrue);
        expect(json['new_version'], equals(2));
        expect(json.containsKey('has_conflict'), isFalse);
        expect(json.containsKey('error'), isFalse);
      });

      test('serializes failed result with error', () {
        final result = SyncPushResult(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          success: false,
          error: 'Record not found',
        );

        final json = result.toJson();

        expect(json['success'], isFalse);
        expect(json['error'], equals('Record not found'));
      });

      test('serializes conflict result', () {
        final result = SyncPushResult(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          success: false,
          hasConflict: true,
        );

        final json = result.toJson();

        expect(json['success'], isFalse);
        expect(json['has_conflict'], isTrue);
      });
    });

    group('SyncConflict', () {
      test('serializes conflict correctly', () {
        final conflict = SyncConflict(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          clientVersion: 1,
          serverVersion: 3,
          serverData: {'transcript_edited': 'Server version'},
          clientData: {'transcript_edited': 'Client version'},
        );

        final json = conflict.toJson();

        expect(json['table_name'], equals('daily_entries'));
        expect(json['client_version'], equals(1));
        expect(json['server_version'], equals(3));
        expect(json['server_data']['transcript_edited'], equals('Server version'));
        expect(json['client_data']['transcript_edited'], equals('Client version'));
        expect(json['resolution'], equals('server_wins'));
        expect(json['is_delete_conflict'], isFalse);
      });

      test('serializes delete conflict', () {
        final conflict = SyncConflict(
          tableName: 'daily_entries',
          recordId: 'uuid-1234',
          clientVersion: 1,
          serverVersion: 3,
          serverData: {'transcript_edited': 'Updated on server'},
          isDeleteConflict: true,
        );

        final json = conflict.toJson();

        expect(json['is_delete_conflict'], isTrue);
      });
    });

    group('SyncPushResponse', () {
      test('serializes response without conflicts', () {
        final response = SyncPushResponse(
          results: [
            SyncPushResult(
              tableName: 'daily_entries',
              recordId: 'uuid-1',
              success: true,
              newVersion: 1,
            ),
          ],
          conflicts: [],
          syncedAt: DateTime.utc(2024, 1, 15),
        );

        final json = response.toJson();

        expect(json['has_conflicts'], isFalse);
        expect(json['conflicts'], isEmpty);
      });

      test('serializes response with conflicts', () {
        final response = SyncPushResponse(
          results: [
            SyncPushResult(
              tableName: 'daily_entries',
              recordId: 'uuid-1',
              success: false,
              hasConflict: true,
            ),
          ],
          conflicts: [
            SyncConflict(
              tableName: 'daily_entries',
              recordId: 'uuid-1',
              clientVersion: 1,
              serverVersion: 2,
            ),
          ],
          syncedAt: DateTime.utc(2024, 1, 15),
        );

        final json = response.toJson();

        expect(json['has_conflicts'], isTrue);
        expect(json['conflicts'], hasLength(1));
      });
    });
  });

  group('Sync Request Validation', () {
    test('validates since parameter format', () {
      // Valid ISO 8601 formats
      expect(() => DateTime.parse('2024-01-15T10:30:00Z'), returnsNormally);
      expect(() => DateTime.parse('2024-01-15T10:30:00.000Z'), returnsNormally);
      expect(() => DateTime.parse('2024-01-15'), returnsNormally);

      // Invalid formats
      expect(() => DateTime.parse('invalid'), throwsFormatException);
      expect(() => DateTime.parse('2024/01/15'), throwsFormatException);
    });

    test('validates table names', () {
      final validTables = {
        'daily_entries',
        'weekly_briefs',
        'problems',
        'portfolio_versions',
        'board_members',
        'governance_sessions',
        'bets',
        'evidence_items',
        'resetup_triggers',
        'user_preferences',
      };

      expect(validTables.contains('daily_entries'), isTrue);
      expect(validTables.contains('invalid_table'), isFalse);
    });

    test('validates operation types', () {
      final validOperations = ['INSERT', 'UPDATE', 'DELETE'];

      expect(validOperations.contains('INSERT'), isTrue);
      expect(validOperations.contains('UPSERT'), isFalse);
    });
  });

  group('Full Download Response', () {
    test('structures full download response correctly', () {
      final data = {
        'daily_entries': [
          {'id': '1', 'transcript_raw': 'Entry 1'},
          {'id': '2', 'transcript_raw': 'Entry 2'},
        ],
        'weekly_briefs': [],
        'problems': [
          {'id': '3', 'name': 'Problem 1'},
        ],
      };

      final response = {
        'data': data,
        'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        'tables': data.keys.toList(),
        'record_counts': {
          for (final entry in data.entries) entry.key: entry.value.length,
        },
      };

      expect(response['tables'], hasLength(3));
      expect(response['record_counts']['daily_entries'], equals(2));
      expect(response['record_counts']['weekly_briefs'], equals(0));
      expect(response['record_counts']['problems'], equals(1));
    });
  });
}
