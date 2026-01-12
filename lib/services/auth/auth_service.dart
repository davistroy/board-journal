import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../api/api_config.dart';
import 'oauth_service.dart';
import 'session_manager.dart';
import 'token_refresh_service.dart';
import 'token_storage.dart';

/// Result of an authentication operation.
class AuthResult {
  /// Whether the operation was successful.
  final bool success;

  /// The authenticated user, if successful.
  final AppUser? user;

  /// Auth tokens, if successful.
  final AuthTokens? tokens;

  /// Error message, if failed.
  final String? error;

  const AuthResult._({
    required this.success,
    this.user,
    this.tokens,
    this.error,
  });

  /// Creates a successful auth result.
  factory AuthResult.success({
    required AppUser user,
    AuthTokens? tokens,
  }) {
    return AuthResult._(
      success: true,
      user: user,
      tokens: tokens,
    );
  }

  /// Creates a failed auth result.
  factory AuthResult.failure(String error) {
    return AuthResult._(
      success: false,
      error: error,
    );
  }

  /// Creates a cancelled auth result.
  factory AuthResult.cancelled() {
    return const AuthResult._(
      success: false,
      error: 'Sign in was cancelled',
    );
  }
}

/// Authentication service facade coordinating OAuth, tokens, and sessions.
///
/// Supports:
/// - Apple Sign-In (required for iOS App Store)
/// - Google Sign-In
/// - Microsoft Sign-In
/// - Local-only mode (skip sign-in)
///
/// Per PRD Section 5.0:
/// - Target: first entry in <60 seconds
/// - Onboarding: Welcome -> Privacy -> OAuth -> First Entry (Home)
class AuthService {
  final OAuthService _oauthService;
  final TokenRefreshService _tokenRefreshService;
  final SessionManager _sessionManager;

  /// Creates an AuthService instance.
  ///
  /// Optionally accepts dependencies for testing.
  AuthService({
    TokenStorage? tokenStorage,
    GoogleSignIn? googleSignIn,
    ApiConfig? apiConfig,
    http.Client? httpClient,
    OAuthService? oauthService,
    TokenRefreshService? tokenRefreshService,
    SessionManager? sessionManager,
  })  : _oauthService = oauthService ??
            OAuthService(
              googleSignIn: googleSignIn,
            ),
        _tokenRefreshService = tokenRefreshService ??
            TokenRefreshService(
              tokenStorage: tokenStorage,
              apiConfig: apiConfig,
              httpClient: httpClient,
            ),
        _sessionManager = sessionManager ??
            SessionManager(
              tokenStorage: tokenStorage,
            );

  /// Signs in with Apple.
  ///
  /// Required for iOS App Store compliance.
  Future<AuthResult> signInWithApple() async {
    final result = await _oauthService.signInWithApple();
    return _handleOAuthResult(result);
  }

  /// Signs in with Google.
  Future<AuthResult> signInWithGoogle() async {
    final result = await _oauthService.signInWithGoogle();
    return _handleOAuthResult(result);
  }

  /// Signs in with Microsoft.
  Future<AuthResult> signInWithMicrosoft() async {
    final result = await _oauthService.signInWithMicrosoft();
    return _handleOAuthResult(result);
  }

  /// Skips sign-in for local-only mode.
  Future<AuthResult> skipSignIn() async {
    try {
      final result = _oauthService.createLocalUser();
      if (result.success && result.user != null) {
        await _sessionManager.saveUser(result.user!);
        return AuthResult.success(user: result.user!);
      }
      return AuthResult.failure(result.error ?? 'Failed to create local user');
    } catch (e) {
      return AuthResult.failure('Failed to set up local mode: $e');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    // Stop refresh timer
    _tokenRefreshService.stopRefreshTimer();

    // Sign out from OAuth providers
    await _oauthService.signOutFromGoogle();

    // Clear session
    await _sessionManager.clearSession();
  }

  /// Refreshes the access token using the refresh token.
  Future<AuthResult> refreshToken() async {
    final result = await _tokenRefreshService.refreshToken();

    if (result.success && result.tokens != null) {
      final user = await _sessionManager.getCurrentUser();
      if (user == null) {
        return AuthResult.failure('User data not found');
      }
      _tokenRefreshService.startRefreshTimer();
      return AuthResult.success(user: user, tokens: result.tokens);
    }

    return AuthResult.failure(result.error ?? 'Token refresh failed');
  }

  /// Checks if the user is currently authenticated.
  Future<bool> isAuthenticated() async {
    return _sessionManager.isAuthenticated();
  }

  /// Gets the current authenticated user.
  Future<AppUser?> getCurrentUser() async {
    return _sessionManager.getCurrentUser();
  }

  /// Checks if the access token needs refresh.
  Future<bool> checkTokenExpiry() async {
    return _tokenRefreshService.needsRefresh();
  }

  /// Performs proactive token refresh if needed.
  Future<void> proactiveRefresh() async {
    await _tokenRefreshService.proactiveRefresh();
  }

  /// Checks if onboarding has been completed.
  Future<bool> isOnboardingCompleted() async {
    return _sessionManager.isOnboardingCompleted();
  }

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    await _sessionManager.completeOnboarding();
  }

  /// Initializes the auth service.
  ///
  /// Checks stored auth state and starts refresh timer if needed.
  Future<AuthState> initialize() async {
    final state = await _sessionManager.initialize();

    if (state.isAuthenticated && state.user != null) {
      // Start proactive refresh for non-local users
      if (state.user!.provider != AuthProvider.localOnly) {
        _tokenRefreshService.startRefreshTimer();
        await proactiveRefresh();
      }
    }

    return state;
  }

  /// Disposes resources.
  void dispose() {
    _tokenRefreshService.dispose();
  }

  // Private helper methods

  /// Handles an OAuth result by saving to session and starting refresh.
  Future<AuthResult> _handleOAuthResult(OAuthResult result) async {
    if (result.cancelled) {
      return AuthResult.cancelled();
    }

    if (!result.success || result.user == null) {
      return AuthResult.failure(result.error ?? 'Sign-in failed');
    }

    try {
      // Save user and tokens
      await _sessionManager.saveUser(result.user!);
      if (result.tokens != null) {
        await _sessionManager.saveTokens(result.tokens!);
      }

      // Start proactive refresh timer
      _tokenRefreshService.startRefreshTimer();

      return AuthResult.success(user: result.user!, tokens: result.tokens);
    } catch (e) {
      return AuthResult.failure('Failed to save session: $e');
    }
  }
}
