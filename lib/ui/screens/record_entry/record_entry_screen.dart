import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/enums/entry_type.dart';
import '../../../providers/audio_providers.dart';
import '../../../router/router.dart';
import 'widgets/widgets.dart';

/// Entry mode for the record screen.
enum RecordEntryMode {
  /// Initial selection screen.
  selection,

  /// Voice recording mode.
  voice,

  /// Text typing mode.
  text,
}

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

    if (_mode == RecordEntryMode.voice) {
      if (voiceState.isRecording) {
        final shouldCancel = await _showCancelRecordingDialog();
        if (shouldCancel == true) {
          await ref.read(voiceRecordingProvider.notifier).cancelRecording();
          return true;
        }
        return false;
      }

      if (voiceState.hasTranscript) {
        final shouldDiscard = await _showDiscardDialog('transcript');
        if (shouldDiscard == true) {
          ref.read(voiceRecordingProvider.notifier).reset();
          return true;
        }
        return false;
      }
      return true;
    }

    if (_mode == RecordEntryMode.text && _textController.text.isNotEmpty) {
      final shouldDiscard = await _showDiscardDialog('text');
      return shouldDiscard ?? false;
    }
    return true;
  }

  Future<bool?> _showCancelRecordingDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel recording?'),
        content: const Text('Your recording will be discarded. Continue?'),
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
  }

  Future<bool?> _showDiscardDialog(String type) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard entry?'),
        content: Text(
          type == 'transcript'
              ? 'Your transcript will be lost. Continue?'
              : 'You have unsaved text. Are you sure you want to discard it?',
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        return SelectionView(
          onVoicePressed: _switchToVoiceMode,
          onTextPressed: _switchToTextMode,
        );
      case RecordEntryMode.voice:
        return VoiceRecordingView(
          transcriptController: _transcriptController,
          onSave: _handleVoiceSave,
        );
      case RecordEntryMode.text:
        return TextEntryView(
          controller: _textController,
          focusNode: _focusNode,
          onSave: _handleTextSave,
        );
    }
  }
}
