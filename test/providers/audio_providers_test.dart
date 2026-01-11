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
              const TranscriptionConfig(deepgramApiKey: null),
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
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.gapCheck));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.followUp));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.confirmSave));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.saved));
      expect(VoiceRecordingPhase.values, contains(VoiceRecordingPhase.error));
    });
  });

  group('VoiceRecordingState', () {
    test('initial state has correct defaults', () {
      const state = VoiceRecordingState();

      expect(state.phase, VoiceRecordingPhase.idle);
      expect(state.duration, Duration.zero);
      expect(state.audioFilePath, isNull);
      expect(state.transcriptRaw, isNull);
      expect(state.transcriptEdited, isNull);
      expect(state.error, isNull);
      expect(state.waveformData.isEmpty, isTrue);
      expect(state.silenceSeconds, 0);
    });

    test('isRecording returns true during recording', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.recording);

      expect(state.isRecording, isTrue);
    });

    test('isRecording returns true when paused', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.paused);

      expect(state.isRecording, isTrue);
    });

    test('isRecording returns false when idle', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.idle);

      expect(state.isRecording, isFalse);
    });

    test('isTranscribing returns true during transcribing', () {
      const state = VoiceRecordingState(phase: VoiceRecordingPhase.transcribing);

      expect(state.isTranscribing, isTrue);
    });

    test('hasTranscript returns false when no transcript', () {
      const state = VoiceRecordingState();

      expect(state.hasTranscript, isFalse);
    });

    test('hasTranscript returns true when transcript is set', () {
      const state = VoiceRecordingState(
        transcriptRaw: 'This is a test transcript.',
      );

      expect(state.hasTranscript, isTrue);
    });

    test('currentTranscript returns edited transcript when available', () {
      const state = VoiceRecordingState(
        transcriptRaw: 'Original text',
        transcriptEdited: 'Edited text',
      );

      expect(state.currentTranscript, 'Edited text');
    });

    test('currentTranscript returns raw transcript when no edit', () {
      const state = VoiceRecordingState(
        transcriptRaw: 'Original text',
      );

      expect(state.currentTranscript, 'Original text');
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
        transcriptRaw: 'This is a test transcript with seven words.',
      );

      expect(state.wordCount, 8);
    });

    test('isOverLimit returns true when over 7500 words', () {
      // Create a string with more than 7500 words
      final longText = List.generate(7501, (i) => 'word').join(' ');
      final state = VoiceRecordingState(transcriptRaw: longText);

      expect(state.isOverLimit, isTrue);
    });

    test('isNearWordLimit returns true when between 6500 and 7500 words', () {
      final nearLimitText = List.generate(7000, (i) => 'word').join(' ');
      final state = VoiceRecordingState(transcriptRaw: nearLimitText);

      expect(state.isNearWordLimit, isTrue);
    });
  });
}
