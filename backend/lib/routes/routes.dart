import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/config.dart';
import '../db/database.dart';
import '../db/queries.dart';
import '../middleware/middleware.dart';
import '../services/jwt_service.dart';
import '../services/sync_service.dart';
import 'account_routes.dart';
import 'ai_routes.dart';
import 'auth_routes.dart';
import 'sync_routes.dart';

export 'account_routes.dart';
export 'ai_routes.dart';
export 'auth_routes.dart';
export 'sync_routes.dart';

/// Build the main application router with all routes and middleware.
Handler buildRouter({
  required Config config,
  required Database db,
  required Queries queries,
  required JwtService jwtService,
  required SyncService syncService,
  http.Client? httpClient,
}) {
  // Create middleware
  final authMiddleware = AuthMiddleware(jwtService);
  final rateLimitMiddleware = RateLimitMiddleware(queries, config);
  final commonMiddleware = CommonMiddleware(config);

  // Create route handlers
  final authRoutes = AuthRoutes(config, jwtService, queries);
  final syncRoutes = SyncRoutes(syncService);
  final accountRoutes = AccountRoutes(db, queries);
  final aiRoutes = AiRoutes(config, httpClient);

  // Build main router
  final router = Router();

  // Health check endpoint (no auth required)
  router.get('/health', (Request request) {
    return Response.ok(
      '{"status":"healthy","timestamp":"${DateTime.now().toUtc().toIso8601String()}"}',
      headers: {'Content-Type': 'application/json'},
    );
  });

  // API version endpoint
  router.get('/version', (Request request) {
    return Response.ok(
      '{"version":"1.0.0","api_version":"v1"}',
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Auth routes (with rate limiting)
  final authHandler = Pipeline()
      .addMiddleware(rateLimitMiddleware.authRateLimit())
      .addHandler(authRoutes.router.call);

  // Session validation requires auth
  final sessionHandler = Pipeline()
      .addMiddleware(authMiddleware.requireAuth())
      .addHandler((Request request) {
    // Forward to auth routes for session handling
    return authRoutes.router.call(request);
  });

  router.mount('/auth', (Request request) {
    // Session endpoint requires auth
    if (request.url.path == 'session' && request.method == 'GET') {
      return sessionHandler(request);
    }
    return authHandler(request);
  });

  // Sync routes (auth required)
  final syncHandler = Pipeline()
      .addMiddleware(authMiddleware.requireAuth())
      .addHandler(syncRoutes.router.call);

  router.mount('/sync', syncHandler);

  // Account routes (auth required)
  final accountHandler = Pipeline()
      .addMiddleware(authMiddleware.requireAuth())
      .addHandler(accountRoutes.router.call);

  router.mount('/account', accountHandler);

  // AI routes (auth required, with rate limiting)
  final aiHandler = Pipeline()
      .addMiddleware(authMiddleware.requireAuth())
      .addMiddleware(rateLimitMiddleware.generalRateLimit(
        maxRequests: 100,
        window: const Duration(minutes: 1),
      ))
      .addHandler(aiRoutes.router.call);

  router.mount('/ai', aiHandler);

  // 404 handler
  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound(
      '{"error":{"code":"NOT_FOUND","message":"Endpoint not found"}}',
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Build full pipeline with common middleware
  return buildMiddlewarePipeline(commonMiddleware).addHandler(router.call);
}
