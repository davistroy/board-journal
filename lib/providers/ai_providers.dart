import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/ai.dart';

// ==================
// AI Configuration Provider
// ==================

/// Provider for AI configuration.
///
/// Reads from environment by default. Override for testing.
final aiConfigProvider = Provider<AIConfig>((ref) {
  return AIConfig.fromEnvironment();
});

// ==================
// Claude Client Provider
// ==================

/// Provider for the Claude API client (Sonnet for daily operations).
///
/// Per PRD Section 3A.1: Claude Sonnet 4.5 for signal extraction,
/// weekly briefs, follow-up questions, and board micro-reviews.
final claudeClientProvider = Provider<ClaudeClient?>((ref) {
  final config = ref.watch(aiConfigProvider);

  if (!config.isValid) {
    // Return null if no API key configured
    return null;
  }

  return ClaudeClient(
    config: ClaudeConfig.sonnet(apiKey: config.anthropicApiKey),
  );
});

/// Provider for the Claude API client (Opus for governance).
///
/// Per PRD Section 3A.1: Claude Opus 4.5 for governance features
/// like Quarterly Reports and Setup analysis.
final claudeOpusClientProvider = Provider<ClaudeClient?>((ref) {
  final config = ref.watch(aiConfigProvider);

  if (!config.isValid) {
    return null;
  }

  return ClaudeClient(
    config: ClaudeConfig.opus(apiKey: config.anthropicApiKey),
  );
});

// ==================
// Signal Extraction Service Provider
// ==================

/// Provider for the signal extraction service.
///
/// Returns null if Claude client is not configured.
final signalExtractionServiceProvider = Provider<SignalExtractionService?>((ref) {
  final client = ref.watch(claudeClientProvider);

  if (client == null) {
    return null;
  }

  return SignalExtractionService(client);
});

// ==================
// Extraction State Management
// ==================

/// State for signal extraction process.
enum ExtractionStatus {
  /// Not started.
  idle,

  /// Extraction in progress.
  extracting,

  /// Extraction completed successfully.
  completed,

  /// Extraction failed (can retry).
  failed,

  /// AI service not configured.
  notConfigured,
}

/// State class for signal extraction.
class ExtractionState {
  final ExtractionStatus status;
  final ExtractedSignals? signals;
  final String? error;

  const ExtractionState({
    this.status = ExtractionStatus.idle,
    this.signals,
    this.error,
  });

  ExtractionState copyWith({
    ExtractionStatus? status,
    ExtractedSignals? signals,
    String? error,
  }) {
    return ExtractionState(
      status: status ?? this.status,
      signals: signals ?? this.signals,
      error: error,
    );
  }

  bool get isExtracting => status == ExtractionStatus.extracting;
  bool get isCompleted => status == ExtractionStatus.completed;
  bool get isFailed => status == ExtractionStatus.failed;
  bool get isNotConfigured => status == ExtractionStatus.notConfigured;
}

/// Notifier for managing signal extraction state.
class ExtractionNotifier extends AutoDisposeNotifier<ExtractionState> {
  @override
  ExtractionState build() => const ExtractionState();

  /// Extracts signals from the given entry text.
  Future<ExtractedSignals?> extractSignals(String entryText) async {
    final service = ref.read(signalExtractionServiceProvider);

    if (service == null) {
      state = const ExtractionState(
        status: ExtractionStatus.notConfigured,
        error: 'AI service not configured. Signals will be extracted later.',
      );
      return null;
    }

    state = const ExtractionState(status: ExtractionStatus.extracting);

    try {
      final signals = await service.extractSignals(entryText);
      state = ExtractionState(
        status: ExtractionStatus.completed,
        signals: signals,
      );
      return signals;
    } on SignalExtractionError catch (e) {
      state = ExtractionState(
        status: ExtractionStatus.failed,
        error: e.message,
      );
      return null;
    } catch (e) {
      state = ExtractionState(
        status: ExtractionStatus.failed,
        error: 'Failed to extract signals: $e',
      );
      return null;
    }
  }

  /// Resets the extraction state.
  void reset() {
    state = const ExtractionState();
  }
}

/// Provider for extraction state management.
final extractionProvider =
    NotifierProvider.autoDispose<ExtractionNotifier, ExtractionState>(
  ExtractionNotifier.new,
);
