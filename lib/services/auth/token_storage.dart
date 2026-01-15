import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import for secure storage (not available on web)
import 'token_storage_io.dart' if (dart.library.html) 'token_storage_web.dart'
    as platform;

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
/// - Mobile: Tokens stored in Keychain (iOS) / Keystore (Android)
/// - Web: Tokens stored in localStorage (WARNING: less secure)
/// - Access token: 15-minute expiry (JWT)
/// - Refresh token: 30-day expiry (opaque)
class TokenStorage {
  /// Secure storage for mobile platforms (null on web).
  final platform.SecureStorageType? _secureStorage;

  /// SharedPreferences instance for web fallback.
  SharedPreferences? _prefs;

  /// Creates a TokenStorage instance.
  TokenStorage() : _secureStorage = kIsWeb ? null : platform.createSecureStorage();

  /// Creates a TokenStorage instance for testing.
  TokenStorage.forTesting({platform.SecureStorageType? secureStorage})
      : _secureStorage = secureStorage;

  /// Gets SharedPreferences instance (lazily initialized).
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Platform-adaptive write operation.
  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.setString(key, value);
    } else {
      await platform.write(_secureStorage!, key, value);
    }
  }

  /// Platform-adaptive read operation.
  Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      return prefs.getString(key);
    } else {
      return platform.read(_secureStorage!, key);
    }
  }

  /// Platform-adaptive delete operation.
  Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await _getPrefs();
      await prefs.remove(key);
    } else {
      await platform.delete(_secureStorage!, key);
    }
  }

  /// Saves authentication tokens.
  ///
  /// Stores access token, refresh token, and their expiry times.
  Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _write(_StorageKeys.accessToken, tokens.accessToken),
      _write(_StorageKeys.refreshToken, tokens.refreshToken),
      _write(
        _StorageKeys.accessTokenExpiry,
        tokens.accessTokenExpiry.toIso8601String(),
      ),
      _write(
        _StorageKeys.refreshTokenExpiry,
        tokens.refreshTokenExpiry.toIso8601String(),
      ),
    ]);
  }

  /// Retrieves the access token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getAccessToken() async {
    return _read(_StorageKeys.accessToken);
  }

  /// Retrieves the refresh token.
  ///
  /// Returns null if no token is stored.
  Future<String?> getRefreshToken() async {
    return _read(_StorageKeys.refreshToken);
  }

  /// Retrieves all stored tokens.
  ///
  /// Returns null if any token data is missing.
  Future<AuthTokens?> getTokens() async {
    final results = await Future.wait([
      _read(_StorageKeys.accessToken),
      _read(_StorageKeys.refreshToken),
      _read(_StorageKeys.accessTokenExpiry),
      _read(_StorageKeys.refreshTokenExpiry),
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
      _delete(_StorageKeys.accessToken),
      _delete(_StorageKeys.refreshToken),
      _delete(_StorageKeys.accessTokenExpiry),
      _delete(_StorageKeys.refreshTokenExpiry),
    ]);
  }

  /// Saves user information.
  Future<void> saveUser(AppUser user) async {
    final userJson = jsonEncode(user.toJson());
    await _write(_StorageKeys.user, userJson);
  }

  /// Retrieves stored user information.
  Future<AppUser?> getUser() async {
    final userJson = await _read(_StorageKeys.user);
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
    await _delete(_StorageKeys.user);
  }

  /// Saves onboarding completion status.
  Future<void> setOnboardingCompleted(bool completed) async {
    await _write(_StorageKeys.onboardingCompleted, completed.toString());
  }

  /// Checks if onboarding has been completed.
  Future<bool> isOnboardingCompleted() async {
    final value = await _read(_StorageKeys.onboardingCompleted);
    return value == 'true';
  }

  /// Clears all authentication data (tokens, user, onboarding status).
  Future<void> clearAll() async {
    await Future.wait([
      clearTokens(),
      clearUser(),
      _delete(_StorageKeys.onboardingCompleted),
    ]);
  }
}
