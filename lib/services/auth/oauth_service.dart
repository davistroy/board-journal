import 'dart:developer' as developer;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';

/// UUID generator for cryptographically secure token generation.
const _uuid = Uuid();

/// Log a message for debugging authentication issues.
void _logOAuth(String message, {Object? error, StackTrace? stackTrace}) {
  developer.log(
    message,
    name: 'OAuthService',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Result of an OAuth sign-in operation.
class OAuthResult {
  /// Whether the operation was successful.
  final bool success;

  /// The authenticated user, if successful.
  final AppUser? user;

  /// Auth tokens, if successful.
  final AuthTokens? tokens;

  /// Error message, if failed.
  final String? error;

  /// Whether the user cancelled the sign-in.
  final bool cancelled;

  const OAuthResult._({
    required this.success,
    this.user,
    this.tokens,
    this.error,
    this.cancelled = false,
  });

  /// Creates a successful OAuth result.
  factory OAuthResult.success({
    required AppUser user,
    AuthTokens? tokens,
  }) {
    return OAuthResult._(
      success: true,
      user: user,
      tokens: tokens,
    );
  }

  /// Creates a failed OAuth result.
  factory OAuthResult.failure(String error) {
    return OAuthResult._(
      success: false,
      error: error,
    );
  }

  /// Creates a cancelled OAuth result.
  factory OAuthResult.cancelled() {
    return const OAuthResult._(
      success: false,
      error: 'Sign in was cancelled',
      cancelled: true,
    );
  }
}

/// Service handling OAuth sign-in flows.
///
/// Supports:
/// - Apple Sign-In (required for iOS App Store)
/// - Google Sign-In
/// - Microsoft Sign-In (placeholder)
/// - Local-only mode (skip sign-in)
class OAuthService {
  final GoogleSignIn _googleSignIn;

  /// Creates an OAuthService instance.
  OAuthService({
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            );

  /// Signs in with Apple.
  ///
  /// Required for iOS App Store compliance.
  /// Uses Sign in with Apple SDK for native integration.
  Future<OAuthResult> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        return OAuthResult.failure(
            'Apple Sign-In is not available on this device');
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
        id: credential.userIdentifier ?? 'apple-${_uuid.v4()}',
        email: credential.email,
        name: _formatAppleName(credential.givenName, credential.familyName),
        provider: AuthProvider.apple,
        createdAt: DateTime.now(),
      );

      // Create tokens (in production, exchange authorizationCode with your backend)
      final tokens = _createTokensFromAppleCredential(
        idToken: credential.identityToken,
        authCode: credential.authorizationCode,
      );

      return OAuthResult.success(user: user, tokens: tokens);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return OAuthResult.cancelled();
      }
      return OAuthResult.failure('Apple Sign-In failed: ${e.message}');
    } catch (e) {
      return OAuthResult.failure('Apple Sign-In failed: $e');
    }
  }

  /// Signs in with Google.
  ///
  /// Uses Google Sign-In SDK for native integration.
  Future<OAuthResult> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();

      if (account == null) {
        return OAuthResult.cancelled();
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

      return OAuthResult.success(user: user, tokens: tokens);
    } catch (e) {
      // Check for cancellation
      if (e.toString().contains('canceled') ||
          e.toString().contains('cancelled')) {
        return OAuthResult.cancelled();
      }
      return OAuthResult.failure('Google Sign-In failed: $e');
    }
  }

  /// Signs in with Microsoft.
  ///
  /// Note: Microsoft Sign-In requires MSAL (Microsoft Authentication Library).
  Future<OAuthResult> signInWithMicrosoft() async {
    // Microsoft Sign-In is not yet configured for this app.
    return OAuthResult.failure(
      'Microsoft Sign-In is not available yet. '
      'Please use Apple or Google sign-in instead.',
    );
  }

  /// Creates a local-only user (skip sign-in).
  ///
  /// Creates a local user that can use the app without cloud sync.
  OAuthResult createLocalUser() {
    final user = AppUser.localOnly();
    return OAuthResult.success(user: user);
  }

  /// Signs out from Google if signed in.
  Future<void> signOutFromGoogle() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e, stackTrace) {
      // Log but don't fail sign-out if provider sign-out fails
      _logOAuth(
        'Google sign-out failed (non-blocking)',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
  AuthTokens? _createTokensFromAppleCredential({
    String? idToken,
    String? authCode,
  }) {
    if (idToken == null) return null;

    // Placeholder tokens - in production, exchange with backend
    return AuthTokens(
      accessToken: idToken,
      refreshToken: authCode ?? 'apple-refresh-${_uuid.v4()}',
      accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
      refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Creates tokens from Google authentication.
  AuthTokens? _createTokensFromGoogleAuth(GoogleSignInAuthentication auth) {
    final accessToken = auth.accessToken;
    if (accessToken == null) return null;

    // Google access tokens typically last 1 hour, but we follow PRD's 15-min pattern
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: 'google-refresh-${_uuid.v4()}',
      accessTokenExpiry: DateTime.now().add(const Duration(minutes: 15)),
      refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
    );
  }
}
