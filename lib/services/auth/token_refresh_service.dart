import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../api/api_config.dart';
import 'token_storage.dart';

/// Result of a token refresh operation.
class TokenRefreshResult {
  /// Whether the refresh was successful.
  final bool success;

  /// The new tokens, if successful.
  final AuthTokens? tokens;

  /// Error message, if failed.
  final String? error;

  /// Whether the user needs to re-authenticate.
  final bool requiresReauth;

  const TokenRefreshResult._({
    required this.success,
    this.tokens,
    this.error,
    this.requiresReauth = false,
  });

  /// Creates a successful refresh result.
  factory TokenRefreshResult.success(AuthTokens tokens) {
    return TokenRefreshResult._(
      success: true,
      tokens: tokens,
    );
  }

  /// Creates a failed refresh result.
  factory TokenRefreshResult.failure(String error,
      {bool requiresReauth = false}) {
    return TokenRefreshResult._(
      success: false,
      error: error,
      requiresReauth: requiresReauth,
    );
  }
}

/// Service for managing token lifecycle.
///
/// Per PRD Section 3A.2:
/// - Access token has 15-minute expiry
/// - Refresh token has 30-day expiry
/// - Proactive refresh when <5 minutes remaining
class TokenRefreshService {
  final TokenStorage _tokenStorage;
  final ApiConfig _apiConfig;
  final http.Client _httpClient;

  /// Timer for proactive token refresh.
  Timer? _refreshTimer;

  /// Callback invoked when tokens are refreshed.
  final void Function(AuthTokens tokens)? onTokensRefreshed;

  /// Creates a TokenRefreshService instance.
  TokenRefreshService({
    TokenStorage? tokenStorage,
    ApiConfig? apiConfig,
    http.Client? httpClient,
    this.onTokensRefreshed,
  })  : _tokenStorage = tokenStorage ?? TokenStorage(),
        _apiConfig = apiConfig ?? const ApiConfig(),
        _httpClient = httpClient ?? http.Client();

  /// Get the API base URL from configuration.
  String get _apiBaseUrl => _apiConfig.baseUrl;

  /// Refreshes the access token using the refresh token.
  ///
  /// Makes a POST request to /auth/refresh with the refresh token.
  Future<TokenRefreshResult> refreshToken() async {
    try {
      final tokens = await _tokenStorage.getTokens();

      if (tokens == null) {
        return TokenRefreshResult.failure('No tokens to refresh',
            requiresReauth: true);
      }

      if (tokens.isRefreshTokenExpired) {
        return TokenRefreshResult.failure(
            'Refresh token expired, please sign in again',
            requiresReauth: true);
      }

      // Exchange refresh token with backend
      final response = await _httpClient
          .post(
            Uri.parse('$_apiBaseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': tokens.refreshToken}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        // Refresh token is invalid or revoked
        return TokenRefreshResult.failure(
            'Session expired, please sign in again',
            requiresReauth: true);
      }

      if (response.statusCode != 200) {
        return TokenRefreshResult.failure(
            'Token refresh failed with status ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Parse new tokens from response
      final newTokens = AuthTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        accessTokenExpiry: DateTime.now().add(
          Duration(seconds: data['expires_in'] as int? ?? 900),
        ),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 30)),
      );

      await _tokenStorage.saveTokens(newTokens);
      onTokensRefreshed?.call(newTokens);

      return TokenRefreshResult.success(newTokens);
    } on TimeoutException {
      return TokenRefreshResult.failure(
          'Token refresh timed out, please check your connection');
    } on SocketException catch (e) {
      return TokenRefreshResult.failure(
          'Network error during token refresh: ${e.message}');
    } catch (e) {
      return TokenRefreshResult.failure('Token refresh failed: $e');
    }
  }

  /// Checks if the access token needs refresh.
  ///
  /// Returns true if expired or will expire within 5 minutes.
  Future<bool> needsRefresh() async {
    return _tokenStorage.needsProactiveRefresh();
  }

  /// Performs proactive token refresh if needed.
  ///
  /// Per PRD: Refresh when <5 minutes remaining.
  Future<TokenRefreshResult?> proactiveRefresh() async {
    final needs = await needsRefresh();
    if (needs) {
      return refreshToken();
    }
    return null;
  }

  /// Starts the proactive refresh timer.
  ///
  /// Checks every minute if refresh is needed.
  void startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => proactiveRefresh(),
    );
  }

  /// Stops the proactive refresh timer.
  void stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Disposes resources.
  void dispose() {
    stopRefreshTimer();
  }
}
