import 'dart:io';

import 'package:boardroom_journal/services/ai/transcription_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TranscriptionConfig', () {
    test('has correct default values', () {
      const config = TranscriptionConfig();

      expect(config.deepgramApiKey, isNull);
      expect(config.openaiApiKey, isNull);
      expect(config.timeout, const Duration(seconds: 30));
      expect(config.maxRetries, 3);
      expect(config.baseRetryDelay, const Duration(seconds: 1));
      expect(config.fallbackThreshold, 3);
    });

    test('hasDeepgram returns correct value', () {
      const configWithDeepgram = TranscriptionConfig(
        deepgramApiKey: 'test-key',
      );
      const configWithoutDeepgram = TranscriptionConfig();
      const configWithEmptyKey = TranscriptionConfig(
        deepgramApiKey: '',
      );

      expect(configWithDeepgram.hasDeepgram, true);
      expect(configWithoutDeepgram.hasDeepgram, false);
      expect(configWithEmptyKey.hasDeepgram, false);
    });

    test('hasWhisper returns correct value', () {
      const configWithWhisper = TranscriptionConfig(
        openaiApiKey: 'test-key',
      );
      const configWithoutWhisper = TranscriptionConfig();
      const configWithEmptyKey = TranscriptionConfig(
        openaiApiKey: '',
      );

      expect(configWithWhisper.hasWhisper, true);
      expect(configWithoutWhisper.hasWhisper, false);
      expect(configWithEmptyKey.hasWhisper, false);
    });

    test('isConfigured returns correct value', () {
      const configBoth = TranscriptionConfig(
        deepgramApiKey: 'dg-key',
        openaiApiKey: 'oai-key',
      );
      const configDeepgramOnly = TranscriptionConfig(
        deepgramApiKey: 'dg-key',
      );
      const configWhisperOnly = TranscriptionConfig(
        openaiApiKey: 'oai-key',
      );
      const configNone = TranscriptionConfig();

      expect(configBoth.isConfigured, true);
      expect(configDeepgramOnly.isConfigured, true);
      expect(configWhisperOnly.isConfigured, true);
      expect(configNone.isConfigured, false);
    });
  });

  group('TranscriptionError', () {
    test('creates error with message', () {
      const error = TranscriptionError(message: 'Test error');

      expect(error.message, 'Test error');
      expect(error.code, isNull);
      expect(error.isRetryable, false);
      expect(error.provider, isNull);
    });

    test('creates retryable error', () {
      const error = TranscriptionError(
        message: 'Rate limited',
        code: 'rate_limit',
        isRetryable: true,
        provider: TranscriptionProvider.deepgram,
      );

      expect(error.isRetryable, true);
      expect(error.provider, TranscriptionProvider.deepgram);
    });

    test('toString includes provider name', () {
      const error = TranscriptionError(
        message: 'API error',
        provider: TranscriptionProvider.whisper,
      );

      expect(error.toString(), contains('whisper'));
    });
  });

  group('TranscriptionResult', () {
    test('holds correct values', () {
      const result = TranscriptionResult(
        text: 'Hello world',
        provider: TranscriptionProvider.deepgram,
        transcriptionTime: Duration(milliseconds: 1500),
        audioDuration: 10.5,
        confidence: 0.95,
      );

      expect(result.text, 'Hello world');
      expect(result.provider, TranscriptionProvider.deepgram);
      expect(result.transcriptionTime, const Duration(milliseconds: 1500));
      expect(result.audioDuration, 10.5);
      expect(result.confidence, 0.95);
    });
  });

  group('PendingTranscription', () {
    test('creates with correct values', () {
      final now = DateTime.now();
      final pending = PendingTranscription(
        id: '123',
        audioFilePath: '/path/to/audio.m4a',
        queuedAt: now,
      );

      expect(pending.id, '123');
      expect(pending.audioFilePath, '/path/to/audio.m4a');
      expect(pending.queuedAt, now);
      expect(pending.attempts, 0);
      expect(pending.lastError, isNull);
    });

    test('copyWith updates values', () {
      final pending = PendingTranscription(
        id: '123',
        audioFilePath: '/path/to/audio.m4a',
        queuedAt: DateTime.now(),
      );

      final updated = pending.copyWith(
        attempts: 2,
        lastError: 'Network error',
      );

      expect(updated.id, '123'); // Unchanged
      expect(updated.attempts, 2);
      expect(updated.lastError, 'Network error');
    });
  });

  group('TranscriptionProvider', () {
    test('has all expected providers', () {
      expect(TranscriptionProvider.values, contains(TranscriptionProvider.deepgram));
      expect(TranscriptionProvider.values, contains(TranscriptionProvider.whisper));
      expect(TranscriptionProvider.values, contains(TranscriptionProvider.mock));
    });
  });

  group('TranscriptionService', () {
    test('isConfigured returns correct value', () {
      final serviceConfigured = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );
      final serviceNotConfigured = TranscriptionService(
        config: const TranscriptionConfig(),
      );

      expect(serviceConfigured.isConfigured, true);
      expect(serviceNotConfigured.isConfigured, false);
    });

    test('pendingTranscriptions starts empty', () {
      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );

      expect(service.pendingTranscriptions, isEmpty);
    });

    test('queueForLater adds to pending queue', () {
      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );

      final id = service.queueForLater('/path/to/audio.m4a');

      expect(service.pendingTranscriptions, hasLength(1));
      expect(service.pendingTranscriptions.first.id, id);
      expect(service.pendingTranscriptions.first.audioFilePath, '/path/to/audio.m4a');
    });

    test('removePending removes from queue', () {
      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );

      final id = service.queueForLater('/path/to/audio.m4a');
      service.removePending(id);

      expect(service.pendingTranscriptions, isEmpty);
    });

    test('clearPendingQueue clears all', () {
      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );

      service.queueForLater('/path/to/audio1.m4a');
      service.queueForLater('/path/to/audio2.m4a');
      service.clearPendingQueue();

      expect(service.pendingTranscriptions, isEmpty);
    });

    test('transcribe throws when not configured', () async {
      final service = TranscriptionService(
        config: const TranscriptionConfig(),
      );

      expect(
        () => service.transcribe(File('/path/to/audio.m4a')),
        throwsA(isA<TranscriptionError>().having(
          (e) => e.code,
          'code',
          'not_configured',
        )),
      );
    });

    test('transcribe throws when file not found', () async {
      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
      );

      expect(
        () => service.transcribe(File('/nonexistent/path/audio.m4a')),
        throwsA(isA<TranscriptionError>().having(
          (e) => e.code,
          'code',
          'file_not_found',
        )),
      );
    });

    group('Deepgram transcription', () {
      test('parses successful response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('api.deepgram.com'));
          expect(request.headers['Authorization'], 'Token test-key');

          return http.Response(
            '''
{
  "metadata": {
    "duration": 10.5
  },
  "results": {
    "channels": [
      {
        "alternatives": [
          {
            "transcript": "Hello world, this is a test.",
            "confidence": 0.95
          }
        ]
      }
    ]
  }
}
''',
            200,
          );
        });

        final service = TranscriptionService(
          config: const TranscriptionConfig(
            deepgramApiKey: 'test-key',
            maxRetries: 0,
          ),
          httpClient: mockClient,
        );

        // Create a temporary file for testing
        final tempDir = Directory.systemTemp.createTempSync('test_');
        final tempFile = File('${tempDir.path}/test_audio.m4a');
        tempFile.writeAsBytesSync([0, 1, 2, 3]); // Dummy audio data

        try {
          final result = await service.transcribe(tempFile);

          expect(result.text, 'Hello world, this is a test.');
          expect(result.provider, TranscriptionProvider.deepgram);
          expect(result.audioDuration, 10.5);
          expect(result.confidence, 0.95);
        } finally {
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      });

      test('handles API error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"error": "Invalid API key"}',
            401,
          );
        });

        final service = TranscriptionService(
          config: const TranscriptionConfig(
            deepgramApiKey: 'invalid-key',
            maxRetries: 0,
          ),
          httpClient: mockClient,
        );

        final tempDir = Directory.systemTemp.createTempSync('test_');
        final tempFile = File('${tempDir.path}/test_audio.m4a');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        try {
          expect(
            () => service.transcribe(tempFile),
            throwsA(isA<TranscriptionError>().having(
              (e) => e.provider,
              'provider',
              TranscriptionProvider.deepgram,
            )),
          );
        } finally {
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      });

      test('retries on rate limit', () async {
        var attempts = 0;
        final mockClient = MockClient((request) async {
          attempts++;
          if (attempts < 2) {
            return http.Response('{"error": "Rate limited"}', 429);
          }
          return http.Response(
            '''
{
  "results": {
    "channels": [
      {
        "alternatives": [
          {
            "transcript": "Success after retry",
            "confidence": 0.9
          }
        ]
      }
    ]
  }
}
''',
            200,
          );
        });

        final service = TranscriptionService(
          config: const TranscriptionConfig(
            deepgramApiKey: 'test-key',
            maxRetries: 3,
            baseRetryDelay: Duration(milliseconds: 10), // Fast retry for tests
          ),
          httpClient: mockClient,
        );

        final tempDir = Directory.systemTemp.createTempSync('test_');
        final tempFile = File('${tempDir.path}/test_audio.m4a');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        try {
          final result = await service.transcribe(tempFile);

          expect(attempts, 2);
          expect(result.text, 'Success after retry');
        } finally {
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      });
    });

    group('Whisper fallback', () {
      test('falls back to Whisper after Deepgram failures', () async {
        var deepgramCalls = 0;
        var whisperCalls = 0;

        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('deepgram')) {
            deepgramCalls++;
            return http.Response('{"error": "Service unavailable"}', 503);
          }
          if (request.url.toString().contains('openai')) {
            whisperCalls++;
            return http.Response('{"text": "Whisper transcription"}', 200);
          }
          return http.Response('Not found', 404);
        });

        final service = TranscriptionService(
          config: const TranscriptionConfig(
            deepgramApiKey: 'dg-key',
            openaiApiKey: 'oai-key',
            maxRetries: 0,
            fallbackThreshold: 1, // Fall back after 1 failure
          ),
          httpClient: mockClient,
        );

        final tempDir = Directory.systemTemp.createTempSync('test_');
        final tempFile = File('${tempDir.path}/test_audio.m4a');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        try {
          // First call - Deepgram fails
          expect(
            () => service.transcribe(tempFile),
            throwsA(isA<TranscriptionError>()),
          );

          // Second call - should use Whisper due to fallback
          final result = await service.transcribe(tempFile);

          expect(result.provider, TranscriptionProvider.whisper);
          expect(result.text, 'Whisper transcription');
          expect(deepgramCalls, 1);
          expect(whisperCalls, 1);
        } finally {
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      });

      test('uses Whisper when only Whisper is configured', () async {
        var whisperCalls = 0;

        final mockClient = MockClient((request) async {
          if (request.url.toString().contains('openai')) {
            whisperCalls++;
            return http.Response('{"text": "Whisper only"}', 200);
          }
          return http.Response('Not found', 404);
        });

        final service = TranscriptionService(
          config: const TranscriptionConfig(
            openaiApiKey: 'oai-key',
          ),
          httpClient: mockClient,
        );

        final tempDir = Directory.systemTemp.createTempSync('test_');
        final tempFile = File('${tempDir.path}/test_audio.m4a');
        tempFile.writeAsBytesSync([0, 1, 2, 3]);

        try {
          final result = await service.transcribe(tempFile);

          expect(result.provider, TranscriptionProvider.whisper);
          expect(result.text, 'Whisper only');
          expect(whisperCalls, 1);
        } finally {
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      });
    });

    test('transcribeWithFallback calls transcribe', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '''
{
  "results": {
    "channels": [
      {
        "alternatives": [
          {
            "transcript": "Test transcription",
            "confidence": 0.9
          }
        ]
      }
    ]
  }
}
''',
          200,
        );
      });

      final service = TranscriptionService(
        config: const TranscriptionConfig(deepgramApiKey: 'test-key'),
        httpClient: mockClient,
      );

      final tempDir = Directory.systemTemp.createTempSync('test_');
      final tempFile = File('${tempDir.path}/test_audio.m4a');
      tempFile.writeAsBytesSync([0, 1, 2, 3]);

      try {
        final result = await service.transcribeWithFallback(tempFile);

        expect(result.text, 'Test transcription');
      } finally {
        tempFile.deleteSync();
        tempDir.deleteSync();
      }
    });
  });
}
