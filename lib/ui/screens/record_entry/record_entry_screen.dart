import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/enums/entry_type.dart';
import '../../../providers/audio_providers.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../../services/ai/ai.dart';
import '../../widgets/silence_countdown_widget.dart';
import '../../widgets/waveform_widget.dart';

/// Entry mode for the record screen.
enum RecordEntryMode {
  /// Initial selection screen.
  selection,

  /// Voice recording mode.
  voice,

  /// Text typing mode.
  text,
}

/// Save phase for the entry save flow.
enum SavePhase {
  /// Not saving.
  idle,

  /// Saving entry to database.
  saving,

  /// Extracting signals from entry.
  extracting,
}

/// State for the text entry.
class TextEntryState {
  final String text;
  final SavePhase savePhase;
  final String? error;

  const TextEntryState({
    this.text = '',
    this.savePhase = SavePhase.idle,
    this.error,
  });

  int get wordCount {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  bool get isOverLimit => wordCount > 7500;
  bool get isNearLimit => wordCount > 6500 && wordCount <= 7500;
  bool get isSaving => savePhase != SavePhase.idle;
  bool get canSave => text.trim().isNotEmpty && !isSaving;

  String get saveStatusText {
    switch (savePhase) {
      case SavePhase.idle:
        return 'Save Entry';
      case SavePhase.saving:
        return 'Saving...';
      case SavePhase.extracting:
        return 'Extracting signals...';
    }
  }

  TextEntryState copyWith({
    String? text,
    SavePhase? savePhase,
    String? error,
  }) {
    return TextEntryState(
      text: text ?? this.text,
      savePhase: savePhase ?? this.savePhase,
      error: error,
    );
  }
}

/// Notifier for text entry state.
class TextEntryNotifier extends Notifier<TextEntryState> {
  @override
  TextEntryState build() => const TextEntryState();

  void updateText(String text) {
    state = state.copyWith(text: text, error: null);
  }

  /// Saves the entry and extracts signals.
  ///
  /// Returns the entry ID if successful, null otherwise.
  /// Signal extraction happens after save and doesn't block navigation.
  Future<String?> save({EntryType entryType = EntryType.text}) async {
    if (!state.canSave) return null;

    final entryText = state.text;
    state = state.copyWith(savePhase: SavePhase.saving, error: null);

    String? entryId;

    try {
      // Step 1: Save entry to database
      final repo = ref.read(dailyEntryRepositoryProvider);
      final timezone = DateTime.now().timeZoneName;

      entryId = await repo.create(
        transcriptRaw: entryText,
        transcriptEdited: entryText,
        entryType: entryType,
        timezone: timezone,
      );

      // Step 2: Extract signals (non-blocking for entry save)
      state = state.copyWith(savePhase: SavePhase.extracting);

      await _extractAndStoreSignals(entryId, entryText);

      // Reset state after successful save
      state = const TextEntryState();

      return entryId;
    } catch (e) {
      // If entry was saved but extraction failed, still return entry ID
      if (entryId != null) {
        state = const TextEntryState();
        return entryId;
      }

      state = state.copyWith(
        savePhase: SavePhase.idle,
        error: 'Failed to save entry: $e',
      );
      return null;
    }
  }

  /// Extracts signals and stores them in the database.
  Future<void> _extractAndStoreSignals(String entryId, String entryText) async {
    final extractionService = ref.read(signalExtractionServiceProvider);

    if (extractionService == null) {
      // AI not configured - signals will be empty
      // Entry is still saved, extraction can happen later
      return;
    }

    try {
      final signals = await extractionService.extractSignals(entryText);

      if (signals.isNotEmpty) {
        final repo = ref.read(dailyEntryRepositoryProvider);
        final signalsJson = jsonEncode(signals.toJson());
        await repo.updateExtractedSignals(entryId, signalsJson);
      }
    } on SignalExtractionError {
      // Log error but don't fail the save
      // Signals can be re-extracted later from Entry Review
    }
  }

  void clear() {
    state = const TextEntryState();
  }
}

final textEntryProvider =
    NotifierProvider<TextEntryNotifier, TextEntryState>(TextEntryNotifier.new);

/// Screen for recording or typing a new journal entry.
///
/// Per PRD Section 5.2:
/// - Voice recording with transcription
/// - Text entry as first-class alternative
class RecordEntryScreen extends ConsumerStatefulWidget {
  const RecordEntryScreen({super.key});

