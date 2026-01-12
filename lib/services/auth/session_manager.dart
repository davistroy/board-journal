import '../../models/models.dart';
import 'token_storage.dart';

/// Manages the current user session state.
///
/// Responsible for:
/// - Checking authentication status
/// - Getting/setting current user
/// - Managing onboarding state
/// - Clearing session data
class SessionManager {
  final TokenStorage _tokenStorage;

  /// Creates a SessionManager instance.
  SessionManager({
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

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

  /// Gets the current auth tokens.
  ///
  /// Returns null if not authenticated.
  Future<AuthTokens?> getTokens() async {
    return _tokenStorage.getTokens();
  }

  /// Saves a user to the session.
  Future<void> saveUser(AppUser user) async {
    await _tokenStorage.saveUser(user);
  }

  /// Saves tokens to the session.
  Future<void> saveTokens(AuthTokens tokens) async {
    await _tokenStorage.saveTokens(tokens);
  }

  /// Checks if onboarding has been completed.
  Future<bool> isOnboardingCompleted() async {
    return _tokenStorage.isOnboardingCompleted();
  }

  /// Marks onboarding as completed.
  Future<void> completeOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(true);
  }

  /// Clears all session data.
  Future<void> clearSession() async {
    await _tokenStorage.clearAll();
  }

  /// Initializes and returns the current auth state.
  ///
  /// Call this on app startup.
  Future<AuthState> initialize() async {
    try {
      final isAuthed = await isAuthenticated();
      final user = await getCurrentUser();
      final onboardingCompleted = await isOnboardingCompleted();

      if (isAuthed && user != null) {
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
}
