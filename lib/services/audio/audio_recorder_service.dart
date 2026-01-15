import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

// Conditional imports for platform-specific code
import 'audio_recorder_io.dart' if (dart.library.html) 'audio_recorder_web.dart'
    as platform;

/// Recording state for the audio recorder.
enum RecordingState {
  /// Not recording.
  idle,

  /// Recording in progress.
  recording,

  /// Recording is paused.
  paused,

  /// Processing/stopping recording.
  stopping,
}

/// Configuration for the audio recorder.
class AudioRecorderConfig {
  /// Maximum recording duration.
  final Duration maxDuration;

  /// Warning threshold before max duration.
  final Duration warningThreshold;

  /// Duration of silence before auto-stop.
  final Duration silenceTimeout;

  /// Countdown starts showing at this time before silence timeout.
  final Duration silenceCountdownStart;

  /// Amplitude threshold below which is considered silence.
  /// Range: -160.0 (silent) to 0.0 (max).
  final double silenceThreshold;

  /// How often to sample amplitude for waveform.
  final Duration amplitudeSampleInterval;

  const AudioRecorderConfig({
    this.maxDuration = const Duration(minutes: 15),
    this.warningThreshold = const Duration(minutes: 12),
    this.silenceTimeout = const Duration(seconds: 8),
    this.silenceCountdownStart = const Duration(seconds: 3),
    this.silenceThreshold = -50.0,
    this.amplitudeSampleInterval = const Duration(milliseconds: 100),
  });
}

/// Error from the audio recorder.
class AudioRecorderError implements Exception {
  final String message;
  final String? code;

  const AudioRecorderError({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AudioRecorderError: $message';
}

/// Event data for amplitude updates.
class AmplitudeEvent {
  /// Current amplitude in dB (-160 to 0).
  final double amplitude;

  /// Normalized amplitude (0.0 to 1.0).
  final double normalized;

  /// Current recording duration.
  final Duration duration;

  /// Whether currently in silence.
  final bool isSilent;

  /// Seconds of continuous silence.
  final int silenceSeconds;

  const AmplitudeEvent({
    required this.amplitude,
    required this.normalized,
    required this.duration,
    required this.isSilent,
    required this.silenceSeconds,
  });
}

/// Event data for recording status changes.
class RecordingStatusEvent {
  /// Current recording state.
  final RecordingState state;

  /// Current recording duration.
  final Duration duration;

  /// Whether at or past warning threshold.
  final bool isNearLimit;

  /// Whether auto-stopped due to max duration.
  final bool autoStopped;

  /// Whether auto-stopped due to silence.
  final bool silenceStopped;

  /// Error message if any.
  final String? error;

  const RecordingStatusEvent({
    required this.state,
    required this.duration,
    this.isNearLimit = false,
    this.autoStopped = false,
    this.silenceStopped = false,
    this.error,
  });
}

/// Service for audio recording with silence detection and waveform data.
///
/// Per PRD Section 4.1:
/// - Max 15 minutes per recording
/// - Warning at 12 minutes
/// - Auto-stop at 15 minutes
/// - 8-second silence timeout with visual countdown in last 3 seconds
class AudioRecorderService {
  final AudioRecorderConfig config;
  final AudioRecorder _recorder;

  /// Stream controller for amplitude events.
  final _amplitudeController = StreamController<AmplitudeEvent>.broadcast();

  /// Stream controller for status events.
  final _statusController = StreamController<RecordingStatusEvent>.broadcast();

  /// Current recording state.
  RecordingState _state = RecordingState.idle;

  /// Timer for duration tracking.
  Timer? _durationTimer;

  /// Timer for amplitude sampling.
  Timer? _amplitudeTimer;

  /// Current recording duration.
  Duration _duration = Duration.zero;

  /// Current consecutive silence duration.
  Duration _silenceDuration = Duration.zero;

  /// Path to current recording file.
  String? _currentFilePath;

  /// Whether the service has been disposed.
  bool _isDisposed = false;

  AudioRecorderService({
    AudioRecorderConfig? config,
    AudioRecorder? recorder,
  })  : config = config ?? const AudioRecorderConfig(),
        _recorder = recorder ?? AudioRecorder();

  /// Stream of amplitude events for waveform visualization.
  Stream<AmplitudeEvent> get amplitudeStream => _amplitudeController.stream;

  /// Stream of recording status events.
  Stream<RecordingStatusEvent> get statusStream => _statusController.stream;

  /// Current recording state.
  RecordingState get state => _state;

  /// Current recording duration.
  Duration get duration => _duration;

  /// Whether currently recording.
  bool get isRecording => _state == RecordingState.recording;

  /// Whether recording is paused.
  bool get isPaused => _state == RecordingState.paused;

  /// Whether at or past warning threshold.
  bool get isNearLimit => _duration >= config.warningThreshold;

  /// Returns the appropriate RecordConfig for the current platform.
  RecordConfig _getRecordConfig() {
    if (kIsWeb) {
      // Web: use WAV for universal browser support
      // (Opus has Safari issues, AAC not supported on Chrome/Firefox)
      return const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1, // Mono for smaller files
      );
    }
    // Mobile: use AAC-LC for compressed audio
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );
  }

