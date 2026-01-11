import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../models/api_models.dart';
import '../services/jwt_service.dart';

/// Middleware for JWT authentication.
///
/// Validates the Authorization header and extracts user information.
/// Sets 'userId' and 'userEmail' in the request context.
class AuthMiddleware {
  final JwtService _jwtService;

  AuthMiddleware(this._jwtService);

  /// Create middleware that requires authentication.
  Middleware requireAuth() {
    return (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['Authorization'];

        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return _unauthorizedResponse('Missing or invalid Authorization header');
        }

        final token = authHeader.substring(7); // Remove 'Bearer ' prefix

        try {
          final payload = _jwtService.validateAccessToken(token);

          // Add user info to request context
          final updatedRequest = request.change(context: {
            ...request.context,
            'userId': payload.userId,
            'userEmail': payload.email,
            'tokenExpiresAt': payload.expiresAt,
          });

          return await innerHandler(updatedRequest);
        } on JwtValidationError catch (e) {
          return _unauthorizedResponse(e.message);
        } catch (e) {
          return _unauthorizedResponse('Token validation failed');
        }
      };
    };
  }

  /// Create middleware that optionally extracts auth info.
  ///
  /// Does not require authentication but will extract user info if present.
  Middleware optionalAuth() {
    return (Handler innerHandler) {
      return (Request request) async {
        final authHeader = request.headers['Authorization'];

        if (authHeader != null && authHeader.startsWith('Bearer ')) {
          final token = authHeader.substring(7);

          try {
            final payload = _jwtService.validateAccessToken(token);

            final updatedRequest = request.change(context: {
              ...request.context,
              'userId': payload.userId,
              'userEmail': payload.email,
              'tokenExpiresAt': payload.expiresAt,
              'isAuthenticated': true,
            });

            return await innerHandler(updatedRequest);
          } catch (_) {
            // Token invalid, continue without auth
          }
        }

        final updatedRequest = request.change(context: {
          ...request.context,
          'isAuthenticated': false,
        });

        return await innerHandler(updatedRequest);
      };
    };
  }

  Response _unauthorizedResponse(String message) {
    return Response(
      401,
      body: jsonEncode(ApiError.unauthorized(message).toJson()),
      headers: {
        'Content-Type': 'application/json',
        'WWW-Authenticate': 'Bearer',
      },
    );
  }
}

/// Extension to easily get user info from request context.
extension RequestAuthExtension on Request {
  /// Get the authenticated user's ID.
  String? get userId => context['userId'] as String?;

  /// Get the authenticated user's email.
  String? get userEmail => context['userEmail'] as String?;

  /// Check if the request is authenticated.
  bool get isAuthenticated =>
      context['isAuthenticated'] as bool? ??
      context['userId'] != null;

  /// Get the token expiration time.
  DateTime? get tokenExpiresAt => context['tokenExpiresAt'] as DateTime?;

  /// Require the user ID (throws if not authenticated).
  String get requiredUserId {
    final id = userId;
    if (id == null) {
      throw StateError('Request is not authenticated');
    }
    return id;
  }
}
