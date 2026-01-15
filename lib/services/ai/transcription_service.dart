import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Conditional import for platform-specific code
import 'transcription_io.dart' if (dart.library.html) 'transcription_web.dart'
    as platform;

/// Configuration for transcription services.
class TranscriptionConfig {
  /// Deepgram API key.
  final String? deepgramApiKey;

  /// OpenAI API key (for Whisper fallback).
  final String? openaiApiKey;

  /// Request timeout duration.
  final Duration timeout;

  /// Maximum retry attempts.
  final int maxRetries;

  /// Base retry delay (will be multiplied by 2^attempt).
  final Duration baseRetryDelay;

  /// Number of Deepgram failures before falling back to Whisper.
  final int fallbackThreshold;

  const TranscriptionConfig({
    this.deepgramApiKey,
    this.openaiApiKey,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(seconds: 1),
    this.fallbackThreshold = 3,
  });

  /// Creates config from environment variables.
  factory TranscriptionConfig.fromEnvironment() {
    return TranscriptionConfig(
      deepgramApiKey: platform.getEnvironmentVariable('DEEPGRAM_API_KEY'),
      openaiApiKey: platform.getEnvironmentVariable('OPENAI_API_KEY'),
    );
  }

  /// Whether Deepgram is configured.
  bool get hasDeepgram =>
      deepgramApiKey != null && deepgramApiKey!.isNotEmpty;

  /// Whether OpenAI (Whisper) is configured.
  bool get hasWhisper => openaiApiKey != null && openaiApiKey!.isNotEmpty;

  /// Whether any transcription service is available.
  bool get isConfigured => hasDeepgram || hasWhisper;
}

/// Error from transcription service.
class TranscriptionError implements Exception {
  final String message;
  final String? code;
  final bool isRetryable;
  final TranscriptionProvider? provider;

  const TranscriptionError({
    required this.message,
    this.code,
    this.isRetryable = false,
    this.provider,
  });

  @override
  String toString() =>
      'TranscriptionError: $message (provider: ${provider?.name ?? "unknown"})';
}

/// Transcription provider types.
enum TranscriptionProvider {
  /// Deepgram Nova-2.
  deepgram,

  /// OpenAI Whisper.
  whisper,

  /// Mock provider for testing.
  mock,
}

/// Result from a transcription operation.
class TranscriptionResult {
  /// The transcribed text.
  final String text;

  /// Which provider was used.
  final TranscriptionProvider provider;

  /// Duration of the audio in seconds.
  final double? audioDuration;

  /// Confidence score (0.0 to 1.0) if available.
  final double? confidence;

  /// Time taken to transcribe.
  final Duration transcriptionTime;

  const TranscriptionResult({
    required this.text,
    required this.provider,
    required this.transcriptionTime,
    this.audioDuration,
    this.confidence,
  });
}

/// State for tracking pending transcriptions (offline queue).
class PendingTranscription {
  /// Unique ID for this transcription.
  final String id;

  /// Path to the audio file.
  final String audioFilePath;

  /// When this was queued.
  final DateTime queuedAt;

  /// Number of attempts made.
  final int attempts;

  /// Last error if any.
  final String? lastError;

