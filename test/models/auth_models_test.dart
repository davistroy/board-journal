import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/models/auth_models.dart';

void main() {
  group('AuthStatus', () {
    test('has all expected values', () {
      expect(AuthStatus.values, contains(AuthStatus.initial));
      expect(AuthStatus.values, contains(AuthStatus.loading));
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
      expect(AuthStatus.values, contains(AuthStatus.unauthenticated));
      expect(AuthStatus.values, contains(AuthStatus.error));
    });
  });

  group('AuthProvider', () {
    test('has all expected values', () {
      expect(AuthProvider.values, contains(AuthProvider.apple));
      expect(AuthProvider.values, contains(AuthProvider.google));
      expect(AuthProvider.values, contains(AuthProvider.microsoft));
      expect(AuthProvider.values, contains(AuthProvider.localOnly));
    });
  });

  group('AppUser', () {
    test('creates user with required fields', () {
      final now = DateTime.now();
      final user = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        provider: AuthProvider.google,
        createdAt: now,
      );

      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.provider, AuthProvider.google);
      expect(user.createdAt, now);
    });

    test('localOnly factory creates local user', () {
      final user = AppUser.localOnly();

      expect(user.id, 'local-user');
      expect(user.email, isNull);
      expect(user.name, 'Local User');
      expect(user.provider, AuthProvider.localOnly);
    });

    test('fromJson creates user from map', () {
      final json = {
        'id': 'user-456',
        'email': 'json@example.com',
        'name': 'JSON User',
        'provider': 'apple',
        'createdAt': '2026-01-10T12:00:00.000Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, 'user-456');
      expect(user.email, 'json@example.com');
      expect(user.name, 'JSON User');
      expect(user.provider, AuthProvider.apple);
    });

    test('fromJson handles unknown provider', () {
      final json = {
        'id': 'user-789',
        'email': null,
        'name': null,
        'provider': 'unknown',
        'createdAt': '2026-01-10T12:00:00.000Z',
      };

      final user = AppUser.fromJson(json);

      expect(user.provider, AuthProvider.localOnly);
    });

    test('toJson converts user to map', () {
      final now = DateTime.utc(2026, 1, 10, 12, 0, 0);
      final user = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        provider: AuthProvider.microsoft,
        createdAt: now,
      );

      final json = user.toJson();

      expect(json['id'], 'user-123');
      expect(json['email'], 'test@example.com');
      expect(json['name'], 'Test User');
      expect(json['provider'], 'microsoft');
      expect(json['createdAt'], now.toIso8601String());
    });

    test('equality works correctly', () {
      final now = DateTime.now();
      final user1 = AppUser(
        id: 'same-id',
        provider: AuthProvider.google,
        createdAt: now,
      );
      final user2 = AppUser(
        id: 'same-id',
        provider: AuthProvider.google,
        createdAt: now,
      );

      expect(user1, equals(user2));
    });
  });

  group('AuthState', () {
    test('initial factory creates initial state', () {
      final state = AuthState.initial();

      expect(state.status, AuthStatus.initial);
      expect(state.user, isNull);
      expect(state.errorMessage, isNull);
      expect(state.onboardingCompleted, isFalse);
    });

    test('loading factory creates loading state', () {
      final state = AuthState.loading();

      expect(state.status, AuthStatus.loading);
    });

    test('authenticated factory creates authenticated state', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(user: user);

      expect(state.status, AuthStatus.authenticated);
      expect(state.user, user);
      expect(state.onboardingCompleted, isTrue);
    });

    test('authenticated factory with onboardingCompleted false', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(
        user: user,
        onboardingCompleted: false,
      );

      expect(state.onboardingCompleted, isFalse);
    });

    test('unauthenticated factory creates unauthenticated state', () {
      final state = AuthState.unauthenticated();

      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(state.onboardingCompleted, isFalse);
    });

    test('error factory creates error state', () {
      final state = AuthState.error('Something went wrong');

      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, 'Something went wrong');
    });

    test('isAuthenticated returns true when authenticated with user', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(user: user);

      expect(state.isAuthenticated, isTrue);
    });

    test('isAuthenticated returns false when unauthenticated', () {
      final state = AuthState.unauthenticated();

      expect(state.isAuthenticated, isFalse);
    });

    test('isLocalOnly returns true for local-only user', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(user: user);

      expect(state.isLocalOnly, isTrue);
    });

    test('isLocalOnly returns false for OAuth user', () {
      final user = AppUser(
        id: 'oauth-user',
        provider: AuthProvider.google,
        createdAt: DateTime.now(),
      );
      final state = AuthState.authenticated(user: user);

      expect(state.isLocalOnly, isFalse);
    });

    test('copyWith preserves values', () {
      final user = AppUser.localOnly();
      final original = AuthState.authenticated(user: user);

      final copied = original.copyWith(
        onboardingCompleted: false,
      );

      expect(copied.status, AuthStatus.authenticated);
      expect(copied.user, user);
      expect(copied.onboardingCompleted, isFalse);
    });
  });

  group('AuthTokens', () {
    test('creates tokens with required fields', () {
      final accessExpiry = DateTime.now().add(const Duration(minutes: 15));
      final refreshExpiry = DateTime.now().add(const Duration(days: 30));

      final tokens = AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        accessTokenExpiry: accessExpiry,
        refreshTokenExpiry: refreshExpiry,
      );

      expect(tokens.accessToken, 'access-token');
      expect(tokens.refreshToken, 'refresh-token');
      expect(tokens.accessTokenExpiry, accessExpiry);
      expect(tokens.refreshTokenExpiry, refreshExpiry);
    });

    test('fromJson creates tokens from map', () {
      final json = {
        'accessToken': 'access-from-json',
        'refreshToken': 'refresh-from-json',
        'accessTokenExpiry': '2026-01-10T12:15:00.000Z',
        'refreshTokenExpiry': '2026-02-09T12:00:00.000Z',
      };

      final tokens = AuthTokens.fromJson(json);

      expect(tokens.accessToken, 'access-from-json');
      expect(tokens.refreshToken, 'refresh-from-json');
    });

    test('toJson converts tokens to map', () {
      final accessExpiry = DateTime.utc(2026, 1, 10, 12, 15);
      final refreshExpiry = DateTime.utc(2026, 2, 9, 12, 0);

      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiry: accessExpiry,
        refreshTokenExpiry: refreshExpiry,
      );

      final json = tokens.toJson();

      expect(json['accessToken'], 'access');
      expect(json['refreshToken'], 'refresh');
      expect(json['accessTokenExpiry'], accessExpiry.toIso8601String());
      expect(json['refreshTokenExpiry'], refreshExpiry.toIso8601String());
    });

    test('isAccessTokenExpired returns true when expired', () {
      final tokens = AuthTokens(
        accessToken: 'expired',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 1)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpired returns false when valid', () {
      final tokens = AuthTokens(
        accessToken: 'valid',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.isAccessTokenExpired, isFalse);
    });

    test('isRefreshTokenExpired returns true when expired', () {
      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'expired',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
        refreshTokenExpiry: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(tokens.isRefreshTokenExpired, isTrue);
    });

    test('needsProactiveRefresh returns true when less than 5 min remaining', () {
      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 3)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.needsProactiveRefresh, isTrue);
    });

    test('needsProactiveRefresh returns false when more than 5 min remaining', () {
      final tokens = AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.needsProactiveRefresh, isFalse);
    });

    test('accessTokenTimeRemaining returns Duration.zero when expired', () {
      final tokens = AuthTokens(
        accessToken: 'expired',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 5)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.accessTokenTimeRemaining, Duration.zero);
    });

    test('accessTokenTimeRemaining returns remaining duration', () {
      final tokens = AuthTokens(
        accessToken: 'valid',
        refreshToken: 'refresh',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.accessTokenTimeRemaining.inMinutes, greaterThanOrEqualTo(9));
    });
  });
}
