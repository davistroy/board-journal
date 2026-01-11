import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/providers/audio_providers.dart';
import 'package:boardroom_journal/services/ai/transcription_service.dart';
import 'package:boardroom_journal/services/audio/audio_recorder_service.dart';

void main() {
  group('Audio Providers', () {
    group('transcriptionConfigProvider', () {
      test('creates TranscriptionConfig from environment', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final config = container.read(transcriptionConfigProvider);

        expect(config, isA<TranscriptionConfig>());
      });
    });

    group('audioRecorderServiceProvider', () {
      test('creates AudioRecorderService instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final service = container.read(audioRecorderServiceProvider);

        expect(service, isA<AudioRecorderService>());
      });
    });

    group('transcriptionServiceProvider', () {
      test('returns null when not configured', () {
        final container = ProviderContainer(
          overrides: [
            transcriptionConfigProvider.overrideWithValue(
              TranscriptionConfig(apiKey: null),
            ),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(transcriptionServiceProvider);

        expect(service, isNull);
      });
    });

    group('isTranscriptionConfiguredProvider', () {
      test('returns false when service is null', () {
        final container = ProviderContainer(
          overrides: [
            transcriptionServiceProvider.overrideWithValue(null),
          ],
        );
        addTearDown(container.dispose);

        final available = container.read(isTranscriptionConfiguredProvider);

        expect(available, isFalse);
      });
    });
  });

  group('VoiceRecordingPhase', () {
    test('has all expected phases', () {
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.idle));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.recording));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.paused));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.stopping));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.transcribing));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.editTranscript));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.extractingSignals));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.complete));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.error));
    });
  });

  group('VoiceRecordingState', () {
    test('initial state has correct defaults', () {
      const state = VoiceRecordingState();

      expect(state.phase, VoiceRecordingPhase.idle);
      expect(state.duration, Duration.zero);
      expect(state.audioFilePath, isNull);
      expect(state.transcript, isNull);
      expect(state.error, isNull);
      expect(state.waveformData, isEmpty);
      expect(state.silenceCountdown, isNull);
    });

    test('isRecording returns true during recording', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.recording);

      expect(state.isRecording, isTrue);
    });

    test('isRecording returns false when idle', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.idle);

      expect(state.isRecording, isFalse);
    });

    test('isPaused returns true when paused', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.paused);

      expect(state.isPaused, isTrue);
    });

    test('isProcessing returns true during transcribing', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.transcribing);

      expect(state.isProcessing, isTrue);
    });

    test('isProcessing returns true during extractingSignals', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.extractingSignals);

      expect(state.isProcessing, isTrue);
    });

    test('hasError returns true when error is set', () {
      const state = VoiceRecordingState(
        phase: VoiceRecordingPhase.error,
        error: 'Recording failed',
      );

      expect(state.hasError, isTrue);
    });

    test('canStartRecording returns true when idle', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.idle);

      expect(state.canStartRecording, isTrue);
    });

    test('canStartRecording returns true when error', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.error);

      expect(state.canStartRecording, isTrue);
    });

    test('canPauseRecording returns true when recording', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.recording);

      expect(state.canPauseRecording, isTrue);
    });

    test('canResumeRecording returns true when paused', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.paused);

      expect(state.canResumeRecording, isTrue);
    });

    test('canStopRecording returns true when recording', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.recording);

      expect(state.canStopRecording, isTrue);
    });

    test('canStopRecording returns true when paused', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.paused);

      expect(state.canStopRecording, isTrue);
    });

    test('copyWith preserves values', () {
      const original = VoiceRecordingState(
        phase: VoiceRecordingPhase.recording,
        duration: Duration(seconds: 30),
      );

      final copied = original.copyWith(
        phase: VoiceRecordingPhase.paused,
      );

      expect(copied.phase, VoiceRecordingPhase.paused);
      expect(copied.duration, const Duration(seconds: 30));
    });

    test('formattedDuration returns correct format', () {
      const state = VoiceRecordingState(
        duration: Duration(minutes: 2, seconds: 35),
      );

      expect(state.formattedDuration, '02:35');
    });

    test('wordCount returns 0 when no transcript', () {
      const state = VoiceRecordingState();

      expect(state.wordCount, 0);
    });

    test('wordCount returns correct count for transcript', () {
      const state = VoiceRecordingState(
        transcript: 'This is a test transcript with seven words.',
      );

      expect(state.wordCount, 8);
    });
  });
}