  @override
  ConsumerState<RecordEntryScreen> createState() => _RecordEntryScreenState();
}

class _RecordEntryScreenState extends ConsumerState<RecordEntryScreen> {
  RecordEntryMode _mode = RecordEntryMode.selection;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _transcriptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sync text controller with state
    _textController.addListener(() {
      ref.read(textEntryProvider.notifier).updateText(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  void _switchToVoiceMode() {
    setState(() => _mode = RecordEntryMode.voice);
  }

  void _switchToTextMode() {
    setState(() => _mode = RecordEntryMode.text);
    // Focus the text field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _switchToSelection() {
    setState(() => _mode = RecordEntryMode.selection);
    _textController.clear();
    ref.read(textEntryProvider.notifier).clear();
    ref.read(voiceRecordingProvider.notifier).reset();
  }

  Future<void> _handleTextSave() async {
    final entryId = await ref.read(textEntryProvider.notifier).save();
    if (entryId != null && mounted) {
      context.go('/entry/$entryId');
    }
  }

  Future<void> _handleVoiceSave() async {
    final voiceState = ref.read(voiceRecordingProvider);

    // Update text entry provider with the transcript
    ref.read(textEntryProvider.notifier).updateText(voiceState.currentTranscript);

    final entryId = await ref.read(textEntryProvider.notifier).save(
      entryType: EntryType.voice,
    );

    if (entryId != null && mounted) {
      ref.read(voiceRecordingProvider.notifier).reset();
      context.go('/entry/$entryId');
    }
  }

  Future<bool> _handleBackPress() async {
    final voiceState = ref.read(voiceRecordingProvider);

    // Handle voice mode back press
    if (_mode == RecordEntryMode.voice) {
      if (voiceState.isRecording) {
        // Ask to cancel recording
        final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel recording?'),
            content: const Text(
              'Your recording will be discarded. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Recording'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        if (shouldCancel == true) {
          await ref.read(voiceRecordingProvider.notifier).cancelRecording();
          return true;
        }
        return false;
      }

      if (voiceState.hasTranscript) {
        // Ask to discard transcript
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard entry?'),
            content: const Text(
              'Your transcript will be lost. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true) {
          ref.read(voiceRecordingProvider.notifier).reset();
          return true;
        }
        return false;
      }

      return true;
    }

    // Handle text mode back press
    if (_mode == RecordEntryMode.text && _textController.text.isNotEmpty) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard entry?'),
          content: const Text(
            'You have unsaved text. Are you sure you want to discard it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceRecordingProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          if (_mode == RecordEntryMode.text || _mode == RecordEntryMode.voice) {
            _switchToSelection();
          } else {
            context.go(AppRoutes.home);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle(voiceState)),
          leading: IconButton(
            icon: Icon(_mode == RecordEntryMode.selection
                ? Icons.close
                : Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && context.mounted) {
                if (_mode == RecordEntryMode.text ||
                    _mode == RecordEntryMode.voice) {
                  _switchToSelection();
                } else {
                  context.go(AppRoutes.home);
                }
              }
            },
          ),
          actions: _buildAppBarActions(voiceState),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBody(),
        ),
      ),
    );
  }

  String _getTitle(VoiceRecordingState voiceState) {
    switch (_mode) {
      case RecordEntryMode.selection:
        return 'Record Entry';
      case RecordEntryMode.voice:
        switch (voiceState.phase) {
          case VoiceRecordingPhase.idle:
            return 'Voice Recording';
          case VoiceRecordingPhase.recording:
          case VoiceRecordingPhase.paused:
            return 'Recording';
          case VoiceRecordingPhase.stopping:
          case VoiceRecordingPhase.transcribing:
            return 'Transcribing...';
          case VoiceRecordingPhase.editTranscript:
          case VoiceRecordingPhase.gapCheck:
          case VoiceRecordingPhase.followUp:
          case VoiceRecordingPhase.confirmSave:
            return 'Edit Transcript';
          case VoiceRecordingPhase.saved:
            return 'Saved';
          case VoiceRecordingPhase.error:
            return 'Error';
        }
      case RecordEntryMode.text:
        return 'Write Entry';
    }
  }

  List<Widget>? _buildAppBarActions(VoiceRecordingState voiceState) {
    if (_mode == RecordEntryMode.text) {
      return [
        Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(textEntryProvider);
            return TextButton(
              onPressed: state.canSave ? _handleTextSave : null,
              child: state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            );
          },
        ),
      ];
    }

    if (_mode == RecordEntryMode.voice &&
        (voiceState.phase == VoiceRecordingPhase.editTranscript ||
            voiceState.phase == VoiceRecordingPhase.confirmSave)) {
      return [
        Consumer(
          builder: (context, ref, _) {
            final textState = ref.watch(textEntryProvider);
            return TextButton(
              onPressed: voiceState.currentTranscript.isNotEmpty &&
                      !textState.isSaving
                  ? _handleVoiceSave
                  : null,
              child: textState.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save'),
            );
          },
        ),
      ];
    }

