import 'package:postgres/postgres.dart';
import '../config/config.dart';

/// Database connection pool manager.
///
/// Provides connection pooling and query execution for PostgreSQL.
class Database {
  static Database? _instance;
  Pool? _pool;
  final Config _config;

  Database._(this._config);

  /// Get the database instance.
  static Database get instance {
    if (_instance == null) {
      throw DatabaseError('Database not initialized. Call Database.initialize() first.');
    }
    return _instance!;
  }

  /// Initialize the database with configuration.
  static Future<Database> initialize(Config config) async {
    if (_instance != null) {
      return _instance!;
    }

    final db = Database._(config);
    await db._connect();
    _instance = db;
    return db;
  }

  /// Reset instance (for testing).
  static Future<void> reset() async {
    await _instance?.close();
    _instance = null;
  }

  /// Connect to the database.
  Future<void> _connect() async {
    final endpoint = Endpoint(
      host: _config.databaseHost,
      port: _config.databasePort,
      database: _config.databaseName,
      username: _config.databaseUser,
      password: _config.databasePassword,
    );

    _pool = Pool.withEndpoints(
      [endpoint],
      settings: PoolSettings(
        maxConnectionCount: _config.databasePoolSize,
        sslMode: _config.isProduction ? SslMode.require : SslMode.disable,
      ),
    );
  }

  /// Execute a query and return the results.
  Future<Result> query(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    if (_pool == null) {
      throw DatabaseError('Database not connected');
    }

    try {
      return await _pool!.execute(
        Sql.named(sql),
        parameters: parameters ?? {},
      );
    } catch (e) {
      throw DatabaseError('Query failed: $e');
    }
  }

  /// Execute a query and return the first row, or null if no results.
  Future<ResultRow?> queryOne(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final result = await query(sql, parameters: parameters);
    return result.isEmpty ? null : result.first;
  }

  /// Execute a query within a transaction.
  Future<T> transaction<T>(
    Future<T> Function(TxSession session) action,
  ) async {
    if (_pool == null) {
      throw DatabaseError('Database not connected');
    }

    return await _pool!.runTx(action);
  }

  /// Close the database connection.
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }

  /// Check if the database is connected.
  bool get isConnected => _pool != null;
}

/// Wrapper for transaction session to simplify query execution.
extension TxSessionExtension on TxSession {
  /// Execute a named query within the transaction.
  Future<Result> queryNamed(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    return await execute(
      Sql.named(sql),
      parameters: parameters ?? {},
    );
  }

  /// Execute a query and return the first row, or null.
  Future<ResultRow?> queryOneNamed(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    final result = await queryNamed(sql, parameters: parameters);
    return result.isEmpty ? null : result.first;
  }
}

/// Error thrown when database operations fail.
class DatabaseError implements Exception {
  final String message;

  DatabaseError(this.message);

  @override
  String toString() => 'DatabaseError: $message';
}
