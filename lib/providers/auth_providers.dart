import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';

// ==================
// Service Providers
// ==================

/// Provider for TokenStorage service.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Provider for AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthService(tokenStorage: tokenStorage);
});

// ==================
// Auth State Provider
// ==================

/// Notifier for managing authentication state.
///
/// Handles:
/// - OAuth sign-in flows (Apple, Google, Microsoft)
/// - Token management and refresh
/// - Sign-out
/// - Onboarding completion
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial()) {
    _initialize();
  }

  /// Initializes auth state from stored data.
  Future<void> _initialize() async {
    state = AuthState.loading();
    try {
      final authState = await _authService.initialize();
      state = authState;
    } catch (e) {
      state = AuthState.error('Failed to initialize: $e');
    }
  }

  /// Signs in with Apple.
  ///
  /// Required for iOS App Store compliance.
  Future<AuthResult> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.signInWithApple();
      if (result.success && result.user != null) {
        state = AuthState.authenticated(
          user: result.user!,
          onboardingCompleted: true,
        );
      } else {
        state = AuthState.error(result.error ?? 'Sign in failed');
      }
      return result;
    } catch (e) {
      final error = 'Apple Sign-In failed: $e';
      state = AuthState.error(error);
      return AuthResult.failure(error);
    }
  }

  /// Signs in with Google.
  Future<AuthResult> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.signInWithGoogle();
      if (result.success && result.user != null) {
        state = AuthState.authenticated(
          user: result.user!,
          onboardingCompleted: true,
        );
      } else {
        state = AuthState.error(result.error ?? 'Sign in failed');
      }
      return result;
    } catch (e) {
      final error = 'Google Sign-In failed: $e';
      state = AuthState.error(error);
      return AuthResult.failure(error);
    }
  }

  /// Signs in with Microsoft.
  Future<AuthResult> signInWithMicrosoft() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.signInWithMicrosoft();
      if (result.success && result.user != null) {
        state = AuthState.authenticated(
          user: result.user!,
          onboardingCompleted: true,
        );
      } else {
        state = AuthState.error(result.error ?? 'Sign in failed');
      }
      return result;
    } catch (e) {
      final error = 'Microsoft Sign-In failed: $e';
      state = AuthState.error(error);
      return AuthResult.failure(error);
    }
  }

  /// Skips sign-in for local-only mode.
  Future<AuthResult> skipSignIn() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await _authService.skipSignIn();
      if (result.success && result.user != null) {
        state = AuthState.authenticated(
          user: result.user!,
          onboardingCompleted: true,
        );
      } else {
        state = AuthState.error(result.error ?? 'Skip sign in failed');
      }
      return result;
    } catch (e) {
      final error = 'Skip sign-in failed: $e';
      state = AuthState.error(error);
      return AuthResult.failure(error);
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authService.signOut();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error('Sign out failed: $e');
    }
  }

  /// Completes onboarding.
  Future<void> completeOnboarding() async {
    try {
      await _authService.completeOnboarding();
      state = state.copyWith(onboardingCompleted: true);
    } catch (e) {
      // Don't fail the whole state, just log
    }
  }

  /// Refreshes the access token.
  Future<void> refreshToken() async {
    try {
      final result = await _authService.refreshToken();
      if (!result.success) {
        // Token refresh failed, might need to re-authenticate
        if (result.error?.contains('expired') == true) {
          state = AuthState.unauthenticated(
            onboardingCompleted: state.onboardingCompleted,
          );
        }
      }
    } catch (e) {
      // Token refresh failed silently, will retry later
    }
  }

  /// Clears error state and returns to unauthenticated.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = AuthState.unauthenticated(
        onboardingCompleted: state.onboardingCompleted,
      );
    }
  }
}

/// Provider for auth state notifier.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final notifier = AuthNotifier(authService);

  // Dispose auth service when provider is disposed
  ref.onDispose(() {
    authService.dispose();
  });

  return notifier;
});

// ==================
// Derived Providers
// ==================

/// Provider for whether user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.isAuthenticated;
});

/// Provider for current user.
final currentUserProvider = Provider<AppUser?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.user;
});

/// Provider for whether onboarding is completed.
final isOnboardingCompletedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.onboardingCompleted;
});

/// Provider for auth status.
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.status;
});

/// Provider for whether user is in local-only mode.
final isLocalOnlyProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.isLocalOnly;
});

/// Provider for auth error message.
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.errorMessage;
});

// ==================
// Helper Providers
// ==================

/// Provider that determines if user should see onboarding.
///
/// Returns true if:
/// - Not authenticated AND not onboarding completed
final shouldShowOnboardingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authNotifierProvider);

  // Still initializing
  if (authState.status == AuthStatus.initial ||
      authState.status == AuthStatus.loading) {
    return false;
  }

  // Show onboarding if not completed
  return !authState.onboardingCompleted;
});

/// Provider that determines the initial route based on auth state.
///
/// Returns:
/// - '/onboarding/welcome' if onboarding not completed
/// - '/' (home) if authenticated
/// - '/signin' if onboarding completed but not authenticated
final initialRouteProvider = Provider<String>((ref) {
  final authState = ref.watch(authNotifierProvider);

  // Still loading
  if (authState.status == AuthStatus.initial ||
      authState.status == AuthStatus.loading) {
    return '/'; // Will redirect after loading
  }

  // Not onboarded yet
  if (!authState.onboardingCompleted) {
    return '/onboarding/welcome';
  }

  // Authenticated
  if (authState.isAuthenticated) {
    return '/';
  }

  // Onboarded but signed out - go to sign-in
  return '/onboarding/signin';
});
