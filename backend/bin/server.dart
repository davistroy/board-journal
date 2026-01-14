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

  stdout.writeln('Starting Boardroom Journal Backend...');
  stdout.writeln('Environment: ${config.environment}');

  // Initialize database
  Database db;
  try {
    stdout.writeln('Connecting to database at ${config.databaseHost}:${config.databasePort}...');
    db = await Database.initialize(config);
    stdout.writeln('Database connected successfully.');
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

  stdout.writeln('');
  stdout.writeln('Server running on http://${server.address.host}:${server.port}');
  stdout.writeln('');
  stdout.writeln('Endpoints:');
  stdout.writeln('  Health:    GET  /health');
  stdout.writeln('  Version:   GET  /version');
  stdout.writeln('  Auth:      POST /auth/oauth/{provider}');
  stdout.writeln('             POST /auth/refresh');
  stdout.writeln('             GET  /auth/session');
  stdout.writeln('  Sync:      GET  /sync?since={timestamp}');
  stdout.writeln('             POST /sync');
  stdout.writeln('             GET  /sync/full');
  stdout.writeln('  Account:   GET  /account');
  stdout.writeln('             DELETE /account');
  stdout.writeln('             GET  /account/export');
  stdout.writeln('  AI:        POST /ai/transcribe');
  stdout.writeln('             POST /ai/extract');
  stdout.writeln('             POST /ai/generate');
  stdout.writeln('');

  // Handle shutdown signals
  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down...');
    await db.close();
    exit(0);
  });

  ProcessSignal.sigterm.watch().listen((_) async {
    stdout.writeln('\nShutting down...');
    await db.close();
    exit(0);
  });

  stdout.writeln('Press Ctrl+C to stop.');
}
