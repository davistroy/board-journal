import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/models.dart';

/// Secure storage keys for auth data.
abstract class _StorageKeys {
  static const accessToken = 'auth_access_token';
  static const refreshToken = 'auth_refresh_token';
  static const accessTokenExpiry = 'auth_access_token_expiry';
  static const refreshTokenExpiry = 'auth_refresh_token_expiry';
  static const user = 'auth_user';
  static const onboardingCompleted = 'auth_onboarding_completed';
}

/// Secure token storage for authentication.
///
/// Per PRD requirements:
/// - Tokens stored in Keychain (iOS) / Keystore (Android)
/// - Access token: 15-minute expiry (JWT)
/// - Refresh token: 30-day expiry (opaque)
class TokenStorage {
  final FlutterSecureStorage _storage;

  /// Creates a TokenStorage instance.
  ///
  /// Optionally accepts a [FlutterSecureStorage] for testing.
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? _createSecureStorage();

  /// Creates secure storage with platform-appropriate options.
  static FlutterSecureStorage _createSecureStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  /// Saves authentication tokens.
  ///
  /// Stores access token, refresh token, and their expiry times.
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: tokens.accessToken),
      _storage.write(
          key: _StorageKeys.refreshToken, value: tokens.refreshToken),
      _storage.write(
        key: _StorageKeys.accessTokenExpiry,
        value: tokens.accessTokenExpiry.toIso8601String(),
      ),
      _storage.write(
        key: _StorageKeys.refreshTokenExpiry,
        value: tokens.refreshTokenExpiry.toIso8601String(),
      ),
    ]);
  }

  /// Retrieves the access token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _StorageKeys.accessToken);
  }

  /// Retrieves the refresh token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _StorageKeys.refreshToken);
  }

  /// Retrieves all stored tokens.
  ///
  /// Returns null if any token data is missing.
  Future<AuthTokens?> getTokens() async {
    final results = await Future.wait([
      _storage.read(key: _StorageKeys.accessToken),
      _storage.read(key: _StorageKeys.refreshToken),
      _storage.read(key: _StorageKeys.accessTokenExpiry),
      _storage.read(key: _StorageKeys.refreshTokenExpiry),
    ]);

    final accessToken = results[0];
    final refreshToken = results[1];
    final accessTokenExpiryStr = results[2];
    final refreshTokenExpiryStr = results[3];

    if (accessToken == null ||
        refreshToken == null ||
        accessTokenExpiryStr == null ||
        refreshTokenExpiryStr == null) {
      return null;
    }

    try {
      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiry: DateTime.parse(accessTokenExpiryStr),
        refreshTokenExpiry: DateTime.parse(refreshTokenExpiryStr),
      );
    } catch (e) {
      // Invalid stored data, clear it
      await clearTokens();
      return null;
    }
  }

  /// Checks if the access token is expired.
  ///
  /// Returns true if expired or no token exists.
  Future<bool> isAccessTokenExpired() async {
    final tokens = await getTokens();
    if (tokens == null) return true;
    return tokens.isAccessTokenExpired;
  }

  /// Checks if the refresh token is expired.
  ///
  /// Returns true if expired or no token exists.
  Future<bool> isRefreshTokenExpired() async {
    final tokens = await getTokens();
    if (tokens == null) return true;
    return tokens.isRefreshTokenExpired;
  }

  /// Checks if proactive refresh is needed (<5 min remaining).
  ///
  /// Per PRD: Proactive refresh when <5 minutes remaining.
  Future<bool> needsProactiveRefresh() async {
    final tokens = await getTokens();
    if (tokens == null) return false;
    return tokens.needsProactiveRefresh;
  }

  /// Clears all stored tokens.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _StorageKeys.accessToken),
      _storage.delete(key: _StorageKeys.refreshToken),
      _storage.delete(key: _StorageKeys.accessTokenExpiry),
      _storage.delete(key: _StorageKeys.refreshTokenExpiry),
    ]);
  }

  /// Saves user information.
  Future<void> saveUser(AppUser user) async {
    final userJson = jsonEncode(user.toJson());
    await _storage.write(key: _StorageKeys.user, value: userJson);
  }

  /// Retrieves stored user information.
  Future<AppUser?> getUser() async {
    final userJson = await _storage.read(key: _StorageKeys.user);
    if (userJson == null) return null;

    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return AppUser.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  /// Clears stored user information.
  Future<void> clearUser() async {
    await _storage.delete(key: _StorageKeys.user);
  }

  /// Saves onboarding completion status.
  Future<void> setOnboardingCompleted(bool completed) async {
    await _storage.write(
      key: _StorageKeys.onboardingCompleted,
      value: completed.toString(),
    );
  }

  /// Checks if onboarding has been completed.
  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: _StorageKeys.onboardingCompleted);
    return value == 'true';
  }

  /// Clears all authentication data (tokens, user, onboarding status).
  Future<void> clearAll() async {
    await Future.wait([
      clearTokens(),
      clearUser(),
      _storage.delete(key: _StorageKeys.onboardingCompleted),
    ]);
  }
}
