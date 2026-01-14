import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

/// Service for Apple Sign-In authentication.
///
/// Handles:
/// - Apple ID token verification using JWKS (C1 security fix)
/// - Apple client secret generation (C3 security fix)
///
/// Apple JWKS endpoint: https://appleid.apple.com/auth/keys
/// Apple token endpoint: https://appleid.apple.com/auth/token
class AppleAuthService {
  static const String _appleJwksUrl = 'https://appleid.apple.com/auth/keys';
  static const String _appleIssuer = 'https://appleid.apple.com';

  final Config _config;
  final http.Client _httpClient;

  /// Cached JWKS keys with expiry.
  Map<String, ECPublicKey>? _cachedKeys;
  DateTime? _keysCacheExpiry;

  /// Cache duration for JWKS keys (1 hour).
  static const Duration _keysCacheDuration = Duration(hours: 1);

  AppleAuthService(this._config, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Verify an Apple ID token.
  ///
  /// Validates the token signature using Apple's public JWKS keys.
  /// Per C1 security fix: This properly verifies tokens against Apple's keys.
  ///
  /// Returns the verified claims if valid.
  /// Throws [AppleAuthError] if verification fails.
  Future<AppleIdTokenClaims> verifyIdToken(String idToken) async {
    try {
      // Decode header to get key ID
      final parts = idToken.split('.');
      if (parts.length != 3) {
        throw AppleAuthError('Invalid JWT format');
      }

      final headerJson =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
      final header = jsonDecode(headerJson) as Map<String, dynamic>;
      final keyId = header['kid'] as String?;
      final algorithm = header['alg'] as String?;

      if (keyId == null) {
        throw AppleAuthError('Missing key ID in token header');
      }

      if (algorithm != 'RS256' && algorithm != 'ES256') {
        throw AppleAuthError('Unsupported algorithm: $algorithm');
      }

      // Get the public key for this key ID
      final publicKey = await _getPublicKey(keyId);
      if (publicKey == null) {
        throw AppleAuthError('Unknown key ID: $keyId');
      }

      // Verify the token signature
      final jwt = JWT.verify(idToken, publicKey);
      final payload = jwt.payload as Map<String, dynamic>;

      // Validate issuer
      final issuer = payload['iss'] as String?;
      if (issuer != _appleIssuer) {
        throw AppleAuthError('Invalid issuer: $issuer');
      }

      // Validate audience (should be our client ID)
      final audience = payload['aud'] as String?;
      if (audience != _config.appleClientId) {
        throw AppleAuthError('Invalid audience: $audience');
      }

      // Validate expiration
      final expSeconds = payload['exp'] as int?;
      if (expSeconds == null) {
        throw AppleAuthError('Missing expiration claim');
      }
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true);
      if (DateTime.now().toUtc().isAfter(expiry)) {
        throw AppleAuthError('Token has expired');
      }

      // Extract claims
      return AppleIdTokenClaims(
        subject: payload['sub'] as String,
        email: payload['email'] as String?,
        emailVerified: payload['email_verified'] == true ||
            payload['email_verified'] == 'true',
        isPrivateEmail: payload['is_private_email'] == true ||
            payload['is_private_email'] == 'true',
        authTime: payload['auth_time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (payload['auth_time'] as int) * 1000,
                isUtc: true,
              )
            : null,
      );
    } on JWTExpiredException {
      throw AppleAuthError('Token has expired');
    } on JWTInvalidException catch (e) {
      throw AppleAuthError('Invalid token: ${e.message}');
    } on AppleAuthError {
      rethrow;
    } catch (e) {
      throw AppleAuthError('Token verification failed: $e');
    }
  }

  /// Generate Apple client secret JWT.
  ///
  /// Per C3 security fix: Generates a properly signed JWT for Apple OAuth.
  ///
  /// The client secret is a JWT signed with the app's private key containing:
  /// - iss: Team ID
  /// - iat: Current timestamp
  /// - exp: Expiration (max 6 months from now)
  /// - aud: https://appleid.apple.com
  /// - sub: Client ID (Service ID)
  ///
  /// Returns the signed JWT string.
  /// Throws [AppleAuthError] if configuration is missing or invalid.
  String generateClientSecret({Duration? expiry}) {
    // Validate configuration
    final teamId = _config.appleTeamId;
    final keyId = _config.appleKeyId;
    final privateKeyPem = _config.applePrivateKey;
    final clientId = _config.appleClientId;

    if (teamId == null || teamId.isEmpty) {
      throw AppleAuthError('Apple Team ID not configured');
    }
    if (keyId == null || keyId.isEmpty) {
      throw AppleAuthError('Apple Key ID not configured');
    }
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      throw AppleAuthError('Apple private key not configured');
    }
    if (clientId == null || clientId.isEmpty) {
      throw AppleAuthError('Apple Client ID not configured');
    }

    // Default expiry is 6 months (maximum allowed by Apple)
    final effectiveExpiry = expiry ?? const Duration(days: 180);

    // Create the JWT
    final jwt = JWT(
      {
        'iss': teamId,
        'sub': clientId,
        'aud': _appleIssuer,
      },
    );

