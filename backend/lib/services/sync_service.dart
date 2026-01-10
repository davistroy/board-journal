import 'dart:convert';

import '../db/database.dart';
import '../db/queries.dart';

/// Service for handling data synchronization.
///
/// Per PRD Section 3C:
/// - Local-first SQLite syncs to cloud
/// - Last-write-wins conflict resolution
/// - User notified when data is overwritten
class SyncService {
  final Database _db;
  final Queries _queries;

  SyncService(this._db, this._queries);

  /// Get changes since a timestamp.
  ///
  /// Returns a list of change records including:
  /// - Table name
  /// - Record ID
  /// - Operation (INSERT, UPDATE, DELETE)
  /// - Changed timestamp
  /// - Full record data for INSERT/UPDATE
  Future<SyncResponse> getChangesSince(
    String userId,
    DateTime since,
  ) async {
    final changes = await _queries.getChangesSince(userId, since);
    final records = <SyncRecord>[];

    for (final change in changes) {
      final tableName = change['table_name'] as String;
      final recordId = change['record_id'] as String;
      final operation = change['operation'] as String;

      Map<String, dynamic>? data;
      if (operation != 'DELETE') {
        data = await _queries.getRecordById(tableName, recordId, userId);
      }

      records.add(SyncRecord(
        tableName: tableName,
        recordId: recordId,
        operation: operation,
        changedAt: change['changed_at_utc'] as DateTime,
        version: change['new_version'] as int,
        data: data,
      ));
    }

    return SyncResponse(
      records: records,
      syncedAt: DateTime.now().toUtc(),
    );
  }

  /// Push local changes to the server.
  ///
  /// Returns a list of conflicts (if any) and the new server versions.
  Future<SyncPushResponse> pushChanges(
    String userId,
    List<SyncPushRecord> records,
  ) async {
    final results = <SyncPushResult>[];
    final conflicts = <SyncConflict>[];

    await _db.transaction((session) async {
      for (final record in records) {
        try {
          final result = await _processRecord(session, userId, record);
          if (result.hasConflict) {
            conflicts.add(result.conflict!);
          }
          results.add(result);
        } catch (e) {
          results.add(SyncPushResult(
            tableName: record.tableName,
            recordId: record.recordId,
            success: false,
            error: e.toString(),
          ));
        }
      }
    });

    return SyncPushResponse(
      results: results,
      conflicts: conflicts,
      syncedAt: DateTime.now().toUtc(),
    );
  }

