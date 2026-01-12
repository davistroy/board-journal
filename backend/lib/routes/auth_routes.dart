import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/config.dart';
import '../db/queries.dart';
import '../middleware/auth_middleware.dart';
import '../models/api_models.dart';
import '../services/apple_auth_service.dart';
import '../services/jwt_service.dart';

/// Authentication routes.
///
/// Per PRD Section 3A.2:
/// - POST /auth/oauth/{provider} - Exchange OAuth code for tokens
/// - POST /auth/refresh - Refresh access token
/// - GET /auth/session - Validate session
class AuthRoutes {
  final Config _config;
  final JwtService _jwtService;
  final Queries _queries;
  final AppleAuthService _appleAuthService;
  final Logger _logger = Logger('AuthRoutes');

  AuthRoutes(this._config, this._jwtService, this._queries)
      : _appleAuthService = AppleAuthService(_config);

  Router get router {
    final router = Router();

    // OAuth token exchange
    router.post('/oauth/<provider>', _handleOAuthToken);

    // Refresh token
    router.post('/refresh', _handleRefreshToken);

    // Session validation
    router.get('/session', _handleSessionValidation);

    // Logout (revoke refresh token)
    router.post('/logout', _handleLogout);

    return router;
  }

  /// Exchange OAuth authorization code for access and refresh tokens.
  Future<Response> _handleOAuthToken(Request request, String provider) async {
    // Validate provider
    if (provider != 'apple' && provider != 'google') {
      return _jsonResponse(
        400,
        ApiError.badRequest('Invalid provider. Must be "apple" or "google"').toJson(),
      );
    }

    // Parse request body
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tokenRequest = OAuthTokenRequest.fromJson(json);

    try {
      // Verify OAuth code with provider and get user info
      final oauthUser = await _verifyOAuthCode(provider, tokenRequest);

      if (oauthUser == null) {
        return _jsonResponse(
          401,
          ApiError.unauthorized('Invalid OAuth code').toJson(),
        );
      }

      // Find or create user
      var user = await _queries.getUserByProvider(
        provider,
        oauthUser.providerUserId,
      );

      final isNewUser = user == null;

      if (user == null) {
        // Create new user
        user = await _queries.createUser(
          email: oauthUser.email,
          name: oauthUser.name,
          provider: provider,
          providerUserId: oauthUser.providerUserId,
        );
      }

      // Check if account is scheduled for deletion
      if (user['delete_scheduled_at_utc'] != null) {
        // Cancel deletion if user logs in again
        await _queries.cancelAccountDeletion(user['id'] as String);
        user = await _queries.getUserById(user['id'] as String);
      }

      // Create tokens
      final accessToken = _jwtService.createAccessToken(
        userId: user!['id'] as String,
        email: user['email'] as String,
      );

      final refreshToken = _jwtService.generateRefreshToken();
      final refreshTokenHash = _jwtService.hashRefreshToken(refreshToken);
      final refreshTokenExpiry = _jwtService.calculateRefreshTokenExpiry();

      // Store refresh token
      await _queries.storeRefreshToken(
        userId: user['id'] as String,
        tokenHash: refreshTokenHash,
        expiresAt: refreshTokenExpiry,
        deviceInfo: tokenRequest.deviceInfo,
      );

      // Create response
      final response = TokenResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: _config.jwtAccessTokenExpiry.inSeconds,
        user: UserInfo.fromMap(user),
      );

      return _jsonResponse(
        isNewUser ? 201 : 200,
        response.toJson(),
      );
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Authentication failed').toJson(),
      );
    }
  }

  /// Refresh access token using refresh token.
  Future<Response> _handleRefreshToken(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final refreshRequest = RefreshTokenRequest.fromJson(json);

    // Hash the provided refresh token
    final tokenHash = _jwtService.hashRefreshToken(refreshRequest.refreshToken);

    // Find valid refresh token
    final tokenRecord = await _queries.findRefreshToken(tokenHash);

    if (tokenRecord == null) {
      return _jsonResponse(
        401,
        ApiError.unauthorized('Invalid or expired refresh token').toJson(),
      );
    }

    // Get user
    final userId = tokenRecord['user_id'] as String;
    final user = await _queries.getUserById(userId);

    if (user == null) {
      return _jsonResponse(
        401,
        ApiError.unauthorized('User not found').toJson(),
      );
    }

    // Revoke old refresh token
    await _queries.revokeRefreshToken(tokenHash);

    // Create new tokens
    final accessToken = _jwtService.createAccessToken(
      userId: user['id'] as String,
      email: user['email'] as String,
    );

    final newRefreshToken = _jwtService.generateRefreshToken();
    final newRefreshTokenHash = _jwtService.hashRefreshToken(newRefreshToken);
    final refreshTokenExpiry = _jwtService.calculateRefreshTokenExpiry();

    // Store new refresh token
    await _queries.storeRefreshToken(
      userId: userId,
      tokenHash: newRefreshTokenHash,
      expiresAt: refreshTokenExpiry,
    );

    final response = TokenResponse(
      accessToken: accessToken,
      refreshToken: newRefreshToken,
      expiresIn: _config.jwtAccessTokenExpiry.inSeconds,
      user: UserInfo.fromMap(user),
    );

    return _jsonResponse(200, response.toJson());
  }

  /// Validate current session and return user info.
  Future<Response> _handleSessionValidation(Request request) async {
    // This endpoint should be behind auth middleware
    final userId = request.userId;

    if (userId == null) {
      return _jsonResponse(
        200,
        SessionResponse(valid: false).toJson(),
      );
    }

    final user = await _queries.getUserById(userId);

    if (user == null) {
      return _jsonResponse(
        200,
        SessionResponse(valid: false).toJson(),
      );
    }

    final expiresAt = request.tokenExpiresAt;
    final expiresIn = expiresAt != null
        ? expiresAt.difference(DateTime.now().toUtc()).inSeconds
        : null;

    final response = SessionResponse(
      valid: true,
      user: UserInfo.fromMap(user),
      expiresIn: expiresIn != null && expiresIn > 0 ? expiresIn : null,
    );

    return _jsonResponse(200, response.toJson());
  }

  /// Logout - revoke refresh token.
  Future<Response> _handleLogout(Request request) async {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final refreshToken = json['refresh_token'] as String?;

    if (refreshToken != null) {
      final tokenHash = _jwtService.hashRefreshToken(refreshToken);
      await _queries.revokeRefreshToken(tokenHash);
    }

    // If user wants to revoke all sessions
    if (json['all_sessions'] == true) {
      final userId = request.userId;
      if (userId != null) {
        await _queries.revokeAllUserRefreshTokens(userId);
      }
    }

    return _jsonResponse(200, {'success': true});
  }

  /// Verify OAuth code with the provider.
  ///
  /// Makes real OAuth calls to Apple/Google in production.
  /// Uses mock data only in development/test environments.
  Future<OAuthUserInfo?> _verifyOAuthCode(
    String provider,
    OAuthTokenRequest request,
  ) async {
    // CRITICAL SECURITY: Only allow mock auth in non-production environments
    if (_config.isDevelopment || _config.isTest) {
      // Double-check environment to prevent misconfiguration
      if (_config.isProduction) {
        throw StateError(
          'SECURITY VIOLATION: Mock OAuth attempted in production environment. '
          'This indicates a misconfigured environment. Aborting.',
        );
      }
      // Mock response for development/testing only
      return OAuthUserInfo(
        providerUserId: 'mock_${provider}_${request.code.hashCode.abs()}',
        email: 'test@example.com',
        name: 'Test User',
      );
    }

    if (provider == 'apple') {
      return await _verifyAppleCode(request);
    } else if (provider == 'google') {
      return await _verifyGoogleCode(request);
    }

    return null;
  }

  /// Verify Apple OAuth code.
  ///
  /// Security hardening (C1, C3):
  /// - Generates proper client secret using Apple private key
  /// - Verifies ID token against Apple's JWKS public keys
  Future<OAuthUserInfo?> _verifyAppleCode(OAuthTokenRequest request) async {
    if (_config.appleClientId == null) {
      throw StateError('Apple OAuth not configured');
    }

    try {
      // Generate client secret using AppleAuthService (C3 fix)
      final clientSecret = _appleAuthService.generateClientSecret();

      // Exchange authorization code for tokens
      final response = await http.post(
        Uri.parse('https://appleid.apple.com/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _config.appleClientId,
          'client_secret': clientSecret,
          'code': request.code,
          'grant_type': 'authorization_code',
          if (request.redirectUri != null) 'redirect_uri': request.redirectUri,
        },
      );

      if (response.statusCode != 200) {
        _logger.warning('Apple token exchange failed: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = data['id_token'] as String;

      // Verify ID token using JWKS (C1 fix)
      final claims = await _appleAuthService.verifyIdToken(idToken);

      return OAuthUserInfo(
        providerUserId: claims.subject,
        email: claims.email ?? '',
        name: null, // Apple may not provide name
      );
    } on AppleAuthError catch (e) {
      _logger.warning('Apple authentication failed: ${e.message}');
      return null;
    } catch (e) {
      _logger.severe('Unexpected error in Apple auth: $e');
      return null;
    }
  }

  /// Verify Google OAuth code.
  Future<OAuthUserInfo?> _verifyGoogleCode(OAuthTokenRequest request) async {
    if (_config.googleClientId == null || _config.googleClientSecret == null) {
      throw StateError('Google OAuth not configured');
    }

    // Exchange authorization code for tokens
    final tokenResponse = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _config.googleClientId,
        'client_secret': _config.googleClientSecret,
        'code': request.code,
        'grant_type': 'authorization_code',
        if (request.redirectUri != null) 'redirect_uri': request.redirectUri,
      },
    );

    if (tokenResponse.statusCode != 200) {
      return null;
    }

    final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;

    // Get user info
    final userResponse = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (userResponse.statusCode != 200) {
      return null;
    }

    final userData = jsonDecode(userResponse.body) as Map<String, dynamic>;

    return OAuthUserInfo(
      providerUserId: userData['id'] as String,
      email: userData['email'] as String,
      name: userData['name'] as String?,
    );
  }

  // Note: _generateAppleClientSecret and _decodeJwtPayload removed.
  // Apple authentication now uses AppleAuthService for proper JWKS verification
  // and client secret generation (C1 and C3 security fixes).

  Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// User info from OAuth provider.
class OAuthUserInfo {
  final String providerUserId;
  final String email;
  final String? name;

  OAuthUserInfo({
    required this.providerUserId,
    required this.email,
    this.name,
  });
}