    // Parse the private key and sign
    try {
      final privateKey = ECPrivateKey(privateKeyPem);

      return jwt.sign(
        privateKey,
        algorithm: JWTAlgorithm.ES256,
        expiresIn: effectiveExpiry,
      );
    } catch (e) {
      throw AppleAuthError('Failed to sign client secret: $e');
    }
  }

  /// Get the public key for a given key ID from Apple's JWKS.
  Future<ECPublicKey?> _getPublicKey(String keyId) async {
    // Check cache first
    if (_cachedKeys != null &&
        _keysCacheExpiry != null &&
        DateTime.now().isBefore(_keysCacheExpiry!)) {
      return _cachedKeys![keyId];
    }

    // Fetch fresh keys
    await _refreshJwksKeys();
    return _cachedKeys?[keyId];
  }

  /// Fetch and cache Apple's JWKS keys.
  Future<void> _refreshJwksKeys() async {
    try {
      final response = await _httpClient
          .get(Uri.parse(_appleJwksUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw AppleAuthError(
          'Failed to fetch Apple JWKS: ${response.statusCode}',
        );
      }

      final jwks = jsonDecode(response.body) as Map<String, dynamic>;
      final keys = jwks['keys'] as List<dynamic>;

      final keyMap = <String, ECPublicKey>{};
      for (final keyData in keys) {
        final key = keyData as Map<String, dynamic>;
        final keyId = key['kid'] as String?;
        if (keyId == null) continue;

        try {
          // Convert JWK to PEM format for dart_jsonwebtoken
          final publicKey = _jwkToECPublicKey(key);
          if (publicKey != null) {
            keyMap[keyId] = publicKey;
          }
        } catch (e) {
          // Skip invalid keys, continue with others
        }
      }

      _cachedKeys = keyMap;
      _keysCacheExpiry = DateTime.now().add(_keysCacheDuration);
    } catch (e) {
      if (e is AppleAuthError) rethrow;
      throw AppleAuthError('Failed to refresh JWKS keys: $e');
    }
  }

  /// Convert a JWK (JSON Web Key) to ECPublicKey.
  ECPublicKey? _jwkToECPublicKey(Map<String, dynamic> jwk) {
    final kty = jwk['kty'] as String?;
    final crv = jwk['crv'] as String?;
    final x = jwk['x'] as String?;
    final y = jwk['y'] as String?;

    if (kty != 'EC' || crv != 'P-256' || x == null || y == null) {
      return null;
    }

    // Decode the x and y coordinates
    final xBytes = base64Url.decode(base64Url.normalize(x));
    final yBytes = base64Url.decode(base64Url.normalize(y));

    // Construct PEM format for EC public key
    // This is a simplified approach; in production you might use pointycastle
    final pem = _constructECPublicKeyPem(xBytes, yBytes);

    try {
      return ECPublicKey(pem);
    } catch (e) {
      return null;
    }
  }

  /// Construct a PEM-formatted EC public key from x and y coordinates.
  ///
  /// Note: This is a simplified implementation for P-256 curve.
  String _constructECPublicKeyPem(List<int> x, List<int> y) {
    // EC public key in uncompressed format: 0x04 || x || y
    final publicKeyBytes = <int>[0x04, ...x, ...y];

    // P-256 curve OID: 1.2.840.10045.3.1.7
    // Algorithm identifier for EC public key
    final algorithmIdentifier = <int>[
      0x30,
      0x13, // SEQUENCE
      0x06,
      0x07,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x02,
      0x01, // OID ecPublicKey
      0x06,
      0x08,
      0x2a,
      0x86,
      0x48,
      0xce,
      0x3d,
      0x03,
      0x01,
      0x07, // OID P-256
    ];

    // BIT STRING encoding for the public key
    final bitString = <int>[
      0x03,
      publicKeyBytes.length + 1,
      0x00,
      ...publicKeyBytes,
    ];

    // Full SEQUENCE
    final fullLength = algorithmIdentifier.length + bitString.length;
    final der = <int>[
      0x30,
      if (fullLength > 127) ...[
        0x81,
        fullLength,
      ] else
        fullLength,
      ...algorithmIdentifier,
      ...bitString,
    ];

    // Encode as PEM
    final base64Der = base64.encode(der);
    final lines = <String>[];
    for (var i = 0; i < base64Der.length; i += 64) {
      final end = (i + 64 > base64Der.length) ? base64Der.length : i + 64;
      lines.add(base64Der.substring(i, end));
    }

    return '-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----';
  }

  /// Clear the JWKS cache (useful for testing).
  void clearCache() {
    _cachedKeys = null;
    _keysCacheExpiry = null;
  }
}

/// Claims from a verified Apple ID token.
class AppleIdTokenClaims {
  /// The unique identifier for the user (Apple user ID).
  final String subject;

  /// The user's email address (may be private/relay email).
  final String? email;

  /// Whether the email has been verified by Apple.
  final bool emailVerified;

  /// Whether the email is a private relay email.
  final bool isPrivateEmail;

  /// When the user authenticated.
  final DateTime? authTime;

  AppleIdTokenClaims({
    required this.subject,
    this.email,
    this.emailVerified = false,
    this.isPrivateEmail = false,
    this.authTime,
  });
}

/// Error from Apple authentication operations.
class AppleAuthError implements Exception {
  final String message;

  AppleAuthError(this.message);

  @override
  String toString() => 'AppleAuthError: $message';
}
