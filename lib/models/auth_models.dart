import 'package:equatable/equatable.dart';

/// Authentication state of the application.
///
/// Per PRD Section 5.0: Auth states for onboarding flow.
enum AuthStatus {
  /// Initial state before auth status is determined.
  initial,

  /// Loading auth state (checking stored tokens, refreshing, etc.)
  loading,

  /// User is authenticated with valid tokens.
  authenticated,

  /// User is not authenticated (no tokens or expired).
  unauthenticated,

  /// Authentication error occurred.
  error,
}

/// OAuth provider used for authentication.
enum AuthProvider {
  /// Apple Sign-In (required for iOS App Store).
  apple,

  /// Google Sign-In.
  google,

  /// Microsoft Sign-In.
  microsoft,

  /// Local-only mode (skipped sign-in).
  localOnly,
}

/// User information from authentication.
///
/// Contains the essential user data returned from OAuth providers.
class AppUser extends Equatable {
  /// Unique user identifier from the auth provider.
  final String id;

  /// User's email address.
  final String? email;

  /// User's display name.
  final String? name;

  /// OAuth provider used for authentication.
  final AuthProvider provider;

  /// When the user account was created.
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.email,
    this.name,
    required this.provider,
    required this.createdAt,
  });

  /// Creates a local-only user for skip sign-in mode.
  factory AppUser.localOnly() {
    return AppUser(
      id: 'local-user',
      email: null,
      name: 'Local User',
      provider: AuthProvider.localOnly,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a user from JSON map (for storage/API).
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      provider: AuthProvider.values.firstWhere(
        (p) => p.name == json['provider'],
        orElse: () => AuthProvider.localOnly,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts user to JSON map (for storage/API).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'provider': provider.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, email, name, provider, createdAt];
}

/// Authentication state container.
///
/// Holds the current auth status, user info, and any error messages.
class AuthState extends Equatable {
  /// Current authentication status.
  final AuthStatus status;

  /// Currently authenticated user, if any.
  final AppUser? user;

  /// Error message if status is [AuthStatus.error].
  final String? errorMessage;

  /// Whether onboarding has been completed.
  final bool onboardingCompleted;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.onboardingCompleted = false,
  });

  /// Initial auth state before any checking.
  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.initial,
    );
  }

  /// Loading state while checking auth.
  factory AuthState.loading() {
    return const AuthState(
      status: AuthStatus.loading,
    );
  }

  /// Authenticated state with user.
  factory AuthState.authenticated({
    required AppUser user,
    bool onboardingCompleted = true,
  }) {
    return AuthState(
      status: AuthStatus.authenticated,
      user: user,
      onboardingCompleted: onboardingCompleted,
    );
  }

  /// Unauthenticated state.
  factory AuthState.unauthenticated({bool onboardingCompleted = false}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      onboardingCompleted: onboardingCompleted,
    );
  }

  /// Error state with message.
  factory AuthState.error(String message) {
    return AuthState(
      status: AuthStatus.error,
      errorMessage: message,
    );
  }

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// Whether the user is in local-only mode.
  bool get isLocalOnly =>
      isAuthenticated && user?.provider == AuthProvider.localOnly;

  /// Creates a copy with updated fields.
  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? errorMessage,
    bool? onboardingCompleted,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, onboardingCompleted];
}

/// Token information for OAuth.
///
/// Per PRD requirements:
/// - Access token: 15-minute expiry (JWT)
/// - Refresh token: 30-day expiry (opaque)
class AuthTokens extends Equatable {
  /// JWT access token (15-min expiry).
  final String accessToken;

  /// Refresh token (30-day expiry).
  final String refreshToken;

  /// When the access token expires.
  final DateTime accessTokenExpiry;

  /// When the refresh token expires.
  final DateTime refreshTokenExpiry;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
    required this.refreshTokenExpiry,
  });

  /// Creates tokens from JSON (for storage).
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpiry: DateTime.parse(json['accessTokenExpiry'] as String),
      refreshTokenExpiry: DateTime.parse(json['refreshTokenExpiry'] as String),
    );
  }

  /// Converts to JSON (for storage).
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiry': accessTokenExpiry.toIso8601String(),
      'refreshTokenExpiry': refreshTokenExpiry.toIso8601String(),
    };
  }

  /// Whether the access token has expired.
  bool get isAccessTokenExpired => DateTime.now().isAfter(accessTokenExpiry);

  /// Whether the refresh token has expired.
  bool get isRefreshTokenExpired => DateTime.now().isAfter(refreshTokenExpiry);

  /// Whether the access token needs proactive refresh (<5 min remaining).
  /// Per PRD: Proactive refresh when <5 minutes remaining.
  bool get needsProactiveRefresh {
    final now = DateTime.now();
    final fiveMinutesBeforeExpiry =
        accessTokenExpiry.subtract(const Duration(minutes: 5));
    return now.isAfter(fiveMinutesBeforeExpiry);
  }

  /// Remaining time until access token expires.
  Duration get accessTokenTimeRemaining {
    final now = DateTime.now();
    if (now.isAfter(accessTokenExpiry)) {
      return Duration.zero;
    }
    return accessTokenExpiry.difference(now);
  }

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        accessTokenExpiry,
        refreshTokenExpiry,
      ];
}