  /// Starts a new recording.
  ///
  /// Throws [AudioRecorderError] if microphone permission is denied
  /// or if already recording.
  Future<void> startRecording() async {
    if (_isDisposed) {
      throw const AudioRecorderError(message: 'Service has been disposed');
    }

    if (_state != RecordingState.idle) {
      throw const AudioRecorderError(
        message: 'Already recording or not in idle state',
        code: 'already_recording',
      );
    }

    // Check permission (mobile only - web handles via browser prompt)
    if (!kIsWeb) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const AudioRecorderError(
          message: 'Microphone permission denied',
          code: 'permission_denied',
        );
      }
    }

    // Generate file path (platform-specific)
    _currentFilePath = await platform.getRecordingPath();

    // Configure recording (platform-specific)
    final recordConfig = _getRecordConfig();

    try {
      await _recorder.start(recordConfig, path: _currentFilePath!);
      _state = RecordingState.recording;
      _duration = Duration.zero;
      _silenceDuration = Duration.zero;

      _startTimers();
      _emitStatus();
    } catch (e) {
      _currentFilePath = null;
      throw AudioRecorderError(message: 'Failed to start recording: $e');
    }
  }

  /// Stops the current recording and returns the audio file path.
  ///
  /// Returns null if not recording.
  Future<String?> stopRecording({
    bool autoStopped = false,
    bool silenceStopped = false,
  }) async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      return null;
    }

    _state = RecordingState.stopping;
    _emitStatus();

    _stopTimers();

    try {
      final path = await _recorder.stop();
      _state = RecordingState.idle;

      _statusController.add(RecordingStatusEvent(
        state: _state,
        duration: _duration,
        autoStopped: autoStopped,
        silenceStopped: silenceStopped,
      ));

      final filePath = path ?? _currentFilePath;
      _currentFilePath = null;
      _duration = Duration.zero;
      _silenceDuration = Duration.zero;

      return filePath;
    } catch (e) {
      _state = RecordingState.idle;
      _currentFilePath = null;
      throw AudioRecorderError(message: 'Failed to stop recording: $e');
    }
  }

  /// Pauses the current recording.
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) {
      return;
    }

    try {
      await _recorder.pause();
      _state = RecordingState.paused;
      _stopTimers();
      _emitStatus();
    } catch (e) {
      throw AudioRecorderError(message: 'Failed to pause recording: $e');
    }
  }

  /// Resumes a paused recording.
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) {
      return;
    }

    try {
      await _recorder.resume();
      _state = RecordingState.recording;
      _silenceDuration = Duration.zero; // Reset silence on resume
      _startTimers();
      _emitStatus();
    } catch (e) {
      throw AudioRecorderError(message: 'Failed to resume recording: $e');
    }
  }

  /// Cancels the current recording and deletes the file.
  Future<void> cancelRecording() async {
    if (_state == RecordingState.idle) {
      return;
    }

    _stopTimers();

    try {
      await _recorder.stop();
    } catch (_) {
      // Ignore errors when canceling
    }

    // Delete the file (platform-specific)
    if (_currentFilePath != null) {
      await platform.deleteAudioFile(_currentFilePath!);
    }

    _state = RecordingState.idle;
    _currentFilePath = null;
    _duration = Duration.zero;
    _silenceDuration = Duration.zero;
    _emitStatus();
  }

  /// Deletes an audio file after successful transcription.
  Future<void> deleteAudioFile(String filePath) async {
    await platform.deleteAudioFile(filePath);
  }

  /// Disposes of the service and releases resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _stopTimers();

    if (_state != RecordingState.idle) {
      await cancelRecording();
    }

    await _amplitudeController.close();
    await _statusController.close();
    _recorder.dispose();
  }

  void _startTimers() {
    // Duration timer - tick every second
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);

      // Check max duration
      if (_duration >= config.maxDuration) {
        stopRecording(autoStopped: true);
        return;
      }

      _emitStatus();
    });

    // Amplitude timer - sample frequently for waveform
    _amplitudeTimer = Timer.periodic(config.amplitudeSampleInterval, (_) async {
      if (_state != RecordingState.recording) return;

      try {
        final amplitude = await _recorder.getAmplitude();
        final current = amplitude.current;

        // Check for silence
        final isSilent = current < config.silenceThreshold;
        if (isSilent) {
          _silenceDuration += config.amplitudeSampleInterval;

          // Check silence timeout
          if (_silenceDuration >= config.silenceTimeout) {
            stopRecording(silenceStopped: true);
            return;
          }
        } else {
          _silenceDuration = Duration.zero;
        }

        // Normalize amplitude from dB (-160 to 0) to 0.0-1.0
        final normalized = _normalizeAmplitude(current);

        _amplitudeController.add(AmplitudeEvent(
          amplitude: current,
          normalized: normalized,
          duration: _duration,
          isSilent: isSilent,
          silenceSeconds: _silenceDuration.inSeconds,
        ));
      } catch (_) {
        // Ignore amplitude read errors
      }
    });
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  void _emitStatus() {
    _statusController.add(RecordingStatusEvent(
      state: _state,
      duration: _duration,
      isNearLimit: isNearLimit,
    ));
  }

  /// Normalizes dB amplitude to 0.0-1.0 range.
  double _normalizeAmplitude(double db) {
    // Clamp to expected range
    const minDb = -60.0; // Practical minimum
    const maxDb = 0.0;

    final clamped = db.clamp(minDb, maxDb);
    return (clamped - minDb) / (maxDb - minDb);
  }
}
