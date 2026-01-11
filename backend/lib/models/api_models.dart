import 'dart:convert';

/// API request/response models for the Boardroom Journal backend.

// ============================================
// Authentication Models
// ============================================

/// Request to exchange OAuth code for tokens.
class OAuthTokenRequest {
  final String code;
  final String? redirectUri;
  final Map<String, dynamic>? deviceInfo;

  OAuthTokenRequest({
    required this.code,
    this.redirectUri,
    this.deviceInfo,
  });

  factory OAuthTokenRequest.fromJson(Map<String, dynamic> json) {
    return OAuthTokenRequest(
      code: json['code'] as String,
      redirectUri: json['redirect_uri'] as String?,
      deviceInfo: json['device_info'] as Map<String, dynamic>?,
    );
  }
}

/// Response with access and refresh tokens.
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final UserInfo user;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    required this.user,
  });

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'token_type': tokenType,
        'user': user.toJson(),
      };
}

/// Request to refresh access token.
class RefreshTokenRequest {
  final String refreshToken;

  RefreshTokenRequest({required this.refreshToken});

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) {
    return RefreshTokenRequest(
      refreshToken: json['refresh_token'] as String,
    );
  }
}

/// User information.
class UserInfo {
  final String id;
  final String email;
  final String? name;
  final String provider;
  final DateTime createdAt;
  final DateTime? deleteScheduledAt;

  UserInfo({
    required this.id,
    required this.email,
    this.name,
    required this.provider,
    required this.createdAt,
    this.deleteScheduledAt,
  });

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    return UserInfo(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String?,
      provider: map['provider'] as String,
      createdAt: map['created_at_utc'] as DateTime,
      deleteScheduledAt: map['delete_scheduled_at_utc'] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'provider': provider,
        'created_at': createdAt.toIso8601String(),
        if (deleteScheduledAt != null)
          'delete_scheduled_at': deleteScheduledAt!.toIso8601String(),
      };
}

/// Session validation response.
class SessionResponse {
  final bool valid;
  final UserInfo? user;
  final int? expiresIn;

  SessionResponse({
    required this.valid,
    this.user,
    this.expiresIn,
  });

  Map<String, dynamic> toJson() => {
        'valid': valid,
        if (user != null) 'user': user!.toJson(),
        if (expiresIn != null) 'expires_in': expiresIn,
      };
}

// ============================================
// Account Models
// ============================================

/// Account information response.
class AccountResponse {
  final UserInfo user;
  final AccountStats stats;

  AccountResponse({
    required this.user,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'stats': stats.toJson(),
      };
}

/// Account statistics.
class AccountStats {
  final int totalEntries;
  final int totalBriefs;
  final int totalSessions;
  final int totalBets;
  final DateTime? lastEntryAt;
  final DateTime? lastSessionAt;

  AccountStats({
    required this.totalEntries,
    required this.totalBriefs,
    required this.totalSessions,
    required this.totalBets,
    this.lastEntryAt,
    this.lastSessionAt,
  });

  Map<String, dynamic> toJson() => {
        'total_entries': totalEntries,
        'total_briefs': totalBriefs,
        'total_sessions': totalSessions,
        'total_bets': totalBets,
        if (lastEntryAt != null) 'last_entry_at': lastEntryAt!.toIso8601String(),
        if (lastSessionAt != null)
          'last_session_at': lastSessionAt!.toIso8601String(),
      };
}

/// Account deletion response.
class AccountDeletionResponse {
  final bool scheduled;
  final DateTime deleteAt;
  final String message;

  AccountDeletionResponse({
    required this.scheduled,
    required this.deleteAt,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'scheduled': scheduled,
        'delete_at': deleteAt.toIso8601String(),
        'message': message,
      };
}

// ============================================
// AI Proxy Models
// ============================================

/// Transcription request.
class TranscribeRequest {
  final String audioBase64;
  final String mimeType;
  final String? language;

  TranscribeRequest({
    required this.audioBase64,
    required this.mimeType,
    this.language,
  });

