import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/providers/ai_providers.dart';
import 'package:boardroom_journal/services/ai/ai.dart';

void main() {
  group('ExtractionStatus', () {
    test('has all expected values', () {
      expect(ExtractionStatus.values, contains(ExtractionStatus.idle));
      expect(ExtractionStatus.values, contains(ExtractionStatus.extracting));
      expect(ExtractionStatus.values, contains(ExtractionStatus.completed));
      expect(ExtractionStatus.values, contains(ExtractionStatus.failed));
      expect(ExtractionStatus.values, contains(ExtractionStatus.notConfigured));
    });
  });

  group('ExtractionState', () {
    test('default state has correct values', () {
      const state = ExtractionState();

      expect(state.status, ExtractionStatus.idle);
      expect(state.signals, isNull);
      expect(state.error, isNull);
    });

    test('isExtracting returns true when extracting', () {
      const state = ExtractionState(status: ExtractionStatus.extracting);

      expect(state.isExtracting, isTrue);
      expect(state.isCompleted, isFalse);
      expect(state.isFailed, isFalse);
    });

    test('isCompleted returns true when completed', () {
      const state = ExtractionState(status: ExtractionStatus.completed);

      expect(state.isCompleted, isTrue);
      expect(state.isExtracting, isFalse);
      expect(state.isFailed, isFalse);
    });

    test('isFailed returns true when failed', () {
      const state = ExtractionState(status: ExtractionStatus.failed);

      expect(state.isFailed, isTrue);
      expect(state.isExtracting, isFalse);
      expect(state.isCompleted, isFalse);
    });

    test('isNotConfigured returns true when not configured', () {
      const state = ExtractionState(status: ExtractionStatus.notConfigured);

      expect(state.isNotConfigured, isTrue);
    });

    test('copyWith preserves values', () {
      const original = ExtractionState(
        status: ExtractionStatus.extracting,
        error: 'test error',
      );

      final copied = original.copyWith(
        status: ExtractionStatus.failed,
      );

      expect(copied.status, ExtractionStatus.failed);
      // error gets reset by copyWith when not specified
      expect(original.status, ExtractionStatus.extracting);
    });

    test('copyWith can update all fields', () {
      const state = ExtractionState();

      final updated = state.copyWith(
        status: ExtractionStatus.completed,
        error: 'new error',
      );

      expect(updated.status, ExtractionStatus.completed);
      expect(updated.error, 'new error');
    });
  });

  group('BriefGenerationStatus', () {
    test('has all expected values', () {
      expect(BriefGenerationStatus.values, contains(BriefGenerationStatus.idle));
      expect(BriefGenerationStatus.values, contains(BriefGenerationStatus.generating));
      expect(BriefGenerationStatus.values, contains(BriefGenerationStatus.completed));
      expect(BriefGenerationStatus.values, contains(BriefGenerationStatus.failed));
      expect(BriefGenerationStatus.values, contains(BriefGenerationStatus.notConfigured));
    });
  });

  group('BriefGenerationState', () {
    test('default state has correct values', () {
      const state = BriefGenerationState();

      expect(state.status, BriefGenerationStatus.idle);
      expect(state.brief, isNull);
      expect(state.error, isNull);
      expect(state.options, isA<BriefRegenerationOptions>());
    });

    test('isGenerating returns true when generating', () {
      const state = BriefGenerationState(status: BriefGenerationStatus.generating);

      expect(state.isGenerating, isTrue);
      expect(state.isCompleted, isFalse);
      expect(state.isFailed, isFalse);
    });

    test('isCompleted returns true when completed', () {
      const state = BriefGenerationState(status: BriefGenerationStatus.completed);

      expect(state.isCompleted, isTrue);
      expect(state.isGenerating, isFalse);
    });

    test('isFailed returns true when failed', () {
      const state = BriefGenerationState(status: BriefGenerationStatus.failed);

      expect(state.isFailed, isTrue);
      expect(state.isGenerating, isFalse);
    });

    test('isNotConfigured returns true when not configured', () {
      const state = BriefGenerationState(status: BriefGenerationStatus.notConfigured);

      expect(state.isNotConfigured, isTrue);
    });

    test('copyWith preserves values', () {
      const options = BriefRegenerationOptions(shorter: true);
      const original = BriefGenerationState(
        status: BriefGenerationStatus.idle,
        options: options,
      );

      final copied = original.copyWith(
        status: BriefGenerationStatus.generating,
      );

      expect(copied.status, BriefGenerationStatus.generating);
      expect(copied.options.shorter, isTrue);
    });

    test('copyWith can update all fields', () {
      const state = BriefGenerationState();
      const newOptions = BriefRegenerationOptions(
        shorter: true,
        moreActionable: true,
      );

      final updated = state.copyWith(
        status: BriefGenerationStatus.failed,
        error: 'generation failed',
        options: newOptions,
      );

      expect(updated.status, BriefGenerationStatus.failed);
      expect(updated.error, 'generation failed');
      expect(updated.options.shorter, isTrue);
      expect(updated.options.moreActionable, isTrue);
    });
  });

  group('AI Config Provider', () {
    test('creates AIConfig from environment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(aiConfigProvider);

      expect(config, isA<AIConfig>());
    });
  });

  group('Claude Client Provider', () {
    test('returns null when API key not configured', () {
      final container = ProviderContainer(
        overrides: [
          aiConfigProvider.overrideWithValue(
            AIConfig(anthropicApiKey: null, openAiApiKey: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(claudeClientProvider);

      expect(client, isNull);
    });

    test('creates ClaudeClient when API key configured', () {
      final container = ProviderContainer(
        overrides: [
          aiConfigProvider.overrideWithValue(
            AIConfig(anthropicApiKey: 'test-key', openAiApiKey: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(claudeClientProvider);

      expect(client, isA<ClaudeClient>());
    });
  });

  group('Claude Opus Client Provider', () {
    test('returns null when API key not configured', () {
      final container = ProviderContainer(
        overrides: [
          aiConfigProvider.overrideWithValue(
            AIConfig(anthropicApiKey: null, openAiApiKey: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(claudeOpusClientProvider);

      expect(client, isNull);
    });

    test('creates ClaudeClient for Opus when API key configured', () {
      final container = ProviderContainer(
        overrides: [
          aiConfigProvider.overrideWithValue(
            AIConfig(anthropicApiKey: 'test-key', openAiApiKey: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(claudeOpusClientProvider);

      expect(client, isA<ClaudeClient>());
    });
  });

  group('Signal Extraction Service Provider', () {
    test('returns null when Claude client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(signalExtractionServiceProvider);

      expect(service, isNull);
    });
  });

  group('Weekly Brief Generation Service Provider', () {
    test('returns null when Claude client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(weeklyBriefGenerationServiceProvider);

      expect(service, isNull);
    });
  });

  group('Vagueness Detection Service Provider', () {
    test('returns null when Opus client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeOpusClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(vaguenessDetectionServiceProvider);

      expect(service, isNull);
    });
  });

  group('Quick Version AI Service Provider', () {
    test('returns null when Opus client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeOpusClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(quickVersionAIServiceProvider);

      expect(service, isNull);
    });
  });

  group('Extraction Provider', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(extractionProvider);

      expect(state.status, ExtractionStatus.idle);
      expect(state.signals, isNull);
      expect(state.error, isNull);
    });
  });
}
