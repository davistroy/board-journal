import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../../lib/config/config.dart';
import '../../lib/middleware/auth_middleware.dart';
import '../../lib/services/jwt_service.dart';

void main() {
  late Config config;
  late JwtService jwtService;
  late AuthMiddleware authMiddleware;

  setUp(() {
    config = Config.forTesting();
    jwtService = JwtService(config);
    authMiddleware = AuthMiddleware(jwtService);
  });

  tearDown(() {
    Config.reset();
  });

  group('AuthMiddleware', () {
    group('requireAuth', () {
      test('returns 401 when Authorization header is missing', () async {
        final handler = authMiddleware.requireAuth()(
          (request) => Response.ok('Success'),
        );

        final request = Request('GET', Uri.parse('http://localhost/test'));
        final response = await handler(request);

        expect(response.statusCode, equals(401));

        final body = jsonDecode(await response.readAsString());
        expect(body['error']['code'], equals('UNAUTHORIZED'));
      });

      test('returns 401 when Authorization header is not Bearer', () async {
        final handler = authMiddleware.requireAuth()(
          (request) => Response.ok('Success'),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Basic token'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 when token is invalid', () async {
        final handler = authMiddleware.requireAuth()(
          (request) => Response.ok('Success'),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Bearer invalid_token'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(401));
      });

      test('returns 401 when token is expired', () async {
        // Create an expired token
        final expiredToken = jwtService.createAccessToken(
          userId: 'test-user-id',
          email: 'test@example.com',
          expiry: const Duration(seconds: -1), // Already expired
        );

        final handler = authMiddleware.requireAuth()(
          (request) => Response.ok('Success'),
        );

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Bearer $expiredToken'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(401));

        final body = jsonDecode(await response.readAsString());
        expect(body['error']['message'], contains('expired'));
      });

      test('passes request to handler when token is valid', () async {
        final validToken = jwtService.createAccessToken(
          userId: 'test-user-id',
          email: 'test@example.com',
        );

        final handler = authMiddleware.requireAuth()((request) {
          // Verify user info is in context
          expect(request.context['userId'], equals('test-user-id'));
          expect(request.context['userEmail'], equals('test@example.com'));
          return Response.ok('Success');
        });

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Bearer $validToken'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(200));
        expect(await response.readAsString(), equals('Success'));
      });
    });

    group('optionalAuth', () {
      test('proceeds without auth when header is missing', () async {
        final handler = authMiddleware.optionalAuth()((request) {
          expect(request.context['isAuthenticated'], isFalse);
          return Response.ok('Success');
        });

        final request = Request('GET', Uri.parse('http://localhost/test'));
        final response = await handler(request);

        expect(response.statusCode, equals(200));
      });

      test('proceeds without auth when token is invalid', () async {
        final handler = authMiddleware.optionalAuth()((request) {
          expect(request.context['isAuthenticated'], isFalse);
          return Response.ok('Success');
        });

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Bearer invalid'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(200));
      });

      test('extracts user info when token is valid', () async {
        final validToken = jwtService.createAccessToken(
          userId: 'test-user-id',
          email: 'test@example.com',
        );

        final handler = authMiddleware.optionalAuth()((request) {
          expect(request.context['isAuthenticated'], isTrue);
          expect(request.context['userId'], equals('test-user-id'));
          expect(request.context['userEmail'], equals('test@example.com'));
          return Response.ok('Success');
        });

        final request = Request(
          'GET',
          Uri.parse('http://localhost/test'),
          headers: {'Authorization': 'Bearer $validToken'},
        );
        final response = await handler(request);

        expect(response.statusCode, equals(200));
      });
    });
  });

  group('RequestAuthExtension', () {
    test('userId returns null when not authenticated', () async {
      final handler = authMiddleware.optionalAuth()((request) {
        expect(request.userId, isNull);
        return Response.ok('Success');
      });

      final request = Request('GET', Uri.parse('http://localhost/test'));
      await handler(request);
    });

    test('userId returns user ID when authenticated', () async {
      final validToken = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
      );

      final handler = authMiddleware.requireAuth()((request) {
        expect(request.userId, equals('test-user-id'));
        return Response.ok('Success');
      });

      final request = Request(
        'GET',
        Uri.parse('http://localhost/test'),
        headers: {'Authorization': 'Bearer $validToken'},
      );
      await handler(request);
    });

    test('requiredUserId throws when not authenticated', () async {
      final handler = authMiddleware.optionalAuth()((request) {
        expect(() => request.requiredUserId, throwsStateError);
        return Response.ok('Success');
      });

      final request = Request('GET', Uri.parse('http://localhost/test'));
      await handler(request);
    });
  });
}
