import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../models/api_models.dart';
import '../services/sync_service.dart';

/// Sync routes for data synchronization.
///
/// Per PRD Section 3C:
/// - GET /sync?since={timestamp} - Get changes since timestamp
/// - POST /sync - Push local changes
/// - GET /sync/full - Full data download
class SyncRoutes {
  final SyncService _syncService;

  SyncRoutes(this._syncService);

  Router get router {
    final router = Router();

    // Get changes since timestamp
    router.get('/', _handleGetChanges);

    // Push local changes
    router.post('/', _handlePushChanges);

    // Full data download
    router.get('/full', _handleFullDownload);

    return router;
  }

  /// Get changes since a timestamp.
  ///
  /// Query parameters:
  /// - since: ISO 8601 timestamp (required)
  Future<Response> _handleGetChanges(Request request) async {
    final userId = request.requiredUserId;

    final sinceParam = request.url.queryParameters['since'];

    if (sinceParam == null || sinceParam.isEmpty) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Missing required parameter: since').toJson(),
      );
    }

    DateTime since;
    try {
      since = DateTime.parse(sinceParam);
    } catch (e) {
      return _jsonResponse(
        400,
        ApiError.badRequest(
          'Invalid timestamp format. Use ISO 8601 (e.g., 2024-01-15T10:30:00Z)',
        ).toJson(),
      );
    }

    try {
      final response = await _syncService.getChangesSince(userId, since);

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to retrieve changes').toJson(),
      );
    }
  }

  /// Push local changes to the server.
  ///
  /// Request body:
  /// {
  ///   "records": [
  ///     {
  ///       "table_name": "daily_entries",
  ///       "record_id": "uuid",
  ///       "operation": "INSERT|UPDATE|DELETE",
  ///       "client_version": 1,
  ///       "data": { ... }  // Required for INSERT/UPDATE
  ///     }
  ///   ]
  /// }
  Future<Response> _handlePushChanges(Request request) async {
    final userId = request.requiredUserId;

    final body = await request.readAsString();
    Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Invalid JSON body').toJson(),
      );
    }

    final recordsJson = json['records'] as List<dynamic>?;

    if (recordsJson == null || recordsJson.isEmpty) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Missing or empty records array').toJson(),
      );
    }

    // Validate and parse records
    final records = <SyncPushRecord>[];
    final errors = <String, String>{};

    for (var i = 0; i < recordsJson.length; i++) {
      try {
        final recordJson = recordsJson[i] as Map<String, dynamic>;

        // Validate required fields
        if (!recordJson.containsKey('table_name')) {
          errors['records[$i]'] = 'Missing table_name';
          continue;
        }
        if (!recordJson.containsKey('record_id')) {
          errors['records[$i]'] = 'Missing record_id';
          continue;
        }
        if (!recordJson.containsKey('operation')) {
          errors['records[$i]'] = 'Missing operation';
          continue;
        }
        if (!recordJson.containsKey('client_version')) {
          errors['records[$i]'] = 'Missing client_version';
          continue;
        }

        final operation = recordJson['operation'] as String;
        if (!['INSERT', 'UPDATE', 'DELETE'].contains(operation)) {
          errors['records[$i]'] = 'Invalid operation: $operation';
          continue;
        }

        if (operation != 'DELETE' && !recordJson.containsKey('data')) {
          errors['records[$i]'] = 'Missing data for $operation operation';
          continue;
        }

        records.add(SyncPushRecord.fromJson(recordJson));
      } catch (e) {
        errors['records[$i]'] = 'Invalid record format: $e';
      }
    }

    if (errors.isNotEmpty) {
      return _jsonResponse(
        400,
        ApiError.validationError(errors).toJson(),
      );
    }

    try {
      final response = await _syncService.pushChanges(userId, records);

      // Return appropriate status code
      final statusCode = response.conflicts.isNotEmpty ? 409 : 200;

      return _jsonResponse(statusCode, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to push changes').toJson(),
      );
    }
  }

  /// Full data download for all tables.
  ///
  /// Returns all data for the authenticated user.
  /// Used for initial sync or recovery.
  Future<Response> _handleFullDownload(Request request) async {
    final userId = request.requiredUserId;

    try {
      final data = await _syncService.getFullData(userId);

      // Add metadata
      final response = {
        'data': data,
        'downloaded_at': DateTime.now().toUtc().toIso8601String(),
        'tables': data.keys.toList(),
        'record_counts': {
          for (final entry in data.entries) entry.key: entry.value.length,
        },
      };

      return _jsonResponse(200, response);
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to download data').toJson(),
      );
    }
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
