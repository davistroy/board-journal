import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/transcription_service.dart';
import '../services/audio/audio_recorder_service.dart';
import '../services/audio/waveform_data.dart';

// ==================
// Transcription Configuration Provider
// ==================

/// Provider for transcription configuration.
///
/// Reads API keys from environment. Override for testing.
final transcriptionConfigProvider = Provider<TranscriptionConfig>((ref) {
  return TranscriptionConfig.fromEnvironment();
});

// ==================
// Audio Recorder Service Provider
// ==================

/// Provider for the audio recorder service.
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ==================
// Transcription Service Provider
// ==================

/// Provider for the transcription service.
final transcriptionServiceProvider = Provider<TranscriptionService?>((ref) {
  final config = ref.watch(transcriptionConfigProvider);

  if (!config.isConfigured) {
    return null;
  }

  final service = TranscriptionService(config: config);

  ref.onDispose(() {
    service.close();
  });

  return service;
});

// ==================
// Voice Recording State
// ==================

/// State for voice recording flow.
enum VoiceRecordingPhase {
  /// Ready to start recording.
  idle,

  /// Currently recording audio.
  recording,

  /// Recording paused.
  paused,

  /// Processing/stopping recording.
  stopping,

  /// Transcribing audio to text.
  transcribing,

  /// Showing transcript for editing.
  editTranscript,

  /// Checking for gaps in entry.
  gapCheck,

  /// Asking follow-up questions.
  followUp,

  /// Ready to save.
  confirmSave,

  /// Saved successfully.
  saved,

  /// Error occurred.
  error,
}

/// State class for voice recording.
class VoiceRecordingState {
  /// Current phase of the recording flow.
  final VoiceRecordingPhase phase;

  /// Current recording duration.
  final Duration duration;

  /// Whether at or past 12-minute warning threshold.
  final bool isNearLimit;

  /// Current waveform data for visualization.
  final WaveformData waveformData;

  /// Current amplitude (0.0 to 1.0).
  final double amplitude;

  /// Whether currently detecting silence.
  final bool isSilent;

  /// Seconds of continuous silence.
  final int silenceSeconds;

  /// Path to the recorded audio file (after recording stops).
  final String? audioFilePath;

  /// Transcribed text (after transcription completes).
  final String? transcriptRaw;

  /// Edited transcript text.
  final String? transcriptEdited;

  /// Which transcription provider was used.
  final TranscriptionProvider? transcriptionProvider;

  /// Time taken for transcription.
  final Duration? transcriptionTime;

  /// Error message if any.
  final String? error;

  /// Whether auto-stopped due to max duration.
  final bool autoStopped;

  /// Whether auto-stopped due to silence.
  final bool silenceStopped;

  const VoiceRecordingState({
    this.phase = VoiceRecordingPhase.idle,
    this.duration = Duration.zero,
    this.isNearLimit = false,
    WaveformData? waveformData,
    this.amplitude = 0.0,
    this.isSilent = false,
    this.silenceSeconds = 0,
    this.audioFilePath,
    this.transcriptRaw,
    this.transcriptEdited,
    this.transcriptionProvider,
    this.transcriptionTime,
    this.error,
    this.autoStopped = false,
    this.silenceStopped = false,
  }) : waveformData = waveformData ?? const _DefaultWaveformData();

  VoiceRecordingState copyWith({
    VoiceRecordingPhase? phase,
    Duration? duration,
    bool? isNearLimit,
    WaveformData? waveformData,
    double? amplitude,
    bool? isSilent,
    int? silenceSeconds,
    String? audioFilePath,
    String? transcriptRaw,
    String? transcriptEdited,
    TranscriptionProvider? transcriptionProvider,
    Duration? transcriptionTime,
    String? error,
    bool? autoStopped,
    bool? silenceStopped,
  }) {
    return VoiceRecordingState(
      phase: phase ?? this.phase,
      duration: duration ?? this.duration,
      isNearLimit: isNearLimit ?? this.isNearLimit,
      waveformData: waveformData ?? this.waveformData,
      amplitude: amplitude ?? this.amplitude,
      isSilent: isSilent ?? this.isSilent,
      silenceSeconds: silenceSeconds ?? this.silenceSeconds,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      transcriptRaw: transcriptRaw ?? this.transcriptRaw,
      transcriptEdited: transcriptEdited ?? this.transcriptEdited,
      transcriptionProvider:
          transcriptionProvider ?? this.transcriptionProvider,
      transcriptionTime: transcriptionTime ?? this.transcriptionTime,
      error: error,
      autoStopped: autoStopped ?? this.autoStopped,
      silenceStopped: silenceStopped ?? this.silenceStopped,
    );
  }

  /// Whether currently recording (including paused).
  bool get isRecording =>
      phase == VoiceRecordingPhase.recording ||
      phase == VoiceRecordingPhase.paused;

