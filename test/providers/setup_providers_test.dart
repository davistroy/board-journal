import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/providers/ai_providers.dart';
import 'package:boardroom_journal/providers/setup_providers.dart';
import 'package:boardroom_journal/services/governance/setup_state.dart';

void main() {
  group('SetupSessionState', () {
    test('default state has correct values', () {
      const state = SetupSessionState();

      expect(state.sessionId, isNull);
      expect(state.data, isA<SetupSessionData>());
      expect(state.isLoading, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
      expect(state.isConfigured, isTrue);
    });

    test('isActive returns false when sessionId is null', () {
      const state = SetupSessionState();

      expect(state.isActive, isFalse);
    });

    test('isActive returns true when session exists and not finalized', () {
      const state = SetupSessionState(
        sessionId: 'test-session',
        data: SetupSessionData(
          currentState: SetupState.sensitivityGate,
        ),
      );

      expect(state.isActive, isTrue);
    });

    test('isActive returns false when session is finalized', () {
      const state = SetupSessionState(
        sessionId: 'test-session',
        data: SetupSessionData(
          currentState: SetupState.finalized,
        ),
      );

      expect(state.isActive, isFalse);
    });

    test('isActive returns false when session is abandoned', () {
      const state = SetupSessionState(
        sessionId: 'test-session',
        data: SetupSessionData(
          currentState: SetupState.abandoned,
        ),
      );

      expect(state.isActive, isFalse);
    });

    test('isCompleted returns true when state is finalized', () {
      const state = SetupSessionState(
        data: SetupSessionData(
          currentState: SetupState.finalized,
        ),
      );

      expect(state.isCompleted, isTrue);
    });

    test('isCompleted returns false when state is not finalized', () {
      const state = SetupSessionState(
        data: SetupSessionData(
          currentState: SetupState.collectProblem1,
        ),
      );

      expect(state.isCompleted, isFalse);
    });

    test('progressPercent returns value from state', () {
      const state = SetupSessionState(
        data: SetupSessionData(
          currentState: SetupState.timeAllocation,
        ),
      );

      expect(state.progressPercent, isA<int>());
      expect(state.progressPercent, greaterThanOrEqualTo(0));
      expect(state.progressPercent, lessThanOrEqualTo(100));
    });

    test('currentStateName returns display name from state', () {
      const state = SetupSessionState(
        data: SetupSessionData(
          currentState: SetupState.collectProblem1,
        ),
      );

      expect(state.currentStateName, isA<String>());
      expect(state.currentStateName.isNotEmpty, isTrue);
    });

    test('copyWith preserves values', () {
      const original = SetupSessionState(
        sessionId: 'test-session',
        isLoading: false,
        isProcessing: false,
        isConfigured: true,
      );

      final copied = original.copyWith(
        isLoading: true,
      );

      expect(copied.sessionId, 'test-session');
      expect(copied.isLoading, isTrue);
      expect(copied.isProcessing, isFalse);
      expect(copied.isConfigured, isTrue);
    });

    test('copyWith can update all fields', () {
      const state = SetupSessionState();

      final updated = state.copyWith(
        sessionId: 'new-session',
        isLoading: true,
        isProcessing: true,
        error: 'test error',
        isConfigured: false,
      );

      expect(updated.sessionId, 'new-session');
      expect(updated.isLoading, isTrue);
      expect(updated.isProcessing, isTrue);
      expect(updated.error, 'test error');
      expect(updated.isConfigured, isFalse);
    });

    test('copyWith clears error when null passed', () {
      const state = SetupSessionState(
        error: 'existing error',
      );

      final updated = state.copyWith(error: null);

      expect(updated.error, isNull);
    });
  });

  group('SetupState enum', () {
    test('has all expected states', () {
      expect(SetupState.values, contains(SetupState.initial));
      expect(SetupState.values, contains(SetupState.sensitivityGate));
      expect(SetupState.values, contains(SetupState.collectProblem1));
      expect(SetupState.values, contains(SetupState.collectProblem2));
      expect(SetupState.values, contains(SetupState.collectProblem3));
      expect(SetupState.values, contains(SetupState.collectProblem4));
      expect(SetupState.values, contains(SetupState.collectProblem5));
      expect(SetupState.values, contains(SetupState.timeAllocation));
      expect(SetupState.values, contains(SetupState.calculateHealth));
      expect(SetupState.values, contains(SetupState.createCoreRoles));
      expect(SetupState.values, contains(SetupState.createGrowthRoles));
      expect(SetupState.values, contains(SetupState.createPersonas));
      expect(SetupState.values, contains(SetupState.defineReSetupTriggers));
      expect(SetupState.values, contains(SetupState.publishPortfolio));
      expect(SetupState.values, contains(SetupState.finalized));
      expect(SetupState.values, contains(SetupState.abandoned));
    });
  });

  group('SetupSessionData', () {
    test('default has correct values', () {
      const data = SetupSessionData();

      expect(data.currentState, SetupState.initial);
      expect(data.abstractionMode, isFalse);
      expect(data.problems, isEmpty);
    });
  });

  group('Setup Providers', () {
    test('setupAIServiceProvider returns null when Opus client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeOpusClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(setupAIServiceProvider);

      expect(service, isNull);
    });

    test('setupServiceProvider returns null when AI service is null', () {
      final container = ProviderContainer(
        overrides: [
          setupAIServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(setupServiceProvider);

      expect(service, isNull);
    });

    test('setupSessionProvider returns initial state', () {
      final container = ProviderContainer(
        overrides: [
          setupServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(setupSessionProvider);

      expect(state.sessionId, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isConfigured, isFalse);
    });

    test('hasInProgressSetupProvider is a FutureProvider', () {
      expect(hasInProgressSetupProvider, isA<FutureProvider<String?>>());
    });

    test('rememberedSetupAbstractionModeProvider is a FutureProvider', () {
      expect(rememberedSetupAbstractionModeProvider, isA<FutureProvider<bool?>>());
    });

    test('setupCompletedProvider is a FutureProvider', () {
      expect(setupCompletedProvider, isA<FutureProvider<bool>>());
    });

    test('needsSetupProvider is a StreamProvider', () {
      expect(needsSetupProvider, isA<StreamProvider<bool>>());
    });
  });

  group('SetupSessionNotifier', () {
    test('build returns unconfigured state when service is null', () {
      final container = ProviderContainer(
        overrides: [
          setupServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(setupSessionProvider);

      expect(state.isConfigured, isFalse);
    });

    test('clearError clears the error', () {
      final container = ProviderContainer(
        overrides: [
          setupServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(setupSessionProvider.notifier);
      notifier.clearError();

      final state = container.read(setupSessionProvider);
      expect(state.error, isNull);
    });
  });
}
