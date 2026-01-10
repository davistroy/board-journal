import 'package:postgres/postgres.dart';

import 'database.dart';

/// SQL query helpers for all database operations.
class Queries {
  final Database _db;

  Queries(this._db);

  // ============================================
  // User Queries
  // ============================================

  /// Find a user by ID.
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final row = await _db.queryOne(
      '''
      SELECT id, email, name, provider, provider_user_id,
             created_at_utc, updated_at_utc, deleted_at_utc, delete_scheduled_at_utc
      FROM users
      WHERE id = @id AND deleted_at_utc IS NULL
      ''',
      parameters: {'id': userId},
    );
    return row != null ? _rowToMap(row) : null;
  }

  /// Find a user by email.
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final row = await _db.queryOne(
      '''
      SELECT id, email, name, provider, provider_user_id,
             created_at_utc, updated_at_utc, deleted_at_utc, delete_scheduled_at_utc
      FROM users
      WHERE email = @email AND deleted_at_utc IS NULL
      ''',
      parameters: {'email': email.toLowerCase()},
    );
    return row != null ? _rowToMap(row) : null;
  }

  /// Find a user by OAuth provider and provider user ID.
  Future<Map<String, dynamic>?> getUserByProvider(
    String provider,
    String providerUserId,
  ) async {
    final row = await _db.queryOne(
      '''
      SELECT id, email, name, provider, provider_user_id,
             created_at_utc, updated_at_utc, deleted_at_utc, delete_scheduled_at_utc
      FROM users
      WHERE provider = @provider AND provider_user_id = @providerUserId
        AND deleted_at_utc IS NULL
      ''',
      parameters: {
        'provider': provider,
        'providerUserId': providerUserId,
      },
    );
    return row != null ? _rowToMap(row) : null;
  }

  /// Create a new user.
  Future<Map<String, dynamic>> createUser({
    required String email,
    String? name,
    required String provider,
    required String providerUserId,
  }) async {
    final row = await _db.queryOne(
      '''
      INSERT INTO users (email, name, provider, provider_user_id)
      VALUES (@email, @name, @provider, @providerUserId)
      RETURNING id, email, name, provider, provider_user_id,
                created_at_utc, updated_at_utc, deleted_at_utc, delete_scheduled_at_utc
      ''',
      parameters: {
        'email': email.toLowerCase(),
        'name': name,
        'provider': provider,
        'providerUserId': providerUserId,
      },
    );
    return _rowToMap(row!);
  }

  /// Schedule account deletion (7-day grace period).
  Future<void> scheduleAccountDeletion(String userId) async {
    await _db.query(
      '''
      UPDATE users
      SET delete_scheduled_at_utc = NOW() + INTERVAL '7 days',
          updated_at_utc = NOW()
      WHERE id = @id
      ''',
      parameters: {'id': userId},
    );
  }

  /// Cancel scheduled account deletion.
  Future<void> cancelAccountDeletion(String userId) async {
    await _db.query(
      '''
      UPDATE users
      SET delete_scheduled_at_utc = NULL,
          updated_at_utc = NOW()
      WHERE id = @id
      ''',
      parameters: {'id': userId},
    );
  }

  // ============================================
  // Refresh Token Queries
  // ============================================

  /// Store a refresh token (hashed).
  Future<void> storeRefreshToken({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
    Map<String, dynamic>? deviceInfo,
  }) async {
    await _db.query(
      '''
      INSERT INTO refresh_tokens (user_id, token_hash, expires_at_utc, device_info)
      VALUES (@userId, @tokenHash, @expiresAt, @deviceInfo)
      ''',
      parameters: {
        'userId': userId,
        'tokenHash': tokenHash,
        'expiresAt': expiresAt,
        'deviceInfo': deviceInfo,
      },
    );
  }

  /// Find a valid refresh token.
  Future<Map<String, dynamic>?> findRefreshToken(String tokenHash) async {
    final row = await _db.queryOne(
      '''
      SELECT rt.id, rt.user_id, rt.token_hash, rt.expires_at_utc,
             rt.created_at_utc, rt.revoked_at_utc
      FROM refresh_tokens rt
      JOIN users u ON u.id = rt.user_id
      WHERE rt.token_hash = @tokenHash
        AND rt.expires_at_utc > NOW()
        AND rt.revoked_at_utc IS NULL
        AND u.deleted_at_utc IS NULL
      ''',
      parameters: {'tokenHash': tokenHash},
    );
    return row != null ? _rowToMap(row) : null;
  }

  /// Revoke a refresh token.
  Future<void> revokeRefreshToken(String tokenHash) async {
    await _db.query(
      '''
      UPDATE refresh_tokens
      SET revoked_at_utc = NOW()
      WHERE token_hash = @tokenHash
      ''',
      parameters: {'tokenHash': tokenHash},
    );
  }

  /// Revoke all refresh tokens for a user.
  Future<void> revokeAllUserRefreshTokens(String userId) async {
    await _db.query(
      '''
      UPDATE refresh_tokens
      SET revoked_at_utc = NOW()
      WHERE user_id = @userId AND revoked_at_utc IS NULL
      ''',
      parameters: {'userId': userId},
    );
  }

  // ============================================
  // Rate Limiting Queries
  // ============================================

  /// Get or create auth rate limit record for an IP.
  Future<Map<String, dynamic>> getAuthRateLimit(String ipAddress) async {
    // Try to get existing record
    var row = await _db.queryOne(
      '''
      SELECT ip_address, attempt_count, first_attempt_at_utc, lockout_until_utc
      FROM rate_limit_auth
      WHERE ip_address = @ip
      ''',
      parameters: {'ip': ipAddress},
    );

    if (row == null) {
      // Create new record
      row = await _db.queryOne(
        '''
        INSERT INTO rate_limit_auth (ip_address, attempt_count)
        VALUES (@ip, 0)
        RETURNING ip_address, attempt_count, first_attempt_at_utc, lockout_until_utc
        ''',
        parameters: {'ip': ipAddress},
      );
    }

    return _rowToMap(row!);
  }

  /// Increment auth attempt count.
  Future<void> incrementAuthAttempt(String ipAddress) async {
    await _db.query(
      '''
      UPDATE rate_limit_auth
      SET attempt_count = attempt_count + 1
      WHERE ip_address = @ip
      ''',
      parameters: {'ip': ipAddress},
    );
  }

  /// Set auth lockout.
  Future<void> setAuthLockout(String ipAddress, DateTime lockoutUntil) async {
    await _db.query(
      '''
      UPDATE rate_limit_auth
      SET lockout_until_utc = @lockout
      WHERE ip_address = @ip
      ''',
      parameters: {
        'ip': ipAddress,
        'lockout': lockoutUntil,
      },
    );
  }

  /// Reset auth rate limit.
  Future<void> resetAuthRateLimit(String ipAddress) async {
    await _db.query(
      '''
      UPDATE rate_limit_auth
      SET attempt_count = 0, first_attempt_at_utc = NOW(), lockout_until_utc = NULL
      WHERE ip_address = @ip
      ''',
      parameters: {'ip': ipAddress},
    );
  }

  /// Get account creation rate limit for an IP.
  Future<Map<String, dynamic>?> getAccountCreationRateLimit(
    String ipAddress,
  ) async {
    final row = await _db.queryOne(
      '''
      SELECT ip_address, account_count, window_start_utc
      FROM rate_limit_account_creation
      WHERE ip_address = @ip
        AND window_start_utc > NOW() - INTERVAL '1 hour'
      ''',
      parameters: {'ip': ipAddress},
    );
    return row != null ? _rowToMap(row) : null;
  }

  /// Increment account creation count.
  Future<void> incrementAccountCreation(String ipAddress) async {
    await _db.query(
      '''
      INSERT INTO rate_limit_account_creation (ip_address, account_count)
      VALUES (@ip, 1)
      ON CONFLICT (ip_address)
      DO UPDATE SET
        account_count = CASE
          WHEN rate_limit_account_creation.window_start_utc > NOW() - INTERVAL '1 hour'
          THEN rate_limit_account_creation.account_count + 1
          ELSE 1
        END,
        window_start_utc = CASE
          WHEN rate_limit_account_creation.window_start_utc > NOW() - INTERVAL '1 hour'
          THEN rate_limit_account_creation.window_start_utc
          ELSE NOW()
        END
      ''',
      parameters: {'ip': ipAddress},
    );
  }

  // ============================================
  // Sync Queries
  // ============================================

  /// Get changes since a timestamp for a user.
  Future<List<Map<String, dynamic>>> getChangesSince(
    String userId,
    DateTime since,
  ) async {
    final result = await _db.query(
      '''
      SELECT table_name, record_id, operation, changed_at_utc, new_version
      FROM sync_log
      WHERE user_id = @userId AND changed_at_utc > @since
      ORDER BY changed_at_utc ASC
      ''',
      parameters: {
        'userId': userId,
        'since': since,
      },
    );
    return result.map(_rowToMap).toList();
  }

  /// Get full data for a table.
  Future<List<Map<String, dynamic>>> getTableData(
    String tableName,
    String userId,
  ) async {
    // Validate table name to prevent SQL injection
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

    if (!validTables.contains(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }

    final result = await _db.query(
      'SELECT * FROM $tableName WHERE user_id = @userId',
      parameters: {'userId': userId},
    );
    return result.map(_rowToMap).toList();
  }

  /// Get a single record by ID.
  Future<Map<String, dynamic>?> getRecordById(
    String tableName,
    String recordId,
    String userId,
  ) async {
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

    if (!validTables.contains(tableName)) {
      throw ArgumentError('Invalid table name: $tableName');
    }

    final row = await _db.queryOne(
      'SELECT * FROM $tableName WHERE id = @id AND user_id = @userId',
      parameters: {
        'id': recordId,
        'userId': userId,
      },
    );
    return row != null ? _rowToMap(row) : null;
  }

  // ============================================
  // User Preferences Queries
  // ============================================

  /// Get or create user preferences.
  Future<Map<String, dynamic>> getOrCreateUserPreferences(String userId) async {
    // Try to get existing
    var row = await _db.queryOne(
      '''
      SELECT * FROM user_preferences WHERE user_id = @userId
      ''',
      parameters: {'userId': userId},
    );

    if (row == null) {
      // Create default preferences
      row = await _db.queryOne(
        '''
        INSERT INTO user_preferences (id, user_id, created_at_utc, updated_at_utc)
        VALUES (uuid_generate_v4(), @userId, NOW(), NOW())
        RETURNING *
        ''',
        parameters: {'userId': userId},
      );
    }

    return _rowToMap(row!);
  }

  // ============================================
  // Data Export Query
  // ============================================

  /// Export all data for a user.
  Future<Map<String, List<Map<String, dynamic>>>> exportUserData(
    String userId,
  ) async {
    final tables = [
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
    ];

    final export = <String, List<Map<String, dynamic>>>{};

    for (final table in tables) {
      export[table] = await getTableData(table, userId);
    }

    return export;
  }

  // ============================================
  // Helper Methods
  // ============================================

  /// Convert a ResultRow to a Map.
  Map<String, dynamic> _rowToMap(ResultRow row) {
    final map = <String, dynamic>{};
    for (final column in row.toColumnMap().entries) {
      map[column.key] = column.value;
    }
    return map;
  }
}
