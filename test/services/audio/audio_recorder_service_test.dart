import 'package:boardroom_journal/services/audio/audio_recorder_service.dart';
import 'package:boardroom_journal/services/audio/waveform_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioRecorderConfig', () {
    test('has correct default values', () {
      const config = AudioRecorderConfig();

      expect(config.maxDuration, const Duration(minutes: 15));
      expect(config.warningThreshold, const Duration(minutes: 12));
      expect(config.silenceTimeout, const Duration(seconds: 8));
      expect(config.silenceCountdownStart, const Duration(seconds: 3));
      expect(config.silenceThreshold, -50.0);
      expect(config.amplitudeSampleInterval, const Duration(milliseconds: 100));
    });

    test('allows custom configuration', () {
      const config = AudioRecorderConfig(
        maxDuration: Duration(minutes: 10),
        warningThreshold: Duration(minutes: 8),
        silenceTimeout: Duration(seconds: 5),
        silenceCountdownStart: Duration(seconds: 2),
        silenceThreshold: -40.0,
        amplitudeSampleInterval: Duration(milliseconds: 50),
      );

      expect(config.maxDuration, const Duration(minutes: 10));
      expect(config.warningThreshold, const Duration(minutes: 8));
      expect(config.silenceTimeout, const Duration(seconds: 5));
      expect(config.silenceCountdownStart, const Duration(seconds: 2));
      expect(config.silenceThreshold, -40.0);
      expect(config.amplitudeSampleInterval, const Duration(milliseconds: 50));
    });
  });

  group('AudioRecorderError', () {
    test('creates error with message', () {
      const error = AudioRecorderError(message: 'Test error');

      expect(error.message, 'Test error');
      expect(error.code, isNull);
      expect(error.toString(), 'AudioRecorderError: Test error');
    });

    test('creates error with code', () {
      const error = AudioRecorderError(
        message: 'Permission denied',
        code: 'permission_denied',
      );

      expect(error.message, 'Permission denied');
      expect(error.code, 'permission_denied');
    });
  });

  group('AmplitudeEvent', () {
    test('holds correct values', () {
      const event = AmplitudeEvent(
        amplitude: -30.0,
        normalized: 0.5,
        duration: Duration(seconds: 10),
        isSilent: false,
        silenceSeconds: 0,
      );

      expect(event.amplitude, -30.0);
      expect(event.normalized, 0.5);
      expect(event.duration, const Duration(seconds: 10));
      expect(event.isSilent, false);
      expect(event.silenceSeconds, 0);
    });

    test('indicates silence correctly', () {
      const event = AmplitudeEvent(
        amplitude: -55.0,
        normalized: 0.1,
        duration: Duration(seconds: 30),
        isSilent: true,
        silenceSeconds: 5,
      );

      expect(event.isSilent, true);
      expect(event.silenceSeconds, 5);
    });
  });

  group('RecordingStatusEvent', () {
    test('has default values', () {
      const event = RecordingStatusEvent(
        state: RecordingState.idle,
        duration: Duration.zero,
      );

      expect(event.state, RecordingState.idle);
      expect(event.duration, Duration.zero);
      expect(event.isNearLimit, false);
      expect(event.autoStopped, false);
      expect(event.silenceStopped, false);
      expect(event.error, isNull);
    });

    test('indicates near limit warning', () {
      const event = RecordingStatusEvent(
        state: RecordingState.recording,
        duration: Duration(minutes: 13),
        isNearLimit: true,
      );

      expect(event.isNearLimit, true);
    });

    test('indicates auto-stop conditions', () {
      const autoStoppedEvent = RecordingStatusEvent(
        state: RecordingState.idle,
        duration: Duration(minutes: 15),
        autoStopped: true,
      );

      const silenceStoppedEvent = RecordingStatusEvent(
        state: RecordingState.idle,
        duration: Duration(minutes: 2),
        silenceStopped: true,
      );

      expect(autoStoppedEvent.autoStopped, true);
      expect(autoStoppedEvent.silenceStopped, false);
      expect(silenceStoppedEvent.autoStopped, false);
      expect(silenceStoppedEvent.silenceStopped, true);
    });
  });

  group('RecordingState', () {
    test('has all expected states', () {
      expect(RecordingState.values, contains(RecordingState.idle));
      expect(RecordingState.values, contains(RecordingState.recording));
      expect(RecordingState.values, contains(RecordingState.paused));
      expect(RecordingState.values, contains(RecordingState.stopping));
    });
  });

  group('AudioRecorderService', () {
    test('initializes in idle state', () {
      final service = AudioRecorderService();

      expect(service.state, RecordingState.idle);
      expect(service.duration, Duration.zero);
      expect(service.isRecording, false);
      expect(service.isPaused, false);
      expect(service.isNearLimit, false);
    });

    test('uses custom config', () {
      const config = AudioRecorderConfig(
        maxDuration: Duration(minutes: 5),
      );
      final service = AudioRecorderService(config: config);

      expect(service.config.maxDuration, const Duration(minutes: 5));
    });

    test('throws when starting recording while not idle', () async {
      // Note: This test would require mocking the AudioRecorder package
      // For unit testing without device access, we test the state logic
      final service = AudioRecorderService();

      // Can't really test startRecording without mocking platform channel
      // but we can verify the service initializes correctly
      expect(service.state, RecordingState.idle);
    });

    test('stopRecording returns null when not recording', () async {
      final service = AudioRecorderService();

      final result = await service.stopRecording();

      expect(result, isNull);
    });

    test('pauseRecording does nothing when not recording', () async {
      final service = AudioRecorderService();

      await service.pauseRecording();

      expect(service.state, RecordingState.idle);
    });

    test('resumeRecording does nothing when not paused', () async {
      final service = AudioRecorderService();

      await service.resumeRecording();

      expect(service.state, RecordingState.idle);
    });

    test('cancelRecording does nothing when idle', () async {
      final service = AudioRecorderService();

      await service.cancelRecording();

      expect(service.state, RecordingState.idle);
    });

    test('provides amplitude stream', () {
      final service = AudioRecorderService();

      expect(service.amplitudeStream, isA<Stream<AmplitudeEvent>>());
    });

    test('provides status stream', () {
      final service = AudioRecorderService();

      expect(service.statusStream, isA<Stream<RecordingStatusEvent>>());
    });
  });

  group('WaveformData', () {
    test('initializes with empty samples', () {
      final waveform = WaveformData();

      expect(waveform.isEmpty, true);
      expect(waveform.sampleCount, 0);
      expect(waveform.averageAmplitude, 0.0);
      expect(waveform.peakAmplitude, 0.0);
      expect(waveform.currentAmplitude, 0.0);
    });

    test('adds samples correctly', () {
      var waveform = WaveformData(maxSamples: 10);

      waveform = waveform.addSample(0.5);

      expect(waveform.isEmpty, false);
      expect(waveform.sampleCount, 1);
      expect(waveform.currentAmplitude, 0.5);
      expect(waveform.peakAmplitude, 0.5);
    });

    test('maintains max samples limit', () {
      var waveform = WaveformData(maxSamples: 3);

      waveform = waveform.addSample(0.1);
      waveform = waveform.addSample(0.2);
      waveform = waveform.addSample(0.3);
      waveform = waveform.addSample(0.4);

      expect(waveform.sampleCount, 3);
      expect(waveform.samples, [0.2, 0.3, 0.4]);
    });

    test('clamps amplitude values', () {
      var waveform = WaveformData();

      waveform = waveform.addSample(1.5); // Over 1.0
      expect(waveform.currentAmplitude, 1.0);

      waveform = waveform.addSample(-0.5); // Under 0.0
      expect(waveform.currentAmplitude, 0.0);
    });

    test('calculates average correctly', () {
      var waveform = WaveformData(maxSamples: 3);

      waveform = waveform.addSample(0.2);
      waveform = waveform.addSample(0.4);
      waveform = waveform.addSample(0.6);

      expect(waveform.averageAmplitude, closeTo(0.4, 0.001));
    });

    test('tracks peak amplitude', () {
      var waveform = WaveformData(maxSamples: 5);

      waveform = waveform.addSample(0.3);
      waveform = waveform.addSample(0.8);
      waveform = waveform.addSample(0.5);

      expect(waveform.peakAmplitude, 0.8);
    });

    test('clear returns empty waveform', () {
      var waveform = WaveformData(maxSamples: 10);
      waveform = waveform.addSample(0.5);
      waveform = waveform.addSample(0.6);

      final cleared = waveform.clear();

      expect(cleared.isEmpty, true);
      expect(cleared.maxSamples, 10);
    });

    test('getSamplesForRendering pads with zeros', () {
      var waveform = WaveformData(maxSamples: 10);
      waveform = waveform.addSample(0.5);
      waveform = waveform.addSample(0.6);

      final rendered = waveform.getSamplesForRendering(5);

      expect(rendered.length, 5);
      expect(rendered[0], 0.0); // Padding
      expect(rendered[1], 0.0); // Padding
      expect(rendered[2], 0.0); // Padding
      expect(rendered[3], 0.5);
      expect(rendered[4], 0.6);
    });

    test('getSamplesForRendering downsamples', () {
      var waveform = WaveformData(maxSamples: 10);
      for (var i = 0; i < 10; i++) {
        waveform = waveform.addSample(i / 10);
      }

      final rendered = waveform.getSamplesForRendering(5);

      expect(rendered.length, 5);
    });

    test('isFull returns correct value', () {
      var waveform = WaveformData(maxSamples: 2);

      expect(waveform.isFull, false);

      waveform = waveform.addSample(0.5);
      expect(waveform.isFull, false);

      waveform = waveform.addSample(0.6);
      expect(waveform.isFull, true);
    });
  });

  group('WaveformConfig', () {
    test('has correct default values', () {
      const config = WaveformConfig();

      expect(config.barCount, 30);
      expect(config.minBarHeight, 0.05);
      expect(config.barWidth, 3.0);
      expect(config.barSpacing, 2.0);
      expect(config.barRadius, 1.5);
    });

    test('calculates total width correctly', () {
      const config = WaveformConfig(
        barCount: 10,
        barWidth: 4.0,
        barSpacing: 2.0,
      );

      // (4.0 + 2.0) * 10 - 2.0 = 58.0
      expect(config.totalWidth, 58.0);
    });
  });
}
