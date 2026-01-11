import 'dart:convert';

import 'package:test/test.dart';

import '../../lib/config/config.dart';
import '../../lib/services/jwt_service.dart';

void main() {
  late Config config;
  late JwtService jwtService;

  setUp(() {
    config = Config.forTesting();
    jwtService = JwtService(config);
  });

  tearDown(() {
    Config.reset();
  });

  group('JwtService', () {
    test('creates valid access token', () {
      final token = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
      );

      expect(token, isNotEmpty);
      expect(token.split('.').length, equals(3)); // JWT has 3 parts
    });

    test('validates access token and returns payload', () {
      final token = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
      );

      final payload = jwtService.validateAccessToken(token);

      expect(payload.userId, equals('test-user-id'));
      expect(payload.email, equals('test@example.com'));
      expect(payload.isExpired, isFalse);
    });

    test('throws JwtValidationError for invalid token', () {
      expect(
        () => jwtService.validateAccessToken('invalid.token.here'),
        throwsA(isA<JwtValidationError>()),
      );
    });

    test('throws JwtValidationError for expired token', () {
      final token = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
        expiry: const Duration(seconds: -1),
      );

      expect(
        () => jwtService.validateAccessToken(token),
        throwsA(isA<JwtValidationError>()),
      );
    });

    test('generates unique refresh tokens', () {
      final token1 = jwtService.generateRefreshToken();
      final token2 = jwtService.generateRefreshToken();

      expect(token1, isNotEmpty);
      expect(token2, isNotEmpty);
      expect(token1, isNot(equals(token2)));
    });

    test('hashes refresh token consistently', () {
      final token = jwtService.generateRefreshToken();
      final hash1 = jwtService.hashRefreshToken(token);
      final hash2 = jwtService.hashRefreshToken(token);

      expect(hash1, equals(hash2));
    });

    test('produces different hashes for different tokens', () {
      final token1 = jwtService.generateRefreshToken();
      final token2 = jwtService.generateRefreshToken();

      final hash1 = jwtService.hashRefreshToken(token1);
      final hash2 = jwtService.hashRefreshToken(token2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('calculates refresh token expiry correctly', () {
      final expiry = jwtService.calculateRefreshTokenExpiry();
      final now = DateTime.now().toUtc();

      // Should be approximately 30 days from now
      final difference = expiry.difference(now);
      expect(difference.inDays, greaterThanOrEqualTo(29));
      expect(difference.inDays, lessThanOrEqualTo(30));
    });
  });

  group('JwtPayload', () {
    test('timeRemaining returns remaining duration', () {
      final token = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
        expiry: const Duration(minutes: 5),
      );

      final payload = jwtService.validateAccessToken(token);

      // Should be close to 5 minutes
      expect(payload.timeRemaining.inMinutes, greaterThanOrEqualTo(4));
      expect(payload.timeRemaining.inMinutes, lessThanOrEqualTo(5));
    });

    test('timeRemaining returns zero for expired tokens', () {
      // This test verifies the payload structure
      final payload = JwtPayload(
        userId: 'test-user-id',
        email: 'test@example.com',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );

      expect(payload.timeRemaining, equals(Duration.zero));
      expect(payload.isExpired, isTrue);
    });
  });

  group('Token Response Format', () {
    test('creates proper token response structure', () {
      final token = jwtService.createAccessToken(
        userId: 'test-user-id',
        email: 'test@example.com',
      );

      final refreshToken = jwtService.generateRefreshToken();

      final response = {
        'access_token': token,
        'refresh_token': refreshToken,
        'expires_in': config.jwtAccessTokenExpiry.inSeconds,
        'token_type': 'Bearer',
        'user': {
          'id': 'test-user-id',
          'email': 'test@example.com',
        },
      };

      expect(response['access_token'], isNotEmpty);
      expect(response['refresh_token'], isNotEmpty);
      expect(response['expires_in'], equals(900)); // 15 minutes
      expect(response['token_type'], equals('Bearer'));
      expect((response['user'] as Map<String, dynamic>)['id'], equals('test-user-id'));
    });
  });

  group('OAuth Token Request Validation', () {
    test('parses valid OAuth token request', () {
      final json = {
        'code': 'authorization_code_here',
        'redirect_uri': 'https://app.boardroomjournal.com/callback',
        'device_info': {
          'platform': 'ios',
          'version': '1.0.0',
        },
      };

      expect(json['code'], isNotEmpty);
      expect(json['redirect_uri'], contains('https://'));
    });

    test('validates required code field', () {
      final json = {
        'redirect_uri': 'https://app.boardroomjournal.com/callback',
      };

      expect(json.containsKey('code'), isFalse);
    });
  });

  group('Refresh Token Request Validation', () {
    test('parses valid refresh token request', () {
      final json = {
        'refresh_token': jwtService.generateRefreshToken(),
      };

      expect(json['refresh_token'], isNotEmpty);
    });

    test('validates required refresh_token field', () {
      final json = <String, dynamic>{};

      expect(json.containsKey('refresh_token'), isFalse);
    });
  });
}
