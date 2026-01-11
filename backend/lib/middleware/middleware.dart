import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import '../config/config.dart';
import '../models/api_models.dart';

export 'auth_middleware.dart';
export 'rate_limit_middleware.dart';

/// Common middleware for the application.
class CommonMiddleware {
  final Config _config;

  CommonMiddleware(this._config);

  /// Request body size limit middleware.
  ///
  /// Per PRD Section 3D: max 10MB requests.
  Middleware bodyLimit() {
    return (Handler innerHandler) {
      return (Request request) async {
        final contentLength = request.headers['Content-Length'];

        if (contentLength != null) {
          final size = int.tryParse(contentLength) ?? 0;
          if (size > _config.maxRequestBodySize) {
            return Response(
              413,
              body: jsonEncode(
                ApiError.badRequest(
                  'Request body too large. Maximum size: ${_config.maxRequestBodySize ~/ 1024 ~/ 1024}MB',
                ).toJson(),
              ),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return await innerHandler(request);
      };
    };
  }

  /// Error handling middleware.
  Middleware errorHandler() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request);
        } on FormatException catch (e) {
          return Response(
            400,
            body: jsonEncode(ApiError.badRequest('Invalid JSON: ${e.message}').toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } on HttpException catch (e) {
          return Response(
            400,
            body: jsonEncode(ApiError.badRequest(e.message).toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e, stackTrace) {
          // Log error in production
          if (_config.isProduction) {
            stderr.writeln('Unhandled error: $e');
            stderr.writeln(stackTrace);
          } else {
            print('Unhandled error: $e');
            print(stackTrace);
          }

          return Response(
            500,
            body: jsonEncode(ApiError.serverError().toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        }
      };
    };
  }

  /// JSON content type validation middleware.
  Middleware requireJson() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Skip for GET, DELETE, HEAD, OPTIONS
        final method = request.method.toUpperCase();
        if (['GET', 'DELETE', 'HEAD', 'OPTIONS'].contains(method)) {
          return await innerHandler(request);
        }

        final contentType = request.headers['Content-Type'];
        if (contentType == null || !contentType.contains('application/json')) {
          return Response(
            415,
            body: jsonEncode(
              ApiError.badRequest('Content-Type must be application/json').toJson(),
            ),
            headers: {'Content-Type': 'application/json'},
          );
        }

        return await innerHandler(request);
      };
    };
  }

  /// Request logging middleware.
  Middleware requestLogging() {
    return (Handler innerHandler) {
      return (Request request) async {
        final stopwatch = Stopwatch()..start();
        final response = await innerHandler(request);
        stopwatch.stop();

        final logLine = [
          DateTime.now().toIso8601String(),
          request.method,
          request.requestedUri.path,
          response.statusCode,
          '${stopwatch.elapsedMilliseconds}ms',
        ].join(' | ');

        if (_config.isDevelopment) {
          print(logLine);
        }

        return response;
      };
    };
  }

  /// Security headers middleware.
  Middleware securityHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);

        return response.change(headers: {
          ...response.headers,
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'X-XSS-Protection': '1; mode=block',
          'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
          'Cache-Control': 'no-store',
        });
      };
    };
  }

  /// CORS middleware with appropriate settings.
  Middleware cors() {
    if (_config.isDevelopment) {
      // Allow all origins in development
      return corsHeaders();
    }

    // Restrict origins in production
    return corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: 'https://boardroomjournal.app',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Authorization, Content-Type',
        ACCESS_CONTROL_MAX_AGE: '86400',
      },
    );
  }
}

/// Build the middleware pipeline.
Pipeline buildMiddlewarePipeline(CommonMiddleware common) {
  return Pipeline()
      .addMiddleware(common.cors())
      .addMiddleware(common.securityHeaders())
      .addMiddleware(common.requestLogging())
      .addMiddleware(common.errorHandler())
      .addMiddleware(common.bodyLimit())
      .addMiddleware(common.requireJson());
}
