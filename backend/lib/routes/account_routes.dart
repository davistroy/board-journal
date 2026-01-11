import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../db/database.dart';
import '../db/queries.dart';
import '../middleware/auth_middleware.dart';
import '../models/api_models.dart';

/// Account management routes.
///
/// Per PRD Section 3A.2:
/// - GET /account - Get account info
/// - DELETE /account - Delete account (7-day grace period)
/// - GET /account/export - Export all data
class AccountRoutes {
  final Database _db;
  final Queries _queries;

  AccountRoutes(this._db, this._queries);

  Router get router {
    final router = Router();

    // Get account info
    router.get('/', _handleGetAccount);

    // Delete account
    router.delete('/', _handleDeleteAccount);

    // Cancel deletion
    router.post('/cancel-deletion', _handleCancelDeletion);

    // Export all data
    router.get('/export', _handleExportData);

    return router;
  }

  /// Get account information and statistics.
  Future<Response> _handleGetAccount(Request request) async {
    final userId = request.requiredUserId;

    try {
      final user = await _queries.getUserById(userId);

      if (user == null) {
        return _jsonResponse(404, ApiError.notFound('User not found').toJson());
      }

      // Get account statistics
      final stats = await _getAccountStats(userId);

      final response = AccountResponse(
        user: UserInfo.fromMap(user),
        stats: stats,
      );

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to get account info').toJson(),
      );
    }
  }

  /// Delete account with 7-day grace period.
  ///
  /// Per PRD Section 3D:
  /// - Account deletion triggers a 7-day grace period
  /// - User can cancel within this period
  /// - After 7 days, all data is permanently deleted
  Future<Response> _handleDeleteAccount(Request request) async {
    final userId = request.requiredUserId;

    try {
      final user = await _queries.getUserById(userId);

      if (user == null) {
        return _jsonResponse(404, ApiError.notFound('User not found').toJson());
      }

      // Check if already scheduled for deletion
      if (user['delete_scheduled_at_utc'] != null) {
        final scheduledAt = user['delete_scheduled_at_utc'] as DateTime;
        return _jsonResponse(
          409,
          ApiError.conflict(
            'Account already scheduled for deletion on ${scheduledAt.toIso8601String()}',
          ).toJson(),
        );
      }

      // Schedule deletion
      await _queries.scheduleAccountDeletion(userId);

      // Revoke all refresh tokens
      await _queries.revokeAllUserRefreshTokens(userId);

      final deleteAt = DateTime.now().toUtc().add(const Duration(days: 7));

      final response = AccountDeletionResponse(
        scheduled: true,
        deleteAt: deleteAt,
        message: 'Your account has been scheduled for deletion. '
            'All data will be permanently deleted on ${deleteAt.toIso8601String()}. '
            'You can cancel this by logging in again within 7 days.',
      );

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to schedule account deletion').toJson(),
      );
    }
  }

  /// Cancel scheduled account deletion.
  Future<Response> _handleCancelDeletion(Request request) async {
    final userId = request.requiredUserId;

    try {
      final user = await _queries.getUserById(userId);

      if (user == null) {
        return _jsonResponse(404, ApiError.notFound('User not found').toJson());
      }

      if (user['delete_scheduled_at_utc'] == null) {
        return _jsonResponse(
          400,
          ApiError.badRequest('Account is not scheduled for deletion').toJson(),
        );
      }

      // Cancel deletion
      await _queries.cancelAccountDeletion(userId);

      return _jsonResponse(200, {
        'success': true,
        'message': 'Account deletion has been cancelled.',
      });
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to cancel account deletion').toJson(),
      );
    }
  }

  /// Export all user data.
  ///
  /// Returns a JSON file containing all user data.
  Future<Response> _handleExportData(Request request) async {
    final userId = request.requiredUserId;

    try {
      final user = await _queries.getUserById(userId);

      if (user == null) {
        return _jsonResponse(404, ApiError.notFound('User not found').toJson());
      }

      // Export all data
      final data = await _queries.exportUserData(userId);

      // Build export response
      final export = {
        'export_version': '1.0',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user': {
          'id': user['id'],
          'email': user['email'],
          'name': user['name'],
          'created_at': (user['created_at_utc'] as DateTime).toIso8601String(),
        },
        'data': data,
        'statistics': {
          'daily_entries': data['daily_entries']?.length ?? 0,
          'weekly_briefs': data['weekly_briefs']?.length ?? 0,
          'problems': data['problems']?.length ?? 0,
          'portfolio_versions': data['portfolio_versions']?.length ?? 0,
          'board_members': data['board_members']?.length ?? 0,
          'governance_sessions': data['governance_sessions']?.length ?? 0,
          'bets': data['bets']?.length ?? 0,
          'evidence_items': data['evidence_items']?.length ?? 0,
          'resetup_triggers': data['resetup_triggers']?.length ?? 0,
        },
      };

      // Return as downloadable JSON file
      return Response(
        200,
        body: const JsonEncoder.withIndent('  ').convert(export),
        headers: {
          'Content-Type': 'application/json',
          'Content-Disposition':
              'attachment; filename="boardroom-journal-export-${DateTime.now().toIso8601String().split('T')[0]}.json"',
        },
      );
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Failed to export data').toJson(),
      );
    }
  }

  /// Get account statistics.
  Future<AccountStats> _getAccountStats(String userId) async {
    // Query counts from each table
    final entryCount = await _db.queryOne(
      'SELECT COUNT(*) as count FROM daily_entries WHERE user_id = @userId AND deleted_at_utc IS NULL',
      parameters: {'userId': userId},
    );

    final briefCount = await _db.queryOne(
      'SELECT COUNT(*) as count FROM weekly_briefs WHERE user_id = @userId AND deleted_at_utc IS NULL',
      parameters: {'userId': userId},
    );

    final sessionCount = await _db.queryOne(
      'SELECT COUNT(*) as count FROM governance_sessions WHERE user_id = @userId AND deleted_at_utc IS NULL',
      parameters: {'userId': userId},
    );

    final betCount = await _db.queryOne(
      'SELECT COUNT(*) as count FROM bets WHERE user_id = @userId AND deleted_at_utc IS NULL',
      parameters: {'userId': userId},
    );

    // Get last entry date
    final lastEntry = await _db.queryOne(
      'SELECT created_at_utc FROM daily_entries WHERE user_id = @userId AND deleted_at_utc IS NULL ORDER BY created_at_utc DESC LIMIT 1',
      parameters: {'userId': userId},
    );

    // Get last session date
    final lastSession = await _db.queryOne(
      'SELECT started_at_utc FROM governance_sessions WHERE user_id = @userId AND deleted_at_utc IS NULL ORDER BY started_at_utc DESC LIMIT 1',
      parameters: {'userId': userId},
    );

    return AccountStats(
      totalEntries: (entryCount?.toColumnMap()['count'] as int?) ?? 0,
      totalBriefs: (briefCount?.toColumnMap()['count'] as int?) ?? 0,
      totalSessions: (sessionCount?.toColumnMap()['count'] as int?) ?? 0,
      totalBets: (betCount?.toColumnMap()['count'] as int?) ?? 0,
      lastEntryAt: lastEntry?.toColumnMap()['created_at_utc'] as DateTime?,
      lastSessionAt: lastSession?.toColumnMap()['started_at_utc'] as DateTime?,
    );
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
