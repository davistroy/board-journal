import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/providers/ai_providers.dart';
import 'package:boardroom_journal/providers/quick_version_providers.dart';
import 'package:boardroom_journal/services/governance/quick_version_state.dart';

void main() {
  group('QuickVersionSessionState', () {
    test('default state has correct values', () {
      const state = QuickVersionSessionState();

      expect(state.sessionId, isNull);
      expect(state.data, isA<QuickVersionSessionData>());
      expect(state.isLoading, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
      expect(state.isConfigured, isTrue);
    });

    test('isActive returns false when sessionId is null', () {
      const state = QuickVersionSessionState();

      expect(state.isActive, isFalse);
    });

    test('isActive returns true when session exists and not finalized', () {
      const state = QuickVersionSessionState(
        sessionId: 'test-session',
        data: QuickVersionSessionData(
          currentState: QuickVersionState.sensitivityGate,
        ),
      );

      expect(state.isActive, isTrue);
    });

    test('isActive returns false when session is finalized', () {
      const state = QuickVersionSessionState(
        sessionId: 'test-session',
        data: QuickVersionSessionData(
          currentState: QuickVersionState.finalized,
        ),
      );

      expect(state.isActive, isFalse);
    });

    test('isCompleted returns true when state is finalized', () {
      const state = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.finalized,
        ),
      );

      expect(state.isCompleted, isTrue);
    });

    test('isCompleted returns false when state is not finalized', () {
      const state = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q1RoleContext,
        ),
      );

      expect(state.isCompleted, isFalse);
    });

    test('questionNumber returns correct value for question states', () {
      const state1 = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q1RoleContext,
        ),
      );
      expect(state1.questionNumber, 1);

      const state2 = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q2PaidProblems,
        ),
      );
      expect(state2.questionNumber, 2);

      const state3 = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q3DirectionLoop,
        ),
      );
      expect(state3.questionNumber, 3);

      const state4 = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q4AvoidedDecision,
        ),
      );
      expect(state4.questionNumber, 4);

      const state5 = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q5ComfortWork,
        ),
      );
      expect(state5.questionNumber, 5);
    });

    test('progressPercent returns value from state', () {
      const state = QuickVersionSessionState(
        data: QuickVersionSessionData(
          currentState: QuickVersionState.q3DirectionLoop,
        ),
      );

      // Progress percent is defined on the state enum
      expect(state.progressPercent, isA<int>());
      expect(state.progressPercent, greaterThanOrEqualTo(0));
      expect(state.progressPercent, lessThanOrEqualTo(100));
    });

    test('copyWith preserves values', () {
      const original = QuickVersionSessionState(
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
      const state = QuickVersionSessionState();

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
      const state = QuickVersionSessionState(
        error: 'existing error',
      );

      final updated = state.copyWith(error: null);

      expect(updated.error, isNull);
    });
  });

  group('QuickVersionState enum', () {
    test('has all expected states', () {
      expect(QuickVersionState.values, contains(QuickVersionState.initial));
      expect(QuickVersionState.values, contains(QuickVersionState.sensitivityGate));
      expect(QuickVersionState.values, contains(QuickVersionState.q1RoleContext));
      expect(QuickVersionState.values, contains(QuickVersionState.q2PaidProblems));
      expect(QuickVersionState.values, contains(QuickVersionState.q3DirectionLoop));
      expect(QuickVersionState.values, contains(QuickVersionState.q4AvoidedDecision));
      expect(QuickVersionState.values, contains(QuickVersionState.q5ComfortWork));
      expect(QuickVersionState.values, contains(QuickVersionState.generateOutput));
      expect(QuickVersionState.values, contains(QuickVersionState.finalized));
    });
  });

  group('QuickVersionSessionData', () {
    test('default has correct values', () {
      const data = QuickVersionSessionData();

      expect(data.currentState, QuickVersionState.initial);
      expect(data.abstractionMode, isFalse);
      expect(data.vaguenessSkipCount, 0);
    });

    test('canSkip returns true when skip count is low', () {
      const data = QuickVersionSessionData(vaguenessSkipCount: 0);

      expect(data.canSkip, isTrue);
    });

    test('canSkip returns true when skip count is 1', () {
      const data = QuickVersionSessionData(vaguenessSkipCount: 1);

      expect(data.canSkip, isTrue);
    });

    test('canSkip returns false when skip count reaches max', () {
      const data = QuickVersionSessionData(vaguenessSkipCount: 2);

      expect(data.canSkip, isFalse);
    });
  });

  group('Quick Version Providers', () {
    test('quickVersionServiceProvider returns null when AI not configured', () {
      final container = ProviderContainer(
        overrides: [
          vaguenessDetectionServiceProvider.overrideWithValue(null),
          quickVersionAIServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(quickVersionServiceProvider);

      expect(service, isNull);
    });

    test('quickVersionSessionProvider returns initial state', () {
      final container = ProviderContainer(
        overrides: [
          quickVersionServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(quickVersionSessionProvider);

      expect(state.sessionId, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isConfigured, isFalse);
    });

    test('hasInProgressQuickVersionProvider is a FutureProvider', () {
      expect(hasInProgressQuickVersionProvider, isA<FutureProvider<String?>>());
    });

    test('quickVersionWeeklyCountProvider is a FutureProvider', () {
      expect(quickVersionWeeklyCountProvider, isA<FutureProvider<int>>());
    });

    test('rememberedAbstractionModeProvider is a FutureProvider', () {
      expect(rememberedAbstractionModeProvider, isA<FutureProvider<bool?>>());
    });
  });

  group('QuickVersionSessionNotifier', () {
    test('build returns unconfigured state when service is null', () {
      final container = ProviderContainer(
        overrides: [
          quickVersionServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(quickVersionSessionProvider);

      expect(state.isConfigured, isFalse);
    });

    test('clearError clears the error', () {
      final container = ProviderContainer(
        overrides: [
          quickVersionServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(quickVersionSessionProvider.notifier);
      notifier.clearError();

      final state = container.read(quickVersionSessionProvider);
      expect(state.error, isNull);
    });
  });
}