  const PendingTranscription({
    required this.id,
    required this.audioFilePath,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  PendingTranscription copyWith({
    int? attempts,
    String? lastError,
  }) {
    return PendingTranscription(
      id: id,
      audioFilePath: audioFilePath,
      queuedAt: queuedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Service for transcribing audio files to text.
///
/// Per PRD Section 3A.1:
/// - Deepgram Nova-2 for speech-to-text
/// - Batch transcription (not streaming)
/// - Target <2 seconds from stop to transcript display
/// - Retry with exponential backoff (1s, 2s, 4s)
/// - Fallback to OpenAI Whisper on 3+ failures
class TranscriptionService {
  final TranscriptionConfig config;
  final http.Client _httpClient;

  /// Count of consecutive Deepgram failures (for fallback logic).
  int _deepgramFailureCount = 0;

  /// Queue of pending transcriptions for offline mode.
  final List<PendingTranscription> _pendingQueue = [];

  TranscriptionService({
    TranscriptionConfig? config,
    http.Client? httpClient,
  })  : config = config ?? TranscriptionConfig.fromEnvironment(),
        _httpClient = httpClient ?? http.Client();

  /// Queue of pending offline transcriptions.
  List<PendingTranscription> get pendingTranscriptions =>
      List.unmodifiable(_pendingQueue);

  /// Whether the service is configured and available.
  bool get isConfigured => config.isConfigured;

  /// Transcribes audio bytes using the best available provider.
  ///
  /// Tries Deepgram first, falls back to Whisper on repeated failures.
  /// Throws [TranscriptionError] on failure.
  ///
  /// [audioBytes] - The raw audio data
  /// [mimeType] - The MIME type of the audio (e.g., 'audio/wav', 'audio/m4a')
  /// [fileName] - Optional file name for APIs that require it
  Future<TranscriptionResult> transcribeBytes(
    Uint8List audioBytes, {
    required String mimeType,
    String fileName = 'audio.wav',
  }) async {
    if (!config.isConfigured) {
      throw const TranscriptionError(
        message: 'No transcription service configured',
        code: 'not_configured',
      );
    }

    if (audioBytes.isEmpty) {
      throw const TranscriptionError(
        message: 'Audio data is empty',
        code: 'empty_audio',
      );
    }

    final stopwatch = Stopwatch()..start();

    // Determine which provider to use
    final shouldUseWhisper = !config.hasDeepgram ||
        _deepgramFailureCount >= config.fallbackThreshold;

    if (shouldUseWhisper && config.hasWhisper) {
      return _transcribeBytesWithWhisper(audioBytes, mimeType, fileName, stopwatch);
    }

    if (config.hasDeepgram) {
      try {
        final result = await _transcribeBytesWithDeepgram(audioBytes, mimeType, stopwatch);
        _deepgramFailureCount = 0; // Reset on success
        return result;
      } on TranscriptionError catch (e) {
        _deepgramFailureCount++;

        // Try Whisper fallback if available and threshold reached
        if (config.hasWhisper &&
            _deepgramFailureCount >= config.fallbackThreshold) {
          return _transcribeBytesWithWhisper(audioBytes, mimeType, fileName, stopwatch);
        }

        rethrow;
      }
    }

    throw const TranscriptionError(
      message: 'No transcription service available',
      code: 'no_provider',
    );
  }

  /// Transcribes audio from a URL (typically a web blob URL).
  ///
  /// Fetches the audio data from the URL and transcribes it.
  /// Throws [TranscriptionError] on failure.
  Future<TranscriptionResult> transcribeFromUrl(
    String url, {
    String mimeType = 'audio/wav',
  }) async {
    try {
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw TranscriptionError(
          message: 'Failed to fetch audio from URL: ${response.statusCode}',
          code: 'fetch_failed',
        );
      }

      return transcribeBytes(
        response.bodyBytes,
        mimeType: mimeType,
        fileName: 'recording.wav',
      );
    } catch (e) {
      if (e is TranscriptionError) rethrow;
      throw TranscriptionError(
        message: 'Failed to fetch audio: $e',
        code: 'fetch_error',
      );
    }
  }

  /// Transcribes an audio file using the best available provider.
  /// This method is for mobile platforms only.
  ///
  /// Tries Deepgram first, falls back to Whisper on repeated failures.
  /// Throws [TranscriptionError] on failure.
  Future<TranscriptionResult> transcribe(dynamic audioFile) async {
    if (kIsWeb) {
      throw const TranscriptionError(
        message: 'Use transcribeFromUrl() on web platform',
        code: 'wrong_method',
      );
    }

    final file = audioFile as platform.FileType;

    if (!config.isConfigured) {
      throw const TranscriptionError(
        message: 'No transcription service configured',
        code: 'not_configured',
      );
    }

    if (!await platform.fileExists(file)) {
      throw TranscriptionError(
        message: 'Audio file not found: ${platform.getFilePath(file)}',
        code: 'file_not_found',
      );
    }

    final audioBytes = await platform.readFileBytes(file);
    return transcribeBytes(
      audioBytes,
      mimeType: 'audio/m4a',
      fileName: 'recording.m4a',
    );
  }

  /// Transcribes with fallback logic built-in.
  ///
  /// Convenience method that handles provider selection automatically.
  Future<TranscriptionResult> transcribeWithFallback(dynamic audioFile) async {
    return transcribe(audioFile);
  }

  /// Transcribes bytes using Deepgram Nova-2.
  Future<TranscriptionResult> _transcribeBytesWithDeepgram(
    Uint8List audioBytes,
    String mimeType,
    Stopwatch stopwatch,
  ) async {
    return _retryWithBackoff(() async {
      final url = Uri.parse(
        'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true',
      );

      final response = await _httpClient
          .post(
            url,
            headers: {
              'Authorization': 'Token ${config.deepgramApiKey}',
              'Content-Type': mimeType,
            },
            body: audioBytes,
          )
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        final isRetryable =
            response.statusCode == 429 || response.statusCode >= 500;
        throw TranscriptionError(
          message: 'Deepgram API error: ${response.statusCode}',
          code: 'deepgram_error',
          isRetryable: isRetryable,
          provider: TranscriptionProvider.deepgram,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as Map<String, dynamic>?;
      final channels = results?['channels'] as List<dynamic>?;
      final firstChannel = channels?.firstOrNull as Map<String, dynamic>?;
      final alternatives =
          firstChannel?['alternatives'] as List<dynamic>?;
      final firstAlt = alternatives?.firstOrNull as Map<String, dynamic>?;

      final transcript = firstAlt?['transcript'] as String? ?? '';
      final confidence = firstAlt?['confidence'] as double?;

      // Get audio duration from metadata
      final metadata = json['metadata'] as Map<String, dynamic>?;
      final duration = metadata?['duration'] as double?;

      stopwatch.stop();

      return TranscriptionResult(
        text: transcript,
        provider: TranscriptionProvider.deepgram,
        transcriptionTime: stopwatch.elapsed,
        audioDuration: duration,
        confidence: confidence,
      );
    });
  }

  /// Transcribes bytes using OpenAI Whisper.
  Future<TranscriptionResult> _transcribeBytesWithWhisper(
    Uint8List audioBytes,
    String mimeType,
    String fileName,
    Stopwatch stopwatch,
  ) async {
    return _retryWithBackoff(() async {
      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer ${config.openaiApiKey}';
      request.fields['model'] = 'whisper-1';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(config.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final isRetryable =
            response.statusCode == 429 || response.statusCode >= 500;
        throw TranscriptionError(
          message: 'Whisper API error: ${response.statusCode}',
          code: 'whisper_error',
          isRetryable: isRetryable,
          provider: TranscriptionProvider.whisper,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final transcript = json['text'] as String? ?? '';

      stopwatch.stop();

      return TranscriptionResult(
        text: transcript,
        provider: TranscriptionProvider.whisper,
        transcriptionTime: stopwatch.elapsed,
      );
    });
  }

  /// Retries an operation with exponential backoff.
  Future<T> _retryWithBackoff<T>(Future<T> Function() operation) async {
    TranscriptionError? lastError;

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        return await operation();
      } on TranscriptionError catch (e) {
        lastError = e;

        if (!e.isRetryable || attempt >= config.maxRetries) {
          rethrow;
        }

        // Exponential backoff: 1s, 2s, 4s
        final delay = config.baseRetryDelay * (1 << attempt);
        await Future.delayed(delay);
      } on TimeoutException {
        lastError = TranscriptionError(
          message: 'Request timed out',
          code: 'timeout',
          isRetryable: true,
          provider: lastError?.provider,
        );

        if (attempt >= config.maxRetries) {
          throw lastError;
        }

        final delay = config.baseRetryDelay * (1 << attempt);
        await Future.delayed(delay);
      }
    }

    throw lastError ??
        const TranscriptionError(
          message: 'Unknown error during transcription',
          code: 'unknown',
        );
  }

  /// Queues a file for later transcription (offline mode).
  ///
  /// Returns the ID of the queued transcription.
  String queueForLater(String audioFilePath) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _pendingQueue.add(PendingTranscription(
      id: id,
      audioFilePath: audioFilePath,
      queuedAt: DateTime.now(),
    ));
    return id;
  }

  /// Processes pending transcriptions.
  /// Note: This method only works on mobile platforms (not web).
  ///
  /// Returns a list of successful transcription results.
  Future<List<TranscriptionResult>> processPendingQueue() async {
    if (kIsWeb) {
      // Offline queue is not supported on web
      return [];
    }

    final results = <TranscriptionResult>[];
    final toRemove = <String>[];

    for (final pending in _pendingQueue) {
      try {
        final file = platform.createFile(pending.audioFilePath);
        if (!await platform.fileExists(file)) {
          // File was deleted, remove from queue
          toRemove.add(pending.id);
          continue;
        }

        final result = await transcribe(file);
        results.add(result);
        toRemove.add(pending.id);

        // Delete the audio file after successful transcription
        await platform.deleteFile(file);
      } on TranscriptionError {
        // Update attempt count but keep in queue
        final index = _pendingQueue.indexWhere((p) => p.id == pending.id);
        if (index >= 0) {
          _pendingQueue[index] = pending.copyWith(
            attempts: pending.attempts + 1,
          );
        }
      }
    }

    // Remove successfully processed items
    _pendingQueue.removeWhere((p) => toRemove.contains(p.id));

    return results;
  }

  /// Removes a pending transcription from the queue.
  void removePending(String id) {
    _pendingQueue.removeWhere((p) => p.id == id);
  }

  /// Clears all pending transcriptions.
  void clearPendingQueue() {
    _pendingQueue.clear();
  }

  /// Closes the HTTP client.
  void close() {
    _httpClient.close();
  }
}
