import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/models/models.dart';
import 'package:boardroom_journal/services/auth/token_storage.dart';

@GenerateMocks([FlutterSecureStorage])
import 'token_storage_test.mocks.dart';

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TokenStorage tokenStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    tokenStorage = TokenStorage(storage: mockStorage);
  });

  group('TokenStorage', () {
    group('saveTokens', () {
      test('saves all token data to secure storage', () async {
        final tokens = AuthTokens(
          accessToken: 'access-token-123',
          refreshToken: 'refresh-token-456',
          accessTokenExpiry: DateTime(2026, 1, 15, 12, 0),
          refreshTokenExpiry: DateTime(2026, 2, 15, 12, 0),
        );

        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await tokenStorage.saveTokens(tokens);

        verify(mockStorage.write(
          key: 'auth_access_token',
          value: 'access-token-123',
        )).called(1);
        verify(mockStorage.write(
          key: 'auth_refresh_token',
          value: 'refresh-token-456',
        )).called(1);
        verify(mockStorage.write(
          key: 'auth_access_token_expiry',
          value: '2026-01-15T12:00:00.000',
        )).called(1);
        verify(mockStorage.write(
          key: 'auth_refresh_token_expiry',
          value: '2026-02-15T12:00:00.000',
        )).called(1);
      });
    });

    group('getAccessToken', () {
      test('returns access token from storage', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'stored-access-token');

        final result = await tokenStorage.getAccessToken();

        expect(result, 'stored-access-token');
      });

      test('returns null when no token stored', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.getAccessToken();

        expect(result, isNull);
      });
    });

    group('getRefreshToken', () {
      test('returns refresh token from storage', () async {
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'stored-refresh-token');

        final result = await tokenStorage.getRefreshToken();

        expect(result, 'stored-refresh-token');
      });

      test('returns null when no token stored', () async {
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.getRefreshToken();

        expect(result, isNull);
      });
    });

    group('getTokens', () {
      test('returns AuthTokens when all data is present', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'access-token');
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'refresh-token');
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => '2026-01-15T12:00:00.000');
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async => '2026-02-15T12:00:00.000');

        final result = await tokenStorage.getTokens();

        expect(result, isNotNull);
        expect(result!.accessToken, 'access-token');
        expect(result.refreshToken, 'refresh-token');
        expect(result.accessTokenExpiry, DateTime(2026, 1, 15, 12, 0));
        expect(result.refreshTokenExpiry, DateTime(2026, 2, 15, 12, 0));
      });

      test('returns null when access token is missing', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => null);
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'refresh-token');
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => '2026-01-15T12:00:00.000');
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async => '2026-02-15T12:00:00.000');

        final result = await tokenStorage.getTokens();

        expect(result, isNull);
      });

      test('returns null when refresh token is missing', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'access-token');
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => null);
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => '2026-01-15T12:00:00.000');
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async => '2026-02-15T12:00:00.000');

        final result = await tokenStorage.getTokens();

        expect(result, isNull);
      });

      test('returns null and clears storage on invalid date format', () async {
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'access-token');
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'refresh-token');
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => 'invalid-date');
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async => '2026-02-15T12:00:00.000');
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        final result = await tokenStorage.getTokens();

        expect(result, isNull);
        verify(mockStorage.delete(key: 'auth_access_token')).called(1);
      });
    });

    group('isAccessTokenExpired', () {
      test('returns true when tokens not present', () async {
        when(mockStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.isAccessTokenExpired();

        expect(result, isTrue);
      });

      test('returns true when access token is expired', () async {
        final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'access-token');
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'refresh-token');
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => expiredTime.toIso8601String());
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async =>
                DateTime.now().add(const Duration(days: 30)).toIso8601String());

        final result = await tokenStorage.isAccessTokenExpired();

        expect(result, isTrue);
      });

      test('returns false when access token is valid', () async {
        final validTime = DateTime.now().add(const Duration(hours: 1));
        when(mockStorage.read(key: 'auth_access_token'))
            .thenAnswer((_) async => 'access-token');
        when(mockStorage.read(key: 'auth_refresh_token'))
            .thenAnswer((_) async => 'refresh-token');
        when(mockStorage.read(key: 'auth_access_token_expiry'))
            .thenAnswer((_) async => validTime.toIso8601String());
        when(mockStorage.read(key: 'auth_refresh_token_expiry'))
            .thenAnswer((_) async =>
                DateTime.now().add(const Duration(days: 30)).toIso8601String());

        final result = await tokenStorage.isAccessTokenExpired();

        expect(result, isFalse);
      });
    });

    group('isRefreshTokenExpired', () {
      test('returns true when tokens not present', () async {
        when(mockStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.isRefreshTokenExpired();

        expect(result, isTrue);
      });
    });

    group('needsProactiveRefresh', () {
      test('returns false when tokens not present', () async {
        when(mockStorage.read(key: anyNamed('key')))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.needsProactiveRefresh();

        expect(result, isFalse);
      });
    });

    group('clearTokens', () {
      test('deletes all token data from storage', () async {
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        await tokenStorage.clearTokens();

        verify(mockStorage.delete(key: 'auth_access_token')).called(1);
        verify(mockStorage.delete(key: 'auth_refresh_token')).called(1);
        verify(mockStorage.delete(key: 'auth_access_token_expiry')).called(1);
        verify(mockStorage.delete(key: 'auth_refresh_token_expiry')).called(1);
      });
    });

    group('saveUser', () {
      test('saves user as JSON to storage', () async {
        final user = AppUser(
          id: 'user-123',
          email: 'test@example.com',
          displayName: 'Test User',
        );

        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await tokenStorage.saveUser(user);

        verify(mockStorage.write(
          key: 'auth_user',
          value: argThat(contains('user-123'), named: 'value'),
        )).called(1);
      });
    });

    group('getUser', () {
      test('returns AppUser from stored JSON', () async {
        when(mockStorage.read(key: 'auth_user')).thenAnswer((_) async =>
            '{"id":"user-123","email":"test@example.com","displayName":"Test User"}');

        final result = await tokenStorage.getUser();

        expect(result, isNotNull);
        expect(result!.id, 'user-123');
        expect(result.email, 'test@example.com');
        expect(result.displayName, 'Test User');
      });

      test('returns null when no user stored', () async {
        when(mockStorage.read(key: 'auth_user'))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.getUser();

        expect(result, isNull);
      });

      test('returns null on invalid JSON', () async {
        when(mockStorage.read(key: 'auth_user'))
            .thenAnswer((_) async => 'invalid-json');

        final result = await tokenStorage.getUser();

        expect(result, isNull);
      });
    });

    group('clearUser', () {
      test('deletes user from storage', () async {
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        await tokenStorage.clearUser();

        verify(mockStorage.delete(key: 'auth_user')).called(1);
      });
    });

    group('onboarding', () {
      test('setOnboardingCompleted saves true', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await tokenStorage.setOnboardingCompleted(true);

        verify(mockStorage.write(
          key: 'auth_onboarding_completed',
          value: 'true',
        )).called(1);
      });

      test('setOnboardingCompleted saves false', () async {
        when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});

        await tokenStorage.setOnboardingCompleted(false);

        verify(mockStorage.write(
          key: 'auth_onboarding_completed',
          value: 'false',
        )).called(1);
      });

      test('isOnboardingCompleted returns true', () async {
        when(mockStorage.read(key: 'auth_onboarding_completed'))
            .thenAnswer((_) async => 'true');

        final result = await tokenStorage.isOnboardingCompleted();

        expect(result, isTrue);
      });

      test('isOnboardingCompleted returns false when not set', () async {
        when(mockStorage.read(key: 'auth_onboarding_completed'))
            .thenAnswer((_) async => null);

        final result = await tokenStorage.isOnboardingCompleted();

        expect(result, isFalse);
      });
    });

    group('clearAll', () {
      test('clears all auth data from storage', () async {
        when(mockStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});

        await tokenStorage.clearAll();

        verify(mockStorage.delete(key: 'auth_access_token')).called(1);
        verify(mockStorage.delete(key: 'auth_refresh_token')).called(1);
        verify(mockStorage.delete(key: 'auth_access_token_expiry')).called(1);
        verify(mockStorage.delete(key: 'auth_refresh_token_expiry')).called(1);
        verify(mockStorage.delete(key: 'auth_user')).called(1);
        verify(mockStorage.delete(key: 'auth_onboarding_completed')).called(1);
      });
    });
  });
}
