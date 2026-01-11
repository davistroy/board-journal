import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
      deepgramApiKey: Platform.environment['DEEPGRAM_API_KEY'],
      openaiApiKey: Platform.environment['OPENAI_API_KEY'],
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

  /// Transcribes an audio file using the best available provider.
  ///
  /// Tries Deepgram first, falls back to Whisper on repeated failures.
  /// Throws [TranscriptionError] on failure.
  Future<TranscriptionResult> transcribe(File audioFile) async {
    if (!config.isConfigured) {
      throw const TranscriptionError(
        message: 'No transcription service configured',
        code: 'not_configured',
      );
    }

    if (!await audioFile.exists()) {
      throw TranscriptionError(
        message: 'Audio file not found: ${audioFile.path}',
        code: 'file_not_found',
      );
    }

    final stopwatch = Stopwatch()..start();

    // Determine which provider to use
    final shouldUseWhisper = !config.hasDeepgram ||
        _deepgramFailureCount >= config.fallbackThreshold;

    if (shouldUseWhisper && config.hasWhisper) {
      return _transcribeWithWhisper(audioFile, stopwatch);
    }

    if (config.hasDeepgram) {
      try {
        final result = await _transcribeWithDeepgram(audioFile, stopwatch);
        _deepgramFailureCount = 0; // Reset on success
        return result;
      } on TranscriptionError catch (e) {
        _deepgramFailureCount++;

        // Try Whisper fallback if available and threshold reached
        if (config.hasWhisper &&
            _deepgramFailureCount >= config.fallbackThreshold) {
          return _transcribeWithWhisper(audioFile, stopwatch);
        }

        rethrow;
      }
    }

    throw const TranscriptionError(
      message: 'No transcription service available',
      code: 'no_provider',
    );
  }

  /// Transcribes with fallback logic built-in.
  ///
  /// Convenience method that handles provider selection automatically.
  Future<TranscriptionResult> transcribeWithFallback(File audioFile) async {
    return transcribe(audioFile);
  }

  /// Transcribes using Deepgram Nova-2.
  Future<TranscriptionResult> _transcribeWithDeepgram(
    File audioFile,
    Stopwatch stopwatch,
  ) async {
    final audioBytes = await audioFile.readAsBytes();

    return _retryWithBackoff(() async {
      final url = Uri.parse(
        'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true',
      );

      final response = await _httpClient
          .post(
            url,
            headers: {
              'Authorization': 'Token ${config.deepgramApiKey}',
              'Content-Type': 'audio/m4a',
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

  /// Transcribes using OpenAI Whisper.
  Future<TranscriptionResult> _transcribeWithWhisper(
    File audioFile,
    Stopwatch stopwatch,
  ) async {
    return _retryWithBackoff(() async {
      final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer ${config.openaiApiKey}';
      request.fields['model'] = 'whisper-1';
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
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
  ///
  /// Returns a list of successful transcription results.
  Future<List<TranscriptionResult>> processPendingQueue() async {
    final results = <TranscriptionResult>[];
    final toRemove = <String>[];

    for (final pending in _pendingQueue) {
      try {
        final file = File(pending.audioFilePath);
        if (!await file.exists()) {
          // File was deleted, remove from queue
          toRemove.add(pending.id);
          continue;
        }

        final result = await transcribe(file);
        results.add(result);
        toRemove.add(pending.id);

        // Delete the audio file after successful transcription
        await file.delete();
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
