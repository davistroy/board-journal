import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../config/config.dart';

/// Service for JWT token creation and validation.
///
/// Per PRD Section 3A.2:
/// - Access tokens: 15-minute expiry
/// - Refresh tokens: 30-day expiry (opaque, stored hashed in database)
class JwtService {
  final Config _config;
  final SecretKey _secretKey;

  JwtService(this._config)
      : _secretKey = SecretKey(_config.jwtSecret);

  /// Create an access token for a user.
  ///
  /// Returns a JWT string with:
  /// - sub: user ID
  /// - email: user email
  /// - iat: issued at timestamp
  /// - exp: expiration timestamp (15 minutes by default)
  String createAccessToken({
    required String userId,
    required String email,
    Duration? expiry,
  }) {
    final effectiveExpiry = expiry ?? _config.jwtAccessTokenExpiry;
    final now = DateTime.now().toUtc();

    final jwt = JWT(
      {
        'sub': userId,
        'email': email,
        'type': 'access',
      },
      issuer: 'boardroom-journal',
      subject: userId,
      jwtId: _generateJti(),
    );

    return jwt.sign(
      _secretKey,
      expiresIn: effectiveExpiry,
    );
  }

  /// Validate an access token and extract its claims.
  ///
  /// Returns the decoded JWT payload if valid.
  /// Throws [JwtValidationError] if the token is invalid or expired.
  JwtPayload validateAccessToken(String token) {
    try {
      final jwt = JWT.verify(token, _secretKey);

      // Verify token type
      final payload = jwt.payload as Map<String, dynamic>;
      if (payload['type'] != 'access') {
        throw JwtValidationError('Invalid token type');
      }

      // Extract issuedAt from payload 'iat' claim
      final iatSeconds = payload['iat'] as int?;
      final issuedAt = iatSeconds != null
          ? DateTime.fromMillisecondsSinceEpoch(iatSeconds * 1000, isUtc: true)
          : null;

      return JwtPayload(
        userId: payload['sub'] as String,
        email: payload['email'] as String,
        issuedAt: issuedAt,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          (payload['exp'] as int) * 1000,
          isUtc: true,
        ),
      );
    } on JWTExpiredException {
      throw JwtValidationError('Token has expired');
    } on JWTInvalidException catch (e) {
      throw JwtValidationError('Invalid token: ${e.message}');
    } on JWTNotActiveException {
      throw JwtValidationError('Token not yet active');
    } catch (e) {
      throw JwtValidationError('Token validation failed: $e');
    }
  }

  /// Generate a refresh token.
  ///
  /// Returns an opaque refresh token string.
  /// The token should be stored hashed in the database.
  String generateRefreshToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hash a refresh token for storage.
  ///
  /// Uses SHA-256 to create a secure hash.
  String hashRefreshToken(String token) {
    final bytes = utf8.encode(token);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Calculate refresh token expiry date.
  DateTime calculateRefreshTokenExpiry() {
    return DateTime.now().toUtc().add(_config.jwtRefreshTokenExpiry);
  }

  /// Generate a unique JWT ID.
  String _generateJti() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// Decoded JWT payload.
class JwtPayload {
  final String userId;
  final String email;
  final DateTime? issuedAt;
  final DateTime expiresAt;

  JwtPayload({
    required this.userId,
    required this.email,
    this.issuedAt,
    required this.expiresAt,
  });

  /// Whether the token is expired.
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// Time remaining until expiry.
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  String toString() =>
      'JwtPayload(userId: $userId, email: $email, expiresAt: $expiresAt)';
}

/// Error thrown when JWT validation fails.
class JwtValidationError implements Exception {
  final String message;

  JwtValidationError(this.message);

  @override
  String toString() => 'JwtValidationError: $message';
}
