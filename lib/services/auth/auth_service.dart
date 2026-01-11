import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/models.dart';
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

/// Authentication service handling OAuth sign-in flows.
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
  final TokenStorage _tokenStorage;
  final GoogleSignIn _googleSignIn;

  /// Timer for proactive token refresh.
  Timer? _refreshTimer;

  /// Creates an AuthService instance.
  ///
  /// Optionally accepts dependencies for testing.
  AuthService({
    TokenStorage? tokenStorage,
    GoogleSignIn? googleSignIn,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            );

  /// Signs in with Apple.
  ///
  /// Required for iOS App Store compliance.
  /// Uses Sign in with Apple SDK for native integration.
  Future<AuthResult> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return AuthResult.failure('Apple Sign-In is not available on this device');
      }

      // Request credentials
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Extract user info
      // Note: Apple only provides email/name on first sign-in
      final user = AppUser(
        id: credential.userIdentifier ?? 'apple-${DateTime.now().millisecondsSinceEpoch}',
        email: credential.email,
        name: _formatAppleName(credential.givenName, credential.familyName),
        provider: AuthProvider.apple,
        createdAt: DateTime.now(),
      );

      // Create tokens (in production, exchange authorizationCode with your backend)
      // For now, we create placeholder tokens that would be exchanged server-side
      final tokens = _createTokensFromCredential(
        idToken: credential.identityToken,
        authCode: credential.authorizationCode,
      );

      // Store user and tokens
      await Future.wait([
        _tokenStorage.saveUser(user),
        if (tokens != null) _tokenStorage.saveTokens(tokens),
      ]);

      // Start proactive refresh timer
      _startRefreshTimer();

      return AuthResult.success(user: user, tokens: tokens);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.cancelled();
      }
      return AuthResult.failure('Apple Sign-In failed: ${e.message}');
    } catch (e) {
      return AuthResult.failure('Apple Sign-In failed: $e');
    }
  }

  /// Signs in with Google.
  ///
  /// Uses Google Sign-In SDK for native integration.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return AuthResult.cancelled();
      }

      // Get authentication details
      final auth = await account.authentication;

      // Create user from Google account
      final user = AppUser(
        id: account.id,
        email: account.email,
        name: account.displayName,
        provider: AuthProvider.google,
        createdAt: DateTime.now(),
      );

      // Create tokens from Google auth
      final tokens = _createTokensFromGoogleAuth(auth);

      // Store user and tokens
      await Future.wait([
        _tokenStorage.saveUser(user),
        if (tokens != null) _tokenStorage.saveTokens(tokens),
      ]);

      // Start proactive refresh timer
      _startRefreshTimer();

      return AuthResult.success(user: user, tokens: tokens);
    } catch (e) {
      // Check for cancellation
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        return AuthResult.cancelled();
      }
      return AuthResult.failure('Google Sign-In failed: $e');
    }
  }

  /// Signs in with Microsoft.
  ///
  /// Note: This would typically use MSAL (Microsoft Authentication Library).
  /// For now, provides structure that can be completed with real implementation.
  Future<AuthResult> signInWithMicrosoft() async {
    try {
      // TODO: Implement Microsoft Sign-In using MSAL
      // This would require:
      // 1. Adding msal_flutter package
      // 2. Configuring Azure AD app registration
      // 3. Setting up redirect URIs

      // For now, return a placeholder that indicates work is needed
      return AuthResult.failure(
        'Microsoft Sign-In requires additional configuration. '
        'Please set up Azure AD app registration and MSAL integration.',
      );
    } catch (e) {
      return AuthResult.failure('Microsoft Sign-In failed: $e');
    }
  }

  /// Skips sign-in for local-only mode.
  ///
  /// Creates a local user that can use the app without cloud sync.
  Future<AuthResult> skipSignIn() async {
    try {
      final user = AppUser.localOnly();

      // Store local user (no tokens needed)
      await _tokenStorage.saveUser(user);

      return AuthResult.success(user: user);
    } catch (e) {
      return AuthResult.failure('Failed to set up local mode: $e');
    }
  }

  /// Signs out the current user.
  ///
  /// Clears all stored tokens and user data.
  Future<void> signOut() async {
    // Cancel refresh timer
    _refreshTimer?.cancel();
    _refreshTimer = null;

    // Sign out from providers
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Ignore sign-out errors from providers
    }

    // Clear stored data
    await _tokenStorage.clearAll();
  }

  /// Refreshes the access token using the refresh token.
  ///
  /// Per PRD: Access token has 15-minute expiry.
  Future<AuthResult> refreshToken() async {
    try {
      final tokens = await _tokenStorage.getTokens();

      if (tokens == null) {
        return AuthResult.failure('No tokens to refresh');
      }

      if (tokens.isRefreshTokenExpired) {
        return AuthResult.failure('Refresh token expired, please sign in again');
      }

      // TODO: In production, exchange refresh token with your backend
      // For now, create new tokens (simulating server exchange)
      final newTokens = AuthTokens(
        accessToken: 'refreshed-${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: tokens.refreshToken, // Usually unchanged
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
        refreshTokenExpiry: tokens.refreshTokenExpiry, // Usually unchanged
      );

      await _tokenStorage.saveTokens(newTokens);

      final user = await _tokenStorage.getUser();
      if (user == null) {
        return AuthResult.failure('User data not found');
      }

      // Restart refresh timer
      _startRefreshTimer();

      return AuthResult.success(user: user, tokens: newTokens);
    } catch (e) {
      return AuthResult.failure('Token refresh failed: $e');
    }
  }

  /// Checks if the user is currently authenticated.
  ///
  /// Returns true if valid tokens and user data exist.
  Future<bool> isAuthenticated() async {
    final user = await _tokenStorage.getUser();
    if (user == null) return false;

    // Local-only users are always "authenticated"
    if (user.provider == AuthProvider.localOnly) return true;

    // Check token validity
    final tokens = await _tokenStorage.getTokens();
    if (tokens == null) return false;

    // If access token expired but refresh token valid, consider authenticated
    // (will refresh on next API call)
    return !tokens.isRefreshTokenExpired;
  }

  /// Gets the current authenticated user.
  ///
  /// Returns null if not authenticated.
  Future<AppUser?> getCurrentUser() async {
    return _tokenStorage.getUser();
  }

  /// Checks if the access token needs refresh.
  ///
  /// Returns true if expired or will expire within 5 minutes.
  Future<bool> checkTokenExpiry() async {
    return _tokenStorage.needsProactiveRefresh();
  }

  /// Performs proactive token refresh if needed.
  ///
  /// Per PRD: Refresh when <5 minutes remaining.
  /// Should be called periodically or before API calls.
  Future<void> proactiveRefresh() async {
    final needsRefresh = await checkTokenExpiry();
    if (needsRefresh) {
      await refreshToken();
    }
  }

  /// Checks if onboarding has been completed.
  Future<bool> isOnboardingCompleted() async {
    return _tokenStorage.isOnboardingCompleted();
  }

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(true);
  }

  /// Initializes the auth service.
  ///
  /// Checks stored auth state and starts refresh timer if needed.
  /// Call this on app startup.
  Future<AuthState> initialize() async {
    try {
      final isAuthed = await isAuthenticated();
      final user = await getCurrentUser();
      final onboardingCompleted = await isOnboardingCompleted();

      if (isAuthed && user != null) {
        // Start proactive refresh for non-local users
        if (user.provider != AuthProvider.localOnly) {
          _startRefreshTimer();
          // Perform immediate refresh check
          await proactiveRefresh();
        }

        return AuthState.authenticated(
          user: user,
          onboardingCompleted: onboardingCompleted,
        );
      }

      return AuthState.unauthenticated(onboardingCompleted: onboardingCompleted);
    } catch (e) {
      return AuthState.error('Failed to initialize auth: $e');
    }
  }

  /// Disposes resources.
  ///
  /// Call this when the service is no longer needed.
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Private helper methods

  /// Formats Apple name from given and family name.
  String? _formatAppleName(String? givenName, String? familyName) {
    final parts = [givenName, familyName]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Creates tokens from Apple credential.
  ///
  /// In production, the identityToken and authorizationCode would be
  /// sent to your backend to exchange for proper access/refresh tokens.
  AuthTokens? _createTokensFromCredential({
    String? idToken,
    String? authCode,
  }) {
    if (idToken == null) return null;

    // Placeholder tokens - in production, exchange with backend
    return AuthTokens(
      accessToken: idToken,
      refreshToken: authCode ?? 'apple-refresh-${DateTime.now().millisecondsSinceEpoch}',
      accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
      refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Creates tokens from Google authentication.
  AuthTokens? _createTokensFromGoogleAuth(GoogleSignInAuthentication auth) {
    final accessToken = auth.accessToken;
    if (accessToken == null) return null;

    // Google access tokens typically last 1 hour, but we follow PRD's 15-min pattern
    // In production, exchange with your backend for consistent token management
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: 'google-refresh-${DateTime.now().millisecondsSinceEpoch}',
      accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
      refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Starts the proactive refresh timer.
  ///
  /// Checks every minute if refresh is needed.
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => proactiveRefresh(),
    );
  }
}