    return null;
  }

  Widget _buildBody() {
    switch (_mode) {
      case RecordEntryMode.selection:
        return _SelectionView(
          onVoicePressed: _switchToVoiceMode,
          onTextPressed: _switchToTextMode,
        );
      case RecordEntryMode.voice:
        return _VoiceRecordingView(
          transcriptController: _transcriptController,
          onSave: _handleVoiceSave,
        );
      case RecordEntryMode.text:
        return _TextEntryView(
          controller: _textController,
          focusNode: _focusNode,
          onSave: _handleTextSave,
        );
    }
  }
}

/// Mode selection view with voice and text options.
class _SelectionView extends StatelessWidget {
  const _SelectionView({
    required this.onVoicePressed,
    required this.onTextPressed,
  });

  final VoidCallback onVoicePressed;
  final VoidCallback onTextPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('selection'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voice recording button
            FilledButton.icon(
              onPressed: onVoicePressed,
              icon: const Icon(Icons.mic),
              label: const Text('Record Voice'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
            const SizedBox(height: 16),
            // Text entry button
            OutlinedButton.icon(
              onPressed: onTextPressed,
              icon: const Icon(Icons.edit),
              label: const Text('Type Instead'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Just talk about your day.\nWe\'ll extract the important signals.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voice recording view with waveform, timer, and controls.
class _VoiceRecordingView extends ConsumerStatefulWidget {
  const _VoiceRecordingView({
    required this.transcriptController,
    required this.onSave,
  });

  final TextEditingController transcriptController;
  final VoidCallback onSave;

  @override
  ConsumerState<_VoiceRecordingView> createState() =>
      _VoiceRecordingViewState();
}

class _VoiceRecordingViewState extends ConsumerState<_VoiceRecordingView> {
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
        return _IdleView(
          key: const ValueKey('idle'),
          onStartRecording: () {
            ref.read(voiceRecordingProvider.notifier).startRecording();
          },
        );

      case VoiceRecordingPhase.recording:
      case VoiceRecordingPhase.paused:
        return _RecordingView(
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
        return _TranscribingView(
          key: const ValueKey('transcribing'),
          state: state,
        );

      case VoiceRecordingPhase.editTranscript:
      case VoiceRecordingPhase.gapCheck:
      case VoiceRecordingPhase.followUp:
      case VoiceRecordingPhase.confirmSave:
        return _EditTranscriptView(
          key: const ValueKey('edit'),
          state: state,
          controller: widget.transcriptController,
          onSave: widget.onSave,
        );

      case VoiceRecordingPhase.saved:
        return const _SavedView(key: ValueKey('saved'));

      case VoiceRecordingPhase.error:
        return _ErrorView(
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
class _IdleView extends StatelessWidget {
  const _IdleView({
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
class _RecordingView extends StatelessWidget {
  const _RecordingView({
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
class _TranscribingView extends StatelessWidget {
  const _TranscribingView({
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
class _EditTranscriptView extends ConsumerWidget {
  const _EditTranscriptView({
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
class _SavedView extends StatelessWidget {
  const _SavedView({super.key});

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
class _ErrorView extends StatelessWidget {
  const _ErrorView({
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

/// Text entry view with input field and word count.
class _TextEntryView extends ConsumerWidget {
  const _TextEntryView({
    required this.controller,
    required this.focusNode,
    required this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(textEntryProvider);

    return Column(
      key: const ValueKey('text'),
      children: [
        // Error banner
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(textEntryProvider.notifier).updateText(state.text);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),

        // Word count and limit warning
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: state.isOverLimit
                ? Theme.of(context).colorScheme.errorContainer
                : state.isNearLimit
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Icon(
                state.isOverLimit
                    ? Icons.warning
                    : state.isNearLimit
                        ? Icons.info_outline
                        : Icons.edit_note,
                size: 16,
                color: state.isOverLimit
                    ? Theme.of(context).colorScheme.error
                    : state.isNearLimit
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${state.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: state.isOverLimit
                          ? Theme.of(context).colorScheme.error
                          : state.isNearLimit
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (state.isNearLimit || state.isOverLimit) ...[
                const Spacer(),
                Text(
                  state.isOverLimit
                      ? 'Over 7,500 word limit'
                      : 'Approaching limit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: state.isOverLimit
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ],
          ),
        ),

        // Text input
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'What happened today? What\'s on your mind?\n\n'
                    'Write about wins, blockers, risks, decisions you\'re '
                    'avoiding, work that feels productive but isn\'t moving '
                    'you forward, actions you\'re committing to, or insights '
                    'you\'ve had.',
                hintMaxLines: 6,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
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
                    'Tip: Just write freely. We\'ll extract signals later.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: state.canSave ? onSave : null,
                  child: state.isSaving
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
                            Text(state.saveStatusText),
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
