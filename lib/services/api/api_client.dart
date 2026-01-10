import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth.dart';
import 'api_config.dart';

/// Result of an API request.
class ApiResult<T> {
  /// Whether the request was successful.
  final bool success;

  /// The response data if successful.
  final T? data;

  /// Error message if failed.
  final String? error;

  /// HTTP status code.
  final int? statusCode;

  /// Whether the error was due to network/connectivity issues.
  final bool isNetworkError;

  /// Whether this is a conflict error (409).
  final bool isConflict;

  const ApiResult._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
    this.isNetworkError = false,
    this.isConflict = false,
  });

  /// Creates a successful result.
  factory ApiResult.success(T data, {int? statusCode}) {
    return ApiResult._(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }

  /// Creates a failure result.
  factory ApiResult.failure(
    String error, {
    int? statusCode,
    bool isNetworkError = false,
    bool isConflict = false,
  }) {
    return ApiResult._(
      success: false,
      error: error,
      statusCode: statusCode,
      isNetworkError: isNetworkError,
      isConflict: isConflict,
    );
  }
}

/// HTTP client with automatic auth header injection and token refresh.
///
/// Per requirements:
/// - Automatic auth header injection
/// - Token refresh on 401 responses
/// - Timeout handling (30 seconds default)
/// - Retry logic for transient failures
class ApiClient {
  final ApiConfig _config;
  final TokenStorage _tokenStorage;
  final AuthService _authService;
  final http.Client _httpClient;

  /// Flag to prevent concurrent token refresh attempts.
  bool _isRefreshing = false;

  /// Completer for waiting on token refresh.
  Completer<bool>? _refreshCompleter;

  /// Creates an ApiClient instance.
  ApiClient({
    required ApiConfig config,
    required TokenStorage tokenStorage,
    required AuthService authService,
    http.Client? httpClient,
  })  : _config = config,
        _tokenStorage = tokenStorage,
        _authService = authService,
        _httpClient = httpClient ?? http.Client();

  /// Builds the full URL for an endpoint.
  Uri _buildUrl(String endpoint, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('${_config.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  /// Gets the authorization headers.
  Future<Map<String, String>> _getAuthHeaders() async {
    final accessToken = await _tokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  /// Refreshes the token if needed before making a request.
  ///
  /// Per PRD: Proactive refresh when <5 minutes remaining.
  Future<void> _ensureValidToken() async {
    final needsRefresh = await _tokenStorage.needsProactiveRefresh();
    if (needsRefresh) {
      await _refreshToken();
    }
  }

  /// Refreshes the access token.
  ///
  /// Handles concurrent refresh requests by only performing one refresh
  /// and having all other callers wait for it.
  Future<bool> _refreshToken() async {
    // If already refreshing, wait for the current refresh to complete
    if (_isRefreshing && _refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();

    try {
      final result = await _authService.refreshToken();
      final success = result.success;
      _refreshCompleter!.complete(success);
      return success;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Performs a GET request.
  Future<ApiResult<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      () async {
        final url = _buildUrl(endpoint, queryParams: queryParams);
        final headers = requiresAuth ? await _getAuthHeaders() : {'Content-Type': 'application/json'};
        return _httpClient.get(url, headers: headers);
      },
      requiresAuth: requiresAuth,
    );
  }

  /// Performs a POST request.
  Future<ApiResult<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      () async {
        final url = _buildUrl(endpoint, queryParams: queryParams);
        final headers = requiresAuth ? await _getAuthHeaders() : {'Content-Type': 'application/json'};
        return _httpClient.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      requiresAuth: requiresAuth,
    );
  }

  /// Performs a PUT request.
  Future<ApiResult<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      () async {
        final url = _buildUrl(endpoint, queryParams: queryParams);
        final headers = requiresAuth ? await _getAuthHeaders() : {'Content-Type': 'application/json'};
        return _httpClient.put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      requiresAuth: requiresAuth,
    );
  }

  /// Performs a PATCH request.
  Future<ApiResult<Map<String, dynamic>>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      () async {
        final url = _buildUrl(endpoint, queryParams: queryParams);
        final headers = requiresAuth ? await _getAuthHeaders() : {'Content-Type': 'application/json'};
        return _httpClient.patch(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      },
      requiresAuth: requiresAuth,
    );
  }

  /// Performs a DELETE request.
  Future<ApiResult<Map<String, dynamic>>> delete(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    return _executeRequest(
      () async {
        final url = _buildUrl(endpoint, queryParams: queryParams);
        final headers = requiresAuth ? await _getAuthHeaders() : {'Content-Type': 'application/json'};
        return _httpClient.delete(url, headers: headers);
      },
      requiresAuth: requiresAuth,
    );
  }

  /// Executes a request with retry logic and token refresh handling.
  Future<ApiResult<Map<String, dynamic>>> _executeRequest(
    Future<http.Response> Function() requestFn, {
    bool requiresAuth = true,
    int attempt = 0,
  }) async {
    try {
      // Ensure valid token before request if auth is required
      if (requiresAuth) {
        await _ensureValidToken();
      }

      // Execute the request with timeout
      final response = await requestFn().timeout(_config.timeout);

      // Handle 401 Unauthorized
      if (response.statusCode == 401 && requiresAuth) {
        // Try to refresh the token
        final refreshed = await _refreshToken();
        if (refreshed && attempt == 0) {
          // Retry the request once after token refresh
          return _executeRequest(
            requestFn,
            requiresAuth: requiresAuth,
            attempt: attempt + 1,
          );
        }
        return ApiResult.failure(
          'Authentication failed. Please sign in again.',
          statusCode: 401,
        );
      }

      // Handle 409 Conflict
      if (response.statusCode == 409) {
        final body = _parseResponseBody(response);
        return ApiResult.failure(
          body?['error']?.toString() ?? 'Conflict detected',
          statusCode: 409,
          isConflict: true,
        );
      }

      // Handle other error status codes
      if (response.statusCode >= 400) {
        final body = _parseResponseBody(response);
        return ApiResult.failure(
          body?['error']?.toString() ?? 'Request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse successful response
      final body = _parseResponseBody(response);
      return ApiResult.success(
        body ?? {},
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      // Retry on timeout if attempts remaining
      if (attempt < _config.maxRetries) {
        await Future.delayed(_config.retryDelay(attempt));
        return _executeRequest(
          requestFn,
          requiresAuth: requiresAuth,
          attempt: attempt + 1,
        );
      }
      return ApiResult.failure(
        'Request timed out after ${_config.timeoutSeconds} seconds',
        isNetworkError: true,
      );
    } on SocketException catch (e) {
      // Network error - retry if attempts remaining
      if (attempt < _config.maxRetries) {
        await Future.delayed(_config.retryDelay(attempt));
        return _executeRequest(
          requestFn,
          requiresAuth: requiresAuth,
          attempt: attempt + 1,
        );
      }
      return ApiResult.failure(
        'Network error: ${e.message}',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      // HTTP client error - retry if attempts remaining
      if (attempt < _config.maxRetries) {
        await Future.delayed(_config.retryDelay(attempt));
        return _executeRequest(
          requestFn,
          requiresAuth: requiresAuth,
          attempt: attempt + 1,
        );
      }
      return ApiResult.failure(
        'HTTP error: ${e.message}',
        isNetworkError: true,
      );
    } catch (e) {
      return ApiResult.failure('Unexpected error: $e');
    }
  }

  /// Parses the response body as JSON.
  Map<String, dynamic>? _parseResponseBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      return {'raw': response.body};
    }
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
  }
}