  factory TranscribeRequest.fromJson(Map<String, dynamic> json) {
    return TranscribeRequest(
      audioBase64: json['audio_base64'] as String,
      mimeType: json['mime_type'] as String,
      language: json['language'] as String?,
    );
  }
}

/// Transcription response.
class TranscribeResponse {
  final String transcript;
  final double confidence;
  final int durationSeconds;
  final List<TranscriptWord>? words;

  TranscribeResponse({
    required this.transcript,
    required this.confidence,
    required this.durationSeconds,
    this.words,
  });

  Map<String, dynamic> toJson() => {
        'transcript': transcript,
        'confidence': confidence,
        'duration_seconds': durationSeconds,
        if (words != null) 'words': words!.map((w) => w.toJson()).toList(),
      };
}

/// Word-level transcription.
class TranscriptWord {
  final String word;
  final double start;
  final double end;
  final double confidence;

  TranscriptWord({
    required this.word,
    required this.start,
    required this.end,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'start': start,
        'end': end,
        'confidence': confidence,
      };
}

/// Signal extraction request.
class ExtractRequest {
  final String transcript;
  final String? entryId;

  ExtractRequest({
    required this.transcript,
    this.entryId,
  });

  factory ExtractRequest.fromJson(Map<String, dynamic> json) {
    return ExtractRequest(
      transcript: json['transcript'] as String,
      entryId: json['entry_id'] as String?,
    );
  }
}

/// Signal extraction response.
class ExtractResponse {
  final Map<String, List<String>> signals;

  ExtractResponse({required this.signals});

  Map<String, dynamic> toJson() => {
        'signals': signals,
      };
}

/// Brief generation request.
class GenerateRequest {
  final String type; // 'weekly_brief', 'board_review', etc.
  final Map<String, dynamic> context;
  final Map<String, dynamic>? options;

  GenerateRequest({
    required this.type,
    required this.context,
    this.options,
  });

  factory GenerateRequest.fromJson(Map<String, dynamic> json) {
    return GenerateRequest(
      type: json['type'] as String,
      context: json['context'] as Map<String, dynamic>,
      options: json['options'] as Map<String, dynamic>?,
    );
  }
}

/// Brief generation response.
class GenerateResponse {
  final String content;
  final int wordCount;
  final String model;

  GenerateResponse({
    required this.content,
    required this.wordCount,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'word_count': wordCount,
        'model': model,
      };
}

// ============================================
// Error Models
// ============================================

/// API error response.
class ApiError {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  ApiError({
    required this.code,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
      };

  @override
  String toString() => jsonEncode(toJson());

  // Common errors
  static ApiError unauthorized([String? message]) => ApiError(
        code: 'UNAUTHORIZED',
        message: message ?? 'Authentication required',
      );

  static ApiError forbidden([String? message]) => ApiError(
        code: 'FORBIDDEN',
        message: message ?? 'Access denied',
      );

  static ApiError notFound([String? message]) => ApiError(
        code: 'NOT_FOUND',
        message: message ?? 'Resource not found',
      );

  static ApiError badRequest(String message, [Map<String, dynamic>? details]) =>
      ApiError(
        code: 'BAD_REQUEST',
        message: message,
        details: details,
      );

  static ApiError rateLimited(String message, {Duration? retryAfter}) =>
      ApiError(
        code: 'RATE_LIMITED',
        message: message,
        details: retryAfter != null ? {'retry_after_seconds': retryAfter.inSeconds} : null,
      );

  static ApiError serverError([String? message]) => ApiError(
        code: 'INTERNAL_ERROR',
        message: message ?? 'An internal error occurred',
      );

  static ApiError serviceUnavailable([String? message]) => ApiError(
        code: 'SERVICE_UNAVAILABLE',
        message: message ?? 'Service temporarily unavailable',
      );

  static ApiError conflict(String message) => ApiError(
        code: 'CONFLICT',
        message: message,
      );

  static ApiError validationError(Map<String, String> errors) => ApiError(
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: {'errors': errors},
      );
}
