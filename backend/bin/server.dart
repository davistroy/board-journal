import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../lib/config/config.dart';
import '../lib/db/database.dart';
import '../lib/db/queries.dart';
import '../lib/routes/routes.dart';
import '../lib/services/jwt_service.dart';
import '../lib/services/sync_service.dart';

/// Boardroom Journal Backend Server
///
/// Usage:
///   dart run bin/server.dart
///
/// Environment variables:
///   - HOST: Server host (default: 0.0.0.0)
///   - PORT: Server port (default: 8080)
///   - DATABASE_HOST: PostgreSQL host
///   - DATABASE_PORT: PostgreSQL port (default: 5432)
///   - DATABASE_NAME: Database name
///   - DATABASE_USER: Database user
///   - DATABASE_PASSWORD: Database password (required)
///   - JWT_SECRET: Secret for JWT signing (required)
///   - See config.dart for all options
void main() async {
  // Load configuration
  Config config;
  try {
    config = Config.instance;
  } on ConfigurationError catch (e) {
    stderr.writeln('Configuration error: ${e.message}');
    stderr.writeln('');
    stderr.writeln('Required environment variables:');
    stderr.writeln('  - DATABASE_PASSWORD');
    stderr.writeln('  - JWT_SECRET');
    stderr.writeln('');
    stderr.writeln('See config.dart for all configuration options.');
    exit(1);
  }

  print('Starting Boardroom Journal Backend...');
  print('Environment: ${config.environment}');

  // Initialize database
  Database db;
  try {
    print('Connecting to database at ${config.databaseHost}:${config.databasePort}...');
    db = await Database.initialize(config);
    print('Database connected successfully.');
  } catch (e) {
    stderr.writeln('Database connection failed: $e');
    exit(1);
  }

  // Initialize services
  final queries = Queries(db);
  final jwtService = JwtService(config);
  final syncService = SyncService(db, queries);

  // Build router
  final handler = buildRouter(
    config: config,
    db: db,
    queries: queries,
    jwtService: jwtService,
    syncService: syncService,
  );

  // Start server
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );

  // Enable compression
  server.autoCompress = true;

  print('');
  print('Server running on http://${server.address.host}:${server.port}');
  print('');
  print('Endpoints:');
  print('  Health:    GET  /health');
  print('  Version:   GET  /version');
  print('  Auth:      POST /auth/oauth/{provider}');
  print('             POST /auth/refresh');
  print('             GET  /auth/session');
  print('  Sync:      GET  /sync?since={timestamp}');
  print('             POST /sync');
  print('             GET  /sync/full');
  print('  Account:   GET  /account');
  print('             DELETE /account');
  print('             GET  /account/export');
  print('  AI:        POST /ai/transcribe');
  print('             POST /ai/extract');
  print('             POST /ai/generate');
  print('');

  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await db.close();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    print('\nShutting down...');
    await db.close();
    exit(0);
  });

  print('Press Ctrl+C to stop.');
}
