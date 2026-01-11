import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/models/models.dart';
import 'package:boardroom_journal/services/auth/auth_service.dart';
import 'package:boardroom_journal/services/auth/token_storage.dart';

/// Mock implementation of FlutterSecureStorage for testing.
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map.from(_storage);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  // Not used in tests but required by interface
  @override
  IOSOptions get iOptions => const IOSOptions();

  @override
  AndroidOptions get aOptions => const AndroidOptions();

  @override
  LinuxOptions get lOptions => const LinuxOptions();

  @override
  MacOsOptions get mOptions => const MacOsOptions();

  @override
  WindowsOptions get wOptions => const WindowsOptions();

  @override
  WebOptions get webOptions => const WebOptions();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;

  @override
  void registerListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required void Function(String?) listener,
  }) {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  void unregisterAllListeners() {}

  void clear() => _storage.clear();
}

void main() {
  group('TokenStorage', () {
    late MockSecureStorage mockStorage;
    late TokenStorage tokenStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      tokenStorage = TokenStorage(storage: mockStorage);
    });

    group('saveTokens and getTokens', () {
      test('should save and retrieve tokens', () async {
        final tokens = AuthTokens(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final retrieved = await tokenStorage.getTokens();

        expect(retrieved, isNotNull);
        expect(retrieved!.accessToken, equals(tokens.accessToken));
        expect(retrieved.refreshToken, equals(tokens.refreshToken));
      });

      test('should return null when no tokens stored', () async {
        final tokens = await tokenStorage.getTokens();
        expect(tokens, isNull);
      });
    });

    group('getAccessToken', () {
      test('should return access token when stored', () async {
        final tokens = AuthTokens(
          accessToken: 'my-access-token',
          refreshToken: 'my-refresh-token',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final accessToken = await tokenStorage.getAccessToken();

        expect(accessToken, equals('my-access-token'));
      });

      test('should return null when no token stored', () async {
        final accessToken = await tokenStorage.getAccessToken();
        expect(accessToken, isNull);
      });
    });

    group('getRefreshToken', () {
      test('should return refresh token when stored', () async {
        final tokens = AuthTokens(
          accessToken: 'my-access-token',
          refreshToken: 'my-refresh-token',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final refreshToken = await tokenStorage.getRefreshToken();

        expect(refreshToken, equals('my-refresh-token'));
      });
    });

    group('isAccessTokenExpired', () {
      test('should return true when no token stored', () async {
        final expired = await tokenStorage.isAccessTokenExpired();
        expect(expired, isTrue);
      });

      test('should return true when token is expired', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 1)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final expired = await tokenStorage.isAccessTokenExpired();

        expect(expired, isTrue);
      });

      test('should return false when token is valid', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final expired = await tokenStorage.isAccessTokenExpired();

        expect(expired, isFalse);
      });
    });

    group('needsProactiveRefresh', () {
      test('should return false when no token stored', () async {
        final needsRefresh = await tokenStorage.needsProactiveRefresh();
        expect(needsRefresh, isFalse);
      });

      test('should return true when token expires in less than 5 minutes', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 3)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final needsRefresh = await tokenStorage.needsProactiveRefresh();

        expect(needsRefresh, isTrue);
      });

      test('should return false when token has more than 5 minutes remaining', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        final needsRefresh = await tokenStorage.needsProactiveRefresh();

        expect(needsRefresh, isFalse);
      });
    });

    group('clearTokens', () {
      test('should clear all tokens', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );

        await tokenStorage.saveTokens(tokens);
        await tokenStorage.clearTokens();

        expect(await tokenStorage.getAccessToken(), isNull);
        expect(await tokenStorage.getRefreshToken(), isNull);
        expect(await tokenStorage.getTokens(), isNull);
      });
    });

    group('saveUser and getUser', () {
      test('should save and retrieve user', () async {
        final user = AppUser(
          id: 'user-123',
          email: 'test@example.com',
          name: 'Test User',
          provider: AuthProvider.google,
          createdAt: DateTime.now(),
        );

        await tokenStorage.saveUser(user);
        final retrieved = await tokenStorage.getUser();

        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(user.id));
        expect(retrieved.email, equals(user.email));
        expect(retrieved.name, equals(user.name));
        expect(retrieved.provider, equals(user.provider));
      });

      test('should return null when no user stored', () async {
        final user = await tokenStorage.getUser();
        expect(user, isNull);
      });
    });

    group('onboarding status', () {
      test('should return false by default', () async {
        final completed = await tokenStorage.isOnboardingCompleted();
        expect(completed, isFalse);
      });

      test('should persist onboarding completed status', () async {
        await tokenStorage.setOnboardingCompleted(true);
        expect(await tokenStorage.isOnboardingCompleted(), isTrue);

        await tokenStorage.setOnboardingCompleted(false);
        expect(await tokenStorage.isOnboardingCompleted(), isFalse);
      });
    });

    group('clearAll', () {
      test('should clear all stored data', () async {
        final tokens = AuthTokens(
          accessToken: 'test-token',
          refreshToken: 'test-refresh',
          accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
          refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
        );
        final user = AppUser.localOnly();

        await tokenStorage.saveTokens(tokens);
        await tokenStorage.saveUser(user);
        await tokenStorage.setOnboardingCompleted(true);

        await tokenStorage.clearAll();

        expect(await tokenStorage.getTokens(), isNull);
        expect(await tokenStorage.getUser(), isNull);
        expect(await tokenStorage.isOnboardingCompleted(), isFalse);
      });
    });
  });

  group('AuthTokens', () {
    test('isAccessTokenExpired returns true when expired', () {
      final tokens = AuthTokens(
        accessToken: 'test',
        refreshToken: 'test',
        accessTokenExpiry: DateTime.now().subtract(const Duration(minutes: 1)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpired returns false when valid', () {
      final tokens = AuthTokens(
        accessToken: 'test',
        refreshToken: 'test',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.isAccessTokenExpired, isFalse);
    });

    test('needsProactiveRefresh returns true when less than 5 minutes remaining', () {
      final tokens = AuthTokens(
        accessToken: 'test',
        refreshToken: 'test',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 4)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.needsProactiveRefresh, isTrue);
    });

    test('needsProactiveRefresh returns false when more than 5 minutes remaining', () {
      final tokens = AuthTokens(
        accessToken: 'test',
        refreshToken: 'test',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 10)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      expect(tokens.needsProactiveRefresh, isFalse);
    });

    test('accessTokenTimeRemaining returns correct duration', () {
      final expiry = DateTime.now().add(const Duration(minutes: 10));
      final tokens = AuthTokens(
        accessToken: 'test',
        refreshToken: 'test',
        accessTokenExpiry: expiry,
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      final remaining = tokens.accessTokenTimeRemaining;
      // Allow tolerance for test execution time - should be 9 or 10 minutes
      expect(remaining.inMinutes, anyOf(equals(9), equals(10)));
    });

    test('toJson and fromJson round-trip correctly', () {
      final tokens = AuthTokens(
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        accessTokenExpiry: DateTime(2025, 1, 10, 12, 0),
        refreshTokenExpiry: DateTime(2025, 2, 10, 12, 0),
      );

      final json = tokens.toJson();
      final restored = AuthTokens.fromJson(json);

      expect(restored.accessToken, equals(tokens.accessToken));
      expect(restored.refreshToken, equals(tokens.refreshToken));
      expect(restored.accessTokenExpiry, equals(tokens.accessTokenExpiry));
      expect(restored.refreshTokenExpiry, equals(tokens.refreshTokenExpiry));
    });
  });

  group('AppUser', () {
    test('localOnly factory creates correct user', () {
      final user = AppUser.localOnly();

      expect(user.id, equals('local-user'));
      expect(user.name, equals('Local User'));
      expect(user.provider, equals(AuthProvider.localOnly));
      expect(user.email, isNull);
    });

    test('toJson and fromJson round-trip correctly', () {
      final user = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test User',
        provider: AuthProvider.google,
        createdAt: DateTime(2025, 1, 10, 12, 0),
      );

      final json = user.toJson();
      final restored = AppUser.fromJson(json);

      expect(restored.id, equals(user.id));
      expect(restored.email, equals(user.email));
      expect(restored.name, equals(user.name));
      expect(restored.provider, equals(user.provider));
      expect(restored.createdAt, equals(user.createdAt));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'user-456',
        'provider': 'apple',
        'createdAt': '2025-01-10T12:00:00.000',
      };

      final user = AppUser.fromJson(json);

      expect(user.id, equals('user-456'));
      expect(user.email, isNull);
      expect(user.name, isNull);
      expect(user.provider, equals(AuthProvider.apple));
    });

    test('fromJson handles unknown provider', () {
      final json = {
        'id': 'user-789',
        'provider': 'unknown_provider',
        'createdAt': '2025-01-10T12:00:00.000',
      };

      final user = AppUser.fromJson(json);

      expect(user.provider, equals(AuthProvider.localOnly));
    });
  });

  group('AuthState', () {
    test('initial factory creates correct state', () {
      final state = AuthState.initial();

      expect(state.status, equals(AuthStatus.initial));
      expect(state.user, isNull);
      expect(state.onboardingCompleted, isFalse);
    });

    test('loading factory creates correct state', () {
      final state = AuthState.loading();

      expect(state.status, equals(AuthStatus.loading));
    });

    test('authenticated factory creates correct state', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(user: user, onboardingCompleted: true);

      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user, equals(user));
      expect(state.onboardingCompleted, isTrue);
      expect(state.isAuthenticated, isTrue);
    });

    test('unauthenticated factory creates correct state', () {
      final state = AuthState.unauthenticated(onboardingCompleted: true);

      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.user, isNull);
      expect(state.onboardingCompleted, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('error factory creates correct state', () {
      final state = AuthState.error('Something went wrong');

      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage, equals('Something went wrong'));
    });

    test('isLocalOnly returns true for local-only user', () {
      final user = AppUser.localOnly();
      final state = AuthState.authenticated(user: user);

      expect(state.isLocalOnly, isTrue);
    });

    test('isLocalOnly returns false for OAuth user', () {
      final user = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        name: 'Test',
        provider: AuthProvider.google,
        createdAt: DateTime.now(),
      );
      final state = AuthState.authenticated(user: user);

      expect(state.isLocalOnly, isFalse);
    });

    test('copyWith updates specified fields', () {
      final originalUser = AppUser.localOnly();
      final state = AuthState.authenticated(user: originalUser);

      final updated = state.copyWith(
        status: AuthStatus.loading,
        onboardingCompleted: true,
      );

      expect(updated.status, equals(AuthStatus.loading));
      expect(updated.user, equals(originalUser));
      expect(updated.onboardingCompleted, isTrue);
    });
  });

  group('AuthResult', () {
    test('success factory creates correct result', () {
      final user = AppUser.localOnly();
      final result = AuthResult.success(user: user);

      expect(result.success, isTrue);
      expect(result.user, equals(user));
      expect(result.error, isNull);
    });

    test('failure factory creates correct result', () {
      final result = AuthResult.failure('Auth failed');

      expect(result.success, isFalse);
      expect(result.user, isNull);
      expect(result.error, equals('Auth failed'));
    });

    test('cancelled factory creates correct result', () {
      final result = AuthResult.cancelled();

      expect(result.success, isFalse);
      expect(result.error, equals('Sign in was cancelled'));
    });
  });

  group('AuthService', () {
    late MockSecureStorage mockStorage;
    late TokenStorage tokenStorage;
    late AuthService authService;

    setUp(() {
      mockStorage = MockSecureStorage();
      tokenStorage = TokenStorage(storage: mockStorage);
      authService = AuthService(tokenStorage: tokenStorage);
    });

    tearDown(() {
      authService.dispose();
    });

    group('skipSignIn', () {
      test('should create local-only user', () async {
        final result = await authService.skipSignIn();

        expect(result.success, isTrue);
        expect(result.user, isNotNull);
        expect(result.user!.provider, equals(AuthProvider.localOnly));
        expect(result.user!.id, equals('local-user'));
      });

      test('should store user in token storage', () async {
        await authService.skipSignIn();

        final storedUser = await tokenStorage.getUser();
        expect(storedUser, isNotNull);
        expect(storedUser!.provider, equals(AuthProvider.localOnly));
      });
    });

    group('isAuthenticated', () {
      test('should return false when no user stored', () async {
        final isAuthed = await authService.isAuthenticated();
        expect(isAuthed, isFalse);
      });

      test('should return true for local-only user', () async {
        await authService.skipSignIn();

        final isAuthed = await authService.isAuthenticated();
        expect(isAuthed, isTrue);
      });
    });

    group('getCurrentUser', () {
      test('should return null when no user stored', () async {
        final user = await authService.getCurrentUser();
        expect(user, isNull);
      });

      test('should return user after sign-in', () async {
        await authService.skipSignIn();

        final user = await authService.getCurrentUser();
        expect(user, isNotNull);
        expect(user!.provider, equals(AuthProvider.localOnly));
      });
    });

    group('signOut', () {
      test('should clear all auth data', () async {
        await authService.skipSignIn();
        await authService.completeOnboarding();

        await authService.signOut();

        expect(await authService.isAuthenticated(), isFalse);
        expect(await authService.getCurrentUser(), isNull);
        // Note: signOut clears all data including onboarding status
      });
    });

    group('completeOnboarding and isOnboardingCompleted', () {
      test('should return false by default', () async {
        final completed = await authService.isOnboardingCompleted();
        expect(completed, isFalse);
      });

      test('should persist onboarding completion', () async {
        await authService.completeOnboarding();

        final completed = await authService.isOnboardingCompleted();
        expect(completed, isTrue);
      });
    });

    group('initialize', () {
      test('should return unauthenticated when no stored data', () async {
        final state = await authService.initialize();

        expect(state.status, equals(AuthStatus.unauthenticated));
        expect(state.user, isNull);
      });

      test('should return authenticated when valid user stored', () async {
        await authService.skipSignIn();
        await authService.completeOnboarding();

        // Create fresh service to simulate app restart
        final freshService = AuthService(tokenStorage: tokenStorage);
        final state = await freshService.initialize();

        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.user, isNotNull);
        expect(state.onboardingCompleted, isTrue);

        freshService.dispose();
      });
    });

    group('refreshToken', () {
      test('should fail when no tokens stored', () async {
        final result = await authService.refreshToken();

        expect(result.success, isFalse);
        expect(result.error, contains('No tokens'));
      });
    });
  });
}
