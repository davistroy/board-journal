import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/models/models.dart';
import 'package:boardroom_journal/providers/auth_providers.dart';
import 'package:boardroom_journal/services/services.dart';

@GenerateMocks([AuthService, TokenStorage])
import 'auth_providers_test.mocks.dart';

void main() {
  group('AuthNotifier', () {
    late MockAuthService mockAuthService;
    late AuthNotifier authNotifier;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    test('initial state is loading', () {
      when(mockAuthService.initialize())
          .thenAnswer((_) async => AuthState.initial());

      authNotifier = AuthNotifier(mockAuthService);

      // Initial state should be loading during initialization
      expect(authNotifier.state.status, AuthStatus.loading);
    });

    test('signInWithApple returns success on valid response', () async {
      when(mockAuthService.initialize())
          .thenAnswer((_) async => AuthState.initial());
      when(mockAuthService.signInWithApple()).thenAnswer(
        (_) async => AuthResult.success(
          user: AppUser(
            id: 'user-123',
            email: 'test@example.com',
            displayName: 'Test User',
          ),
        ),
      );

      authNotifier = AuthNotifier(mockAuthService);
      await Future.delayed(Duration.zero); // Let init complete

      final result = await authNotifier.signInWithApple();

      expect(result.success, isTrue);
      expect(result.user?.email, 'test@example.com');
    });

    test('signInWithApple handles error', () async {
      when(mockAuthService.initialize())
          .thenAnswer((_) async => AuthState.initial());
      when(mockAuthService.signInWithApple()).thenAnswer(
        (_) async => AuthResult.failure('Sign in cancelled'),
      );

      authNotifier = AuthNotifier(mockAuthService);
      await Future.delayed(Duration.zero);

      final result = await authNotifier.signInWithApple();

      expect(result.success, isFalse);
      expect(result.error, 'Sign in cancelled');
    });

    test('signInWithGoogle returns success on valid response', () async {
      when(mockAuthService.initialize())
          .thenAnswer((_) async => AuthState.initial());
      when(mockAuthService.signInWithGoogle()).thenAnswer(
        (_) async => AuthResult.success(
          user: AppUser(
            id: 'user-456',
            email: 'google@example.com',
            displayName: 'Google User',
          ),
        ),
      );

      authNotifier = AuthNotifier(mockAuthService);
      await Future.delayed(Duration.zero);

      final result = await authNotifier.signInWithGoogle();

      expect(result.success, isTrue);
      expect(result.user?.email, 'google@example.com');
    });

    test('signOut clears auth state', () async {
      when(mockAuthService.initialize()).thenAnswer(
        (_) async => AuthState.authenticated(
          user: AppUser(
            id: 'user-123',
            email: 'test@example.com',
          ),
          onboardingCompleted: true,
        ),
      );
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      authNotifier = AuthNotifier(mockAuthService);
      await Future.delayed(Duration.zero);

      await authNotifier.signOut();

      expect(authNotifier.state.status, AuthStatus.unauthenticated);
    });

    test('refreshToken updates tokens on success', () async {
      when(mockAuthService.initialize())
          .thenAnswer((_) async => AuthState.initial());
      when(mockAuthService.refreshToken()).thenAnswer((_) async => true);

      authNotifier = AuthNotifier(mockAuthService);
      await Future.delayed(Duration.zero);

      final result = await authNotifier.refreshToken();

      expect(result, isTrue);
      verify(mockAuthService.refreshToken()).called(1);
    });
  });

  group('Auth Providers', () {
    test('tokenStorageProvider creates TokenStorage instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final tokenStorage = container.read(tokenStorageProvider);

      expect(tokenStorage, isA<TokenStorage>());
    });

    test('authServiceProvider creates AuthService with TokenStorage', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authService = container.read(authServiceProvider);

      expect(authService, isA<AuthService>());
    });

    test('isAuthenticatedProvider returns auth status', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => MockAuthNotifier(
              AuthState.authenticated(
                user: AppUser(id: 'test', email: 'test@test.com'),
                onboardingCompleted: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final isAuthenticated = container.read(isAuthenticatedProvider);

      expect(isAuthenticated, isTrue);
    });

    test('currentUserProvider returns user when authenticated', () {
      final testUser = AppUser(
        id: 'user-123',
        email: 'test@example.com',
        displayName: 'Test',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => MockAuthNotifier(
              AuthState.authenticated(
                user: testUser,
                onboardingCompleted: true,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = container.read(currentUserProvider);

      expect(user?.id, 'user-123');
      expect(user?.email, 'test@example.com');
    });

    test('currentUserProvider returns null when unauthenticated', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            (ref) => MockAuthNotifier(AuthState.initial()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = container.read(currentUserProvider);

      expect(user, isNull);
    });
  });
}

/// Mock auth notifier for testing derived providers.
class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(super.state);

  @override
  Future<AuthResult> signInWithApple() async => AuthResult.failure('Mock');

  @override
  Future<AuthResult> signInWithGoogle() async => AuthResult.failure('Mock');

  @override
  Future<AuthResult> signInWithMicrosoft() async => AuthResult.failure('Mock');

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> refreshToken() async => false;

  @override
  Future<void> setOnboardingCompleted() async {}
}
