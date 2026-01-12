import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/enums/entry_type.dart';
import '../../../../providers/providers.dart';
import '../../../../services/ai/ai.dart';

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
