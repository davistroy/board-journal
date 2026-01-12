import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/audio_providers.dart';
import '../../../widgets/silence_countdown_widget.dart';
import '../../../widgets/waveform_widget.dart';
import 'text_entry_state.dart';

/// Voice recording view with waveform, timer, and controls.
class VoiceRecordingView extends ConsumerStatefulWidget {
  const VoiceRecordingView({
    super.key,
    required this.transcriptController,
    required this.onSave,
  });

  final TextEditingController transcriptController;
  final VoidCallback onSave;

  @override
  ConsumerState<VoiceRecordingView> createState() => _VoiceRecordingViewState();
}

class _VoiceRecordingViewState extends ConsumerState<VoiceRecordingView> {
  @override
  void initState() {
    super.initState();
    // Listen for transcript changes to sync with controller
    widget.transcriptController.addListener(_onTranscriptChanged);
  }

  @override
  void dispose() {
    widget.transcriptController.removeListener(_onTranscriptChanged);
    super.dispose();
  }

  void _onTranscriptChanged() {
    final state = ref.read(voiceRecordingProvider);
    if (state.phase == VoiceRecordingPhase.editTranscript) {
      ref
          .read(voiceRecordingProvider.notifier)
          .updateTranscript(widget.transcriptController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceRecordingProvider);

    // Sync controller with state when transcript changes from transcription
    if (state.hasTranscript &&
        widget.transcriptController.text != state.currentTranscript &&
        state.phase == VoiceRecordingPhase.editTranscript) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.transcriptController.text = state.currentTranscript;
          widget.transcriptController.selection = TextSelection.fromPosition(
            TextPosition(offset: state.currentTranscript.length),
          );
        }
      });
    }

    return Stack(
      children: [
        // Main content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildPhaseContent(state),
        ),

        // Silence countdown overlay
        if (state.phase == VoiceRecordingPhase.recording &&
            state.silenceSeconds >= 5)
          Positioned.fill(
            child: SilenceCountdownOverlay(
              silenceSeconds: state.silenceSeconds,
              onDismiss: () {
                ref.read(voiceRecordingProvider.notifier).dismissSilenceWarning();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseContent(VoiceRecordingState state) {
    switch (state.phase) {
      case VoiceRecordingPhase.idle:
        return IdleView(
          key: const ValueKey('idle'),
          onStartRecording: () {
            ref.read(voiceRecordingProvider.notifier).startRecording();
          },
        );

      case VoiceRecordingPhase.recording:
      case VoiceRecordingPhase.paused:
        return RecordingView(
          key: const ValueKey('recording'),
          state: state,
          onStop: () {
            ref.read(voiceRecordingProvider.notifier).stopRecording();
          },
          onPause: () {
            ref.read(voiceRecordingProvider.notifier).pauseRecording();
          },
          onResume: () {
            ref.read(voiceRecordingProvider.notifier).resumeRecording();
          },
          onCancel: () {
            ref.read(voiceRecordingProvider.notifier).cancelRecording();
          },
        );

      case VoiceRecordingPhase.stopping:
      case VoiceRecordingPhase.transcribing:
        return TranscribingView(
          key: const ValueKey('transcribing'),
          state: state,
        );

      case VoiceRecordingPhase.editTranscript:
      case VoiceRecordingPhase.gapCheck:
      case VoiceRecordingPhase.followUp:
      case VoiceRecordingPhase.confirmSave:
        return EditTranscriptView(
          key: const ValueKey('edit'),
          state: state,
          controller: widget.transcriptController,
          onSave: widget.onSave,
        );

      case VoiceRecordingPhase.saved:
        return const SavedView(key: ValueKey('saved'));

      case VoiceRecordingPhase.error:
        return ErrorView(
          key: const ValueKey('error'),
          state: state,
          onRetry: () {
            ref.read(voiceRecordingProvider.notifier).retryTranscription();
          },
          onReset: () {
            ref.read(voiceRecordingProvider.notifier).reset();
          },
        );
    }
  }
}

/// Idle view - ready to start recording.
class IdleView extends StatelessWidget {
  const IdleView({
    super.key,
    required this.onStartRecording,
  });

  final VoidCallback onStartRecording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large record button
          GestureDetector(
            onTap: onStartRecording,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.error.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.mic,
                size: 56,
                color: theme.colorScheme.onError,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Tap to start recording',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Max 15 minutes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recording view with waveform and controls.
class RecordingView extends StatelessWidget {
  const RecordingView({
    super.key,
    required this.state,
    required this.onStop,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final VoiceRecordingState state;
  final VoidCallback onStop;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaused = state.phase == VoiceRecordingPhase.paused;

    return Column(
      children: [
        const Spacer(),

        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: state.isNearLimit
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isPaused
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                state.formattedDuration,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: state.isNearLimit
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        if (state.isNearLimit) ...[
          const SizedBox(height: 8),
          Text(
            'Recording will stop at 15 minutes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Waveform visualization
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: RecordingWaveformWidget(
            waveformData: state.waveformData,
            isRecording: !isPaused,
            height: 100,
          ),
        ),

        // Silence indicator
        const SizedBox(height: 16),
        SilenceIndicator(
          isSilent: state.isSilent,
          silenceSeconds: state.silenceSeconds,
        ),

        const Spacer(),

        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cancel button
            IconButton.outlined(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
              ),
            ),
            const SizedBox(width: 24),

            // Stop button
            GestureDetector(
              onTap: onStop,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stop,
                  size: 40,
                  color: theme.colorScheme.onError,
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Pause/Resume button
            IconButton.filled(
              onPressed: isPaused ? onResume : onPause,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              style: IconButton.styleFrom(
                minimumSize: const Size(56, 56),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),
      ],
    );
  }
}

/// Transcribing view - processing audio.
class TranscribingView extends StatelessWidget {
  const TranscribingView({
    super.key,
    required this.state,
  });

  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            state.phase == VoiceRecordingPhase.stopping
                ? 'Stopping recording...'
                : 'Transcribing audio...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This usually takes a few seconds',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit transcript view.
class EditTranscriptView extends ConsumerWidget {
  const EditTranscriptView({
    super.key,
    required this.state,
    required this.controller,
    required this.onSave,
  });

  final VoiceRecordingState state;
  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textState = ref.watch(textEntryProvider);

    return Column(
      children: [
        // Word count bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: state.isOverLimit
                ? theme.colorScheme.errorContainer
                : state.isNearWordLimit
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              // Transcription provider badge
              if (state.transcriptionProvider != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.transcriptionProvider!.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                '${state.wordCount} words',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: state.isOverLimit
                      ? theme.colorScheme.error
                      : state.isNearWordLimit
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (state.transcriptionTime != null) ...[
                const Spacer(),
                Text(
                  'Transcribed in ${state.transcriptionTime!.inMilliseconds}ms',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Transcript editor
        Expanded(
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Your transcript will appear here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),

        // Bottom action bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Review and edit your transcript before saving.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: state.currentTranscript.isNotEmpty &&
                          !textState.isSaving
                      ? onSave
                      : null,
                  child: textState.isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(textState.saveStatusText),
                          ],
                        )
                      : const Text('Save Entry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Saved view - confirmation.
class SavedView extends StatelessWidget {
  const SavedView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Entry Saved!',
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}

/// Error view with retry option.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onReset,
  });

  final VoiceRecordingState state;
  final VoidCallback onRetry;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              state.error ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            if (state.audioFilePath != null) ...[
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Transcription'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Start Over'),
            ),
          ],
        ),
      ),
    );
  }
}