  /// Whether transcription is in progress.
  bool get isTranscribing => phase == VoiceRecordingPhase.transcribing;

  /// Whether we have a transcript to edit.
  bool get hasTranscript =>
      transcriptRaw != null && transcriptRaw!.isNotEmpty;

  /// The current transcript text (edited or raw).
  String get currentTranscript => transcriptEdited ?? transcriptRaw ?? '';

  /// Word count of current transcript.
  int get wordCount {
    final text = currentTranscript.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  /// Whether over word limit.
  bool get isOverLimit => wordCount > 7500;

  /// Whether approaching word limit.
  bool get isNearWordLimit => wordCount > 6500 && wordCount <= 7500;

  /// Formatted duration string (MM:SS).
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Default waveform data to avoid null issues.
class _DefaultWaveformData implements WaveformData {
  const _DefaultWaveformData();

  @override
  int get maxSamples => 50;

  @override
  List<double> get samples => const [];

  @override
  int get sampleCount => 0;

  @override
  bool get isEmpty => true;

  @override
  bool get isFull => false;

  @override
  double get averageAmplitude => 0.0;

  @override
  double get peakAmplitude => 0.0;

  @override
  double get currentAmplitude => 0.0;

  @override
  WaveformData addSample(double normalizedAmplitude) {
    return WaveformData(maxSamples: maxSamples).addSample(normalizedAmplitude);
  }

  @override
  WaveformData clear() => const _DefaultWaveformData();

  @override
  List<double> getSamplesForRendering(int count) => List.filled(count, 0.0);
}

// ==================
// Voice Recording Notifier
// ==================

/// Notifier for managing voice recording state.
class VoiceRecordingNotifier extends AutoDisposeNotifier<VoiceRecordingState> {
  StreamSubscription<AmplitudeEvent>? _amplitudeSubscription;
  StreamSubscription<RecordingStatusEvent>? _statusSubscription;

  @override
  VoiceRecordingState build() {
    // Set up subscriptions when notifier is created
    _setupSubscriptions();

    ref.onDispose(() {
      _amplitudeSubscription?.cancel();
      _statusSubscription?.cancel();
    });

    return const VoiceRecordingState();
  }

  void _setupSubscriptions() {
    final service = ref.read(audioRecorderServiceProvider);

    _amplitudeSubscription = service.amplitudeStream.listen((event) {
      if (state.phase == VoiceRecordingPhase.recording) {
        state = state.copyWith(
          amplitude: event.normalized,
          waveformData: state.waveformData.addSample(event.normalized),
          isSilent: event.isSilent,
          silenceSeconds: event.silenceSeconds,
          duration: event.duration,
        );
      }
    });

    _statusSubscription = service.statusStream.listen((event) {
      final newPhase = _mapRecordingState(event.state);

      if (event.autoStopped || event.silenceStopped) {
        // Recording was auto-stopped, transition to transcription
        state = state.copyWith(
          phase: VoiceRecordingPhase.stopping,
          autoStopped: event.autoStopped,
          silenceStopped: event.silenceStopped,
        );
        // Start transcription automatically
        _handleRecordingStopped();
      } else {
        state = state.copyWith(
          phase: newPhase,
          duration: event.duration,
          isNearLimit: event.isNearLimit,
        );
      }
    });
  }

  VoiceRecordingPhase _mapRecordingState(RecordingState state) {
    switch (state) {
      case RecordingState.idle:
        return VoiceRecordingPhase.idle;
      case RecordingState.recording:
        return VoiceRecordingPhase.recording;
      case RecordingState.paused:
        return VoiceRecordingPhase.paused;
      case RecordingState.stopping:
        return VoiceRecordingPhase.stopping;
    }
  }

  /// Starts a new recording.
  Future<void> startRecording() async {
    if (state.phase != VoiceRecordingPhase.idle) return;

    try {
      final service = ref.read(audioRecorderServiceProvider);
      await service.startRecording();

      state = state.copyWith(
        phase: VoiceRecordingPhase.recording,
        waveformData: WaveformData(),
        error: null,
      );
    } on AudioRecorderError catch (e) {
      state = state.copyWith(
        phase: VoiceRecordingPhase.error,
        error: e.message,
      );
    }
  }

  /// Stops the current recording and starts transcription.
  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    try {
      final service = ref.read(audioRecorderServiceProvider);
      final filePath = await service.stopRecording();

      if (filePath != null) {
        state = state.copyWith(
          phase: VoiceRecordingPhase.transcribing,
          audioFilePath: filePath,
        );

        await _transcribeAudio(filePath);
      } else {
        state = state.copyWith(
          phase: VoiceRecordingPhase.error,
          error: 'No audio file was created',
        );
      }
    } on AudioRecorderError catch (e) {
      state = state.copyWith(
        phase: VoiceRecordingPhase.error,
        error: e.message,
      );
    }
  }

  /// Handles recording being stopped (auto or manual).
  Future<void> _handleRecordingStopped() async {
    final service = ref.read(audioRecorderServiceProvider);

    try {
      final filePath = await service.stopRecording(
        autoStopped: state.autoStopped,
        silenceStopped: state.silenceStopped,
      );

      if (filePath != null) {
        state = state.copyWith(
          phase: VoiceRecordingPhase.transcribing,
          audioFilePath: filePath,
        );

        await _transcribeAudio(filePath);
      }
    } catch (e) {
      state = state.copyWith(
        phase: VoiceRecordingPhase.error,
        error: 'Failed to stop recording: $e',
      );
    }
  }

  /// Transcribes the audio file.
  Future<void> _transcribeAudio(String filePath) async {
    final transcriptionService = ref.read(transcriptionServiceProvider);

    if (transcriptionService == null) {
      // No transcription service configured - use placeholder
      state = state.copyWith(
        phase: VoiceRecordingPhase.editTranscript,
        transcriptRaw: '[Transcription not available - service not configured]',
        transcriptEdited:
            '[Transcription not available - service not configured]',
      );
      return;
    }

    try {
      final result = await transcriptionService.transcribe(File(filePath));

      state = state.copyWith(
        phase: VoiceRecordingPhase.editTranscript,
        transcriptRaw: result.text,
        transcriptEdited: result.text,
        transcriptionProvider: result.provider,
        transcriptionTime: result.transcriptionTime,
      );

      // Delete audio file after successful transcription
      final recorderService = ref.read(audioRecorderServiceProvider);
      await recorderService.deleteAudioFile(filePath);
    } on TranscriptionError catch (e) {
      // Keep the audio file for retry
      state = state.copyWith(
        phase: VoiceRecordingPhase.error,
        error: 'Transcription failed: ${e.message}. Audio saved for retry.',
      );
    } catch (e) {
      state = state.copyWith(
        phase: VoiceRecordingPhase.error,
        error: 'Transcription failed: $e. Audio saved for retry.',
      );
    }
  }

  /// Pauses the current recording.
  Future<void> pauseRecording() async {
    if (state.phase != VoiceRecordingPhase.recording) return;

    try {
      final service = ref.read(audioRecorderServiceProvider);
      await service.pauseRecording();
    } on AudioRecorderError catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Resumes a paused recording.
  Future<void> resumeRecording() async {
    if (state.phase != VoiceRecordingPhase.paused) return;

    try {
      final service = ref.read(audioRecorderServiceProvider);
      await service.resumeRecording();
    } on AudioRecorderError catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Cancels the current recording.
  Future<void> cancelRecording() async {
    final service = ref.read(audioRecorderServiceProvider);
    await service.cancelRecording();

    state = const VoiceRecordingState();
  }

  /// Updates the edited transcript text.
  void updateTranscript(String text) {
    state = state.copyWith(transcriptEdited: text);
  }

  /// Retries transcription for a failed attempt.
  Future<void> retryTranscription() async {
    if (state.audioFilePath == null) {
      state = state.copyWith(
        error: 'No audio file available for retry',
      );
      return;
    }

    state = state.copyWith(
      phase: VoiceRecordingPhase.transcribing,
      error: null,
    );

    await _transcribeAudio(state.audioFilePath!);
  }

  /// Proceeds from edit transcript to confirm save.
  void proceedToConfirmSave() {
    if (state.phase != VoiceRecordingPhase.editTranscript) return;

    state = state.copyWith(phase: VoiceRecordingPhase.confirmSave);
  }

  /// Returns to editing the transcript.
  void returnToEdit() {
    if (state.phase == VoiceRecordingPhase.confirmSave) {
      state = state.copyWith(phase: VoiceRecordingPhase.editTranscript);
    }
  }

  /// Resets the state for a new recording.
  void reset() {
    state = const VoiceRecordingState();
  }

  /// Dismisses a silence detection (continues recording).
  void dismissSilenceWarning() {
    // This is handled by the UI tapping on the countdown
    // The silence timer will naturally reset when audio is detected
  }
}

/// Provider for voice recording state.
final voiceRecordingProvider =
    NotifierProvider.autoDispose<VoiceRecordingNotifier, VoiceRecordingState>(
  VoiceRecordingNotifier.new,
);

// ==================
// Derived Providers
// ==================

/// Provider for whether transcription is configured.
final isTranscriptionConfiguredProvider = Provider<bool>((ref) {
  final config = ref.watch(transcriptionConfigProvider);
  return config.isConfigured;
});

/// Provider for recording duration formatted string.
final recordingDurationProvider = Provider<String>((ref) {
  final state = ref.watch(voiceRecordingProvider);
  return state.formattedDuration;
});

/// Provider for whether currently recording.
final isRecordingProvider = Provider<bool>((ref) {
  final state = ref.watch(voiceRecordingProvider);
  return state.isRecording;
});
