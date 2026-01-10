import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/enums/entry_type.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../../services/ai/ai.dart';

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
  Future<String?> save() async {
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
        entryType: EntryType.text,
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
/// - Voice recording with transcription (placeholder)
/// - Text entry as first-class alternative (implemented)
class RecordEntryScreen extends ConsumerStatefulWidget {
  const RecordEntryScreen({super.key});

  @override
  ConsumerState<RecordEntryScreen> createState() => _RecordEntryScreenState();
}

class _RecordEntryScreenState extends ConsumerState<RecordEntryScreen> {
  RecordEntryMode _mode = RecordEntryMode.selection;
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

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
    super.dispose();
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
  }

  Future<void> _handleSave() async {
    final entryId = await ref.read(textEntryProvider.notifier).save();
    if (entryId != null && mounted) {
      context.go('/entry/$entryId');
    }
  }

  Future<bool> _handleBackPress() async {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          if (_mode == RecordEntryMode.text) {
            _switchToSelection();
          } else {
            context.go(AppRoutes.home);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle()),
          leading: IconButton(
            icon: Icon(_mode == RecordEntryMode.selection
                ? Icons.close
                : Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && context.mounted) {
                if (_mode == RecordEntryMode.text) {
                  _switchToSelection();
                } else {
                  context.go(AppRoutes.home);
                }
              }
            },
          ),
          actions: _mode == RecordEntryMode.text
              ? [
                  Consumer(
                    builder: (context, ref, _) {
                      final state = ref.watch(textEntryProvider);
                      return TextButton(
                        onPressed: state.canSave ? _handleSave : null,
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
                ]
              : null,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildBody(),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_mode) {
      case RecordEntryMode.selection:
        return 'Record Entry';
      case RecordEntryMode.voice:
        return 'Voice Recording';
      case RecordEntryMode.text:
        return 'Write Entry';
    }
  }

  Widget _buildBody() {
    switch (_mode) {
      case RecordEntryMode.selection:
        return _SelectionView(
          onVoicePressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice recording coming soon'),
              ),
            );
          },
          onTextPressed: _switchToTextMode,
        );
      case RecordEntryMode.voice:
        // Placeholder for voice recording
        return const Center(child: Text('Voice recording coming soon'));
      case RecordEntryMode.text:
        return _TextEntryView(
          controller: _textController,
          focusNode: _focusNode,
          onSave: _handleSave,
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
