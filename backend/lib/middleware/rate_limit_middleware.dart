import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../config/config.dart';
import '../db/queries.dart';
import '../models/api_models.dart';

/// Middleware for rate limiting.
///
/// Per PRD Section 3D:
/// - 3 accounts/IP/hour for account creation
/// - 5 failed auth attempts = 15-minute lockout
class RateLimitMiddleware {
  final Queries _queries;
  final Config _config;

  RateLimitMiddleware(this._queries, this._config);

  /// Rate limit for authentication attempts.
  ///
  /// Tracks failed login attempts and enforces lockout.
  Middleware authRateLimit() {
    return (Handler innerHandler) {
      return (Request request) async {
        final ip = _getClientIp(request);

        try {
          final rateLimit = await _queries.getAuthRateLimit(ip);
          final lockoutUntil = rateLimit['lockout_until_utc'] as DateTime?;

          // Check if currently locked out
          if (lockoutUntil != null && lockoutUntil.isAfter(DateTime.now().toUtc())) {
            final retryAfter = lockoutUntil.difference(DateTime.now().toUtc());
            return _rateLimitedResponse(
              'Too many failed login attempts. Please try again later.',
              retryAfter: retryAfter,
            );
          }

          // Process the request
          final response = await innerHandler(request);

          // If auth failed (401), increment attempt count
          if (response.statusCode == 401) {
            await _queries.incrementAuthAttempt(ip);

            // Check if we need to lock out
            final updatedLimit = await _queries.getAuthRateLimit(ip);
            final attempts = updatedLimit['attempt_count'] as int;

            if (attempts >= _config.rateLimitAuthAttemptsBeforeLockout) {
              final lockoutUntil =
                  DateTime.now().toUtc().add(_config.rateLimitAuthLockoutDuration);
              await _queries.setAuthLockout(ip, lockoutUntil);
            }
          } else if (response.statusCode == 200) {
            // Reset on successful auth
            await _queries.resetAuthRateLimit(ip);
          }

          return response;
        } catch (e) {
          // If rate limiting fails, allow the request through
          // (fail open to avoid blocking legitimate users)
          return await innerHandler(request);
        }
      };
    };
  }

  /// Rate limit for account creation.
  ///
  /// Limits new accounts per IP address per hour.
  Middleware accountCreationRateLimit() {
    return (Handler innerHandler) {
      return (Request request) async {
        final ip = _getClientIp(request);

        try {
          final rateLimit = await _queries.getAccountCreationRateLimit(ip);

          if (rateLimit != null) {
            final count = rateLimit['account_count'] as int;

            if (count >= _config.rateLimitAccountCreationPerHour) {
              final windowStart = rateLimit['window_start_utc'] as DateTime;
              final windowEnd = windowStart.add(const Duration(hours: 1));
              final retryAfter = windowEnd.difference(DateTime.now().toUtc());

              return _rateLimitedResponse(
                'Account creation limit reached. Please try again later.',
                retryAfter: retryAfter,
              );
            }
          }

          // Process the request
          final response = await innerHandler(request);

          // If account was created successfully, increment count
          if (response.statusCode == 200 || response.statusCode == 201) {
            await _queries.incrementAccountCreation(ip);
          }

          return response;
        } catch (e) {
          // Fail open
          return await innerHandler(request);
        }
      };
    };
  }

  /// Generic rate limit middleware.
  ///
  /// Simple in-memory rate limiting for general endpoints.
  /// For production, use Redis or similar.
  Middleware generalRateLimit({
    required int maxRequests,
    required Duration window,
  }) {
    // Simple in-memory store (not suitable for multi-instance deployments)
    final _requests = <String, List<DateTime>>{};

    return (Handler innerHandler) {
      return (Request request) async {
        final ip = _getClientIp(request);
        final now = DateTime.now().toUtc();
        final windowStart = now.subtract(window);

        // Get requests within window
        final requests = _requests[ip] ?? [];
        final recentRequests =
            requests.where((t) => t.isAfter(windowStart)).toList();

        if (recentRequests.length >= maxRequests) {
          final oldestInWindow = recentRequests.first;
          final retryAfter = window - now.difference(oldestInWindow);

          return _rateLimitedResponse(
            'Rate limit exceeded',
            retryAfter: retryAfter,
          );
        }

        // Record this request
        recentRequests.add(now);
        _requests[ip] = recentRequests;

        return await innerHandler(request);
      };
    };
  }

  /// Get client IP address from request.
  String _getClientIp(Request request) {
    // Check for forwarded headers (when behind proxy/load balancer)
    final forwarded = request.headers['X-Forwarded-For'];
    if (forwarded != null) {
      // Take the first IP in the chain (original client)
      return forwarded.split(',').first.trim();
    }

    final realIp = request.headers['X-Real-IP'];
    if (realIp != null) {
      return realIp;
    }

    // Fallback to connection info (not available in shelf)
    // In production, ensure your proxy sets X-Forwarded-For
    return 'unknown';
  }

  Response _rateLimitedResponse(String message, {Duration? retryAfter}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (retryAfter != null && retryAfter.inSeconds > 0) {
      headers['Retry-After'] = retryAfter.inSeconds.toString();
    }

    return Response(
      429,
      body: jsonEncode(
        ApiError.rateLimited(message, retryAfter: retryAfter).toJson(),
      ),
      headers: headers,
    );
  }
}

/// Extension to get client IP from request context.
extension RequestIpExtension on Request {
  /// Get the client IP address.
  String get clientIp {
    final forwarded = headers['X-Forwarded-For'];
    if (forwarded != null) {
      return forwarded.split(',').first.trim();
    }
    return headers['X-Real-IP'] ?? 'unknown';
  }
}