  /// Process a single sync record within a transaction.
  Future<SyncPushResult> _processRecord(
    TxSession session,
    String userId,
    SyncPushRecord record,
  ) async {
    final tableName = record.tableName;
    final recordId = record.recordId;

    // Validate table name
    if (!_validTables.contains(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }

    // Get current server record
    final serverRecord = await session.queryOneNamed(
      'SELECT * FROM $tableName WHERE id = @id AND user_id = @userId',
      parameters: {
        'id': recordId,
        'userId': userId,
      },
    );

    final clientVersion = record.clientVersion;

    if (record.operation == 'DELETE') {
      return await _processDelete(
        session,
        tableName,
        recordId,
        userId,
        clientVersion,
        serverRecord,
      );
    }

    if (serverRecord == null) {
      // New record - insert
      return await _processInsert(
        session,
        tableName,
        recordId,
        userId,
        record.data!,
      );
    }

    // Existing record - check for conflicts
    final serverVersion = serverRecord.toColumnMap()['server_version'] as int;

    if (clientVersion < serverVersion) {
      // Conflict detected - server has newer version
      return SyncPushResult(
        tableName: tableName,
        recordId: recordId,
        success: false,
        hasConflict: true,
        conflict: SyncConflict(
          tableName: tableName,
          recordId: recordId,
          clientVersion: clientVersion,
          serverVersion: serverVersion,
          serverData: _rowToMap(serverRecord),
          clientData: record.data,
        ),
      );
    }

    // No conflict - update
    return await _processUpdate(
      session,
      tableName,
      recordId,
      userId,
      record.data!,
      serverVersion,
    );
  }

  Future<SyncPushResult> _processInsert(
    TxSession session,
    String tableName,
    String recordId,
    String userId,
    Map<String, dynamic> data,
  ) async {
    // Add user_id and server_version
    data['user_id'] = userId;
    data['server_version'] = 1;
    data['sync_status'] = 'synced';

    // Build insert query
    final columns = data.keys.toList();
    final values = columns.map((c) => '@$c').join(', ');
    final columnList = columns.join(', ');

    await session.queryNamed(
      'INSERT INTO $tableName ($columnList) VALUES ($values)',
      parameters: data,
    );

    return SyncPushResult(
      tableName: tableName,
      recordId: recordId,
      success: true,
      newVersion: 1,
    );
  }

  Future<SyncPushResult> _processUpdate(
    TxSession session,
    String tableName,
    String recordId,
    String userId,
    Map<String, dynamic> data,
    int currentVersion,
  ) async {
    final newVersion = currentVersion + 1;

    // Remove fields that shouldn't be updated directly
    data.remove('id');
    data.remove('user_id');
    data.remove('created_at_utc');
    data['server_version'] = newVersion;
    data['sync_status'] = 'synced';
    data['updated_at_utc'] = DateTime.now().toUtc();

    // Build update query
    final setClauses = data.keys.map((c) => '$c = @$c').join(', ');

    await session.queryNamed(
      '''
      UPDATE $tableName
      SET $setClauses
      WHERE id = @id AND user_id = @userId
      ''',
      parameters: {
        ...data,
        'id': recordId,
        'userId': userId,
      },
    );

    return SyncPushResult(
      tableName: tableName,
      recordId: recordId,
      success: true,
      newVersion: newVersion,
    );
  }

  Future<SyncPushResult> _processDelete(
    TxSession session,
    String tableName,
    String recordId,
    String userId,
    int clientVersion,
    ResultRow? serverRecord,
  ) async {
    if (serverRecord == null) {
      // Record doesn't exist - nothing to delete
      return SyncPushResult(
        tableName: tableName,
        recordId: recordId,
        success: true,
      );
    }

    final serverVersion = serverRecord.toColumnMap()['server_version'] as int;

    if (clientVersion < serverVersion) {
      // Conflict - server has newer version
      return SyncPushResult(
        tableName: tableName,
        recordId: recordId,
        success: false,
        hasConflict: true,
        conflict: SyncConflict(
          tableName: tableName,
          recordId: recordId,
          clientVersion: clientVersion,
          serverVersion: serverVersion,
          serverData: _rowToMap(serverRecord),
          isDeleteConflict: true,
        ),
      );
    }

    // Soft delete
    final newVersion = serverVersion + 1;
    await session.queryNamed(
      '''
      UPDATE $tableName
      SET deleted_at_utc = NOW(),
          server_version = @newVersion,
          sync_status = 'synced'
      WHERE id = @id AND user_id = @userId
      ''',
      parameters: {
        'id': recordId,
        'userId': userId,
        'newVersion': newVersion,
      },
    );

    return SyncPushResult(
      tableName: tableName,
      recordId: recordId,
      success: true,
      newVersion: newVersion,
    );
  }

  /// Get full data download for all tables.
  Future<Map<String, List<Map<String, dynamic>>>> getFullData(
    String userId,
  ) async {
    return await _queries.exportUserData(userId);
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final map = <String, dynamic>{};
    for (final column in row.toColumnMap().entries) {
      map[column.key] = column.value;
    }
    return map;
  }

  static const _validTables = {
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
}

/// Response from getChangesSince.
class SyncResponse {
  final List<SyncRecord> records;
  final DateTime syncedAt;

  SyncResponse({
    required this.records,
    required this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'records': records.map((r) => r.toJson()).toList(),
        'synced_at': syncedAt.toIso8601String(),
      };
}

/// A single sync record.
class SyncRecord {
  final String tableName;
  final String recordId;
  final String operation;
  final DateTime changedAt;
  final int version;
  final Map<String, dynamic>? data;

  SyncRecord({
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.changedAt,
    required this.version,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'changed_at': changedAt.toIso8601String(),
        'version': version,
        if (data != null) 'data': data,
      };
}

/// A record to push to the server.
class SyncPushRecord {
  final String tableName;
  final String recordId;
  final String operation;
  final int clientVersion;
  final Map<String, dynamic>? data;

  SyncPushRecord({
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.clientVersion,
    this.data,
  });

  factory SyncPushRecord.fromJson(Map<String, dynamic> json) {
    return SyncPushRecord(
      tableName: json['table_name'] as String,
      recordId: json['record_id'] as String,
      operation: json['operation'] as String,
      clientVersion: json['client_version'] as int,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Response from pushChanges.
class SyncPushResponse {
  final List<SyncPushResult> results;
  final List<SyncConflict> conflicts;
  final DateTime syncedAt;

  SyncPushResponse({
    required this.results,
    required this.conflicts,
    required this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'results': results.map((r) => r.toJson()).toList(),
        'conflicts': conflicts.map((c) => c.toJson()).toList(),
        'synced_at': syncedAt.toIso8601String(),
        'has_conflicts': conflicts.isNotEmpty,
      };
}

/// Result of pushing a single record.
class SyncPushResult {
  final String tableName;
  final String recordId;
  final bool success;
  final int? newVersion;
  final bool hasConflict;
  final SyncConflict? conflict;
  final String? error;

  SyncPushResult({
    required this.tableName,
    required this.recordId,
    required this.success,
    this.newVersion,
    this.hasConflict = false,
    this.conflict,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'table_name': tableName,
        'record_id': recordId,
        'success': success,
        if (newVersion != null) 'new_version': newVersion,
        if (hasConflict) 'has_conflict': hasConflict,
        if (error != null) 'error': error,
      };
}

/// A sync conflict.
class SyncConflict {
  final String tableName;
  final String recordId;
  final int clientVersion;
  final int serverVersion;
  final Map<String, dynamic>? serverData;
  final Map<String, dynamic>? clientData;
  final bool isDeleteConflict;

  SyncConflict({
    required this.tableName,
    required this.recordId,
    required this.clientVersion,
    required this.serverVersion,
    this.serverData,
    this.clientData,
    this.isDeleteConflict = false,
  });

  Map<String, dynamic> toJson() => {
        'table_name': tableName,
        'record_id': recordId,
        'client_version': clientVersion,
        'server_version': serverVersion,
        if (serverData != null) 'server_data': serverData,
        if (clientData != null) 'client_data': clientData,
        'is_delete_conflict': isDeleteConflict,
        'resolution': 'server_wins',
      };
}
