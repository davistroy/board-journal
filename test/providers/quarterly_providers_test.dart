import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/ai_providers.dart';
import 'package:boardroom_journal/providers/quarterly_providers.dart';
import 'package:boardroom_journal/services/governance/quarterly_state.dart';

void main() {
  group('QuarterlySessionState', () {
    test('default state has correct values', () {
      const state = QuarterlySessionState();

      expect(state.sessionId, isNull);
      expect(state.data, isA<QuarterlySessionData>());
      expect(state.isLoading, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.error, isNull);
      expect(state.isConfigured, isTrue);
      expect(state.currentBoardMember, isNull);
      expect(state.currentBoardQuestion, isNull);
    });

    test('isActive returns false when sessionId is null', () {
      const state = QuarterlySessionState();

      expect(state.isActive, isFalse);
    });

    test('isActive returns true when session exists and not finalized', () {
      const state = QuarterlySessionState(
        sessionId: 'test-session',
        data: QuarterlySessionData(
          currentState: QuarterlyState.sensitivityGate,
        ),
      );

      expect(state.isActive, isTrue);
    });

    test('isActive returns false when session is finalized', () {
      const state = QuarterlySessionState(
        sessionId: 'test-session',
        data: QuarterlySessionData(
          currentState: QuarterlyState.finalized,
        ),
      );

      expect(state.isActive, isFalse);
    });

    test('isActive returns false when session is abandoned', () {
      const state = QuarterlySessionState(
        sessionId: 'test-session',
        data: QuarterlySessionData(
          currentState: QuarterlyState.abandoned,
        ),
      );

      expect(state.isActive, isFalse);
    });

    test('isCompleted returns true when state is finalized', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.finalized,
        ),
      );

      expect(state.isCompleted, isTrue);
    });

    test('isCompleted returns false when state is not finalized', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.q1LastBetEvaluation,
        ),
      );

      expect(state.isCompleted, isFalse);
    });

    test('progressPercent returns value from state', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.q5PortfolioCheck,
        ),
      );

      expect(state.progressPercent, isA<int>());
      expect(state.progressPercent, greaterThanOrEqualTo(0));
      expect(state.progressPercent, lessThanOrEqualTo(100));
    });

    test('currentStateName returns display name from state', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.q1LastBetEvaluation,
        ),
      );

      expect(state.currentStateName, isA<String>());
      expect(state.currentStateName.isNotEmpty, isTrue);
    });

    test('isInBoardInterrogation returns true for core board interrogation', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.coreBoardInterrogation,
        ),
      );

      expect(state.isInBoardInterrogation, isTrue);
    });

    test('isInBoardInterrogation returns true for growth board interrogation', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.growthBoardInterrogation,
        ),
      );

      expect(state.isInBoardInterrogation, isTrue);
    });

    test('isInBoardInterrogation returns true for clarify state', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.boardInterrogationClarify,
        ),
      );

      expect(state.isInBoardInterrogation, isTrue);
    });

    test('isInBoardInterrogation returns false for other states', () {
      const state = QuarterlySessionState(
        data: QuarterlySessionData(
          currentState: QuarterlyState.q1LastBetEvaluation,
        ),
      );

      expect(state.isInBoardInterrogation, isFalse);
    });

    test('copyWith preserves values', () {
      const original = QuarterlySessionState(
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
      const state = QuarterlySessionState();

      final updated = state.copyWith(
        sessionId: 'new-session',
        isLoading: true,
        isProcessing: true,
        error: 'test error',
        isConfigured: false,
        currentBoardQuestion: 'What is your plan?',
      );

      expect(updated.sessionId, 'new-session');
      expect(updated.isLoading, isTrue);
      expect(updated.isProcessing, isTrue);
      expect(updated.error, 'test error');
      expect(updated.isConfigured, isFalse);
      expect(updated.currentBoardQuestion, 'What is your plan?');
    });

    test('copyWith clears error when null passed', () {
      const state = QuarterlySessionState(
        error: 'existing error',
      );

      final updated = state.copyWith(error: null);

      expect(updated.error, isNull);
    });
  });

  group('QuarterlyState enum', () {
    test('has all expected states', () {
      expect(QuarterlyState.values, contains(QuarterlyState.initial));
      expect(QuarterlyState.values, contains(QuarterlyState.sensitivityGate));
      expect(QuarterlyState.values, contains(QuarterlyState.gate0Prerequisites));
      expect(QuarterlyState.values, contains(QuarterlyState.q1LastBetEvaluation));
      expect(QuarterlyState.values, contains(QuarterlyState.q2CommitmentsVsActuals));
      expect(QuarterlyState.values, contains(QuarterlyState.q3AvoidedDecision));
      expect(QuarterlyState.values, contains(QuarterlyState.q4ComfortWork));
      expect(QuarterlyState.values, contains(QuarterlyState.q5PortfolioCheck));
      expect(QuarterlyState.values, contains(QuarterlyState.q6PortfolioHealthUpdate));
      expect(QuarterlyState.values, contains(QuarterlyState.coreBoardInterrogation));
      expect(QuarterlyState.values, contains(QuarterlyState.growthBoardInterrogation));
      expect(QuarterlyState.values, contains(QuarterlyState.boardInterrogationClarify));
      expect(QuarterlyState.values, contains(QuarterlyState.q9TriggerCheck));
      expect(QuarterlyState.values, contains(QuarterlyState.q10NextBet));
      expect(QuarterlyState.values, contains(QuarterlyState.generateReport));
      expect(QuarterlyState.values, contains(QuarterlyState.finalized));
      expect(QuarterlyState.values, contains(QuarterlyState.abandoned));
    });
  });

  group('QuarterlySessionData', () {
    test('default has correct values', () {
      const data = QuarterlySessionData();

      expect(data.currentState, QuarterlyState.initial);
      expect(data.abstractionMode, isFalse);
    });
  });

  group('QuarterlyEligibility', () {
    test('can be created with eligible status', () {
      const eligibility = QuarterlyEligibility(
        isEligible: true,
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.reason, isNull);
      expect(eligibility.showWarning, isFalse);
      expect(eligibility.warningMessage, isNull);
    });

    test('can be created with ineligible status and reason', () {
      const eligibility = QuarterlyEligibility(
        isEligible: false,
        reason: 'Missing: portfolio',
      );

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.reason, 'Missing: portfolio');
    });

    test('can be created with warning', () {
      const eligibility = QuarterlyEligibility(
        isEligible: true,
        showWarning: true,
        warningMessage: 'Last report was 15 days ago',
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.showWarning, isTrue);
      expect(eligibility.warningMessage, 'Last report was 15 days ago');
    });
  });

  group('Quarterly Providers', () {
    test('quarterlyAIServiceProvider returns null when Opus client is null', () {
      final container = ProviderContainer(
        overrides: [
          claudeOpusClientProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(quarterlyAIServiceProvider);

      expect(service, isNull);
    });

    test('quarterlyServiceProvider returns null when AI service is null', () {
      final container = ProviderContainer(
        overrides: [
          quarterlyAIServiceProvider.overrideWithValue(null),
          vaguenessDetectionServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(quarterlyServiceProvider);

      expect(service, isNull);
    });

    test('quarterlySessionProvider returns initial state', () {
      final container = ProviderContainer(
        overrides: [
          quarterlyServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(quarterlySessionProvider);

      expect(state.sessionId, isNull);
      expect(state.isLoading, isFalse);
      expect(state.isConfigured, isFalse);
    });

    test('hasInProgressQuarterlyProvider is a FutureProvider', () {
      expect(hasInProgressQuarterlyProvider, isA<FutureProvider<String?>>());
    });

    test('quarterlyEligibilityProvider is a FutureProvider', () {
      expect(quarterlyEligibilityProvider, isA<FutureProvider<QuarterlyEligibility>>());
    });

    test('lastOpenBetProvider is a FutureProvider', () {
      expect(lastOpenBetProvider, isA<FutureProvider<Bet?>>());
    });

    test('rememberedQuarterlyAbstractionModeProvider is a FutureProvider', () {
      expect(rememberedQuarterlyAbstractionModeProvider, isA<FutureProvider<bool?>>());
    });
  });

  group('QuarterlySessionNotifier', () {
    test('build returns unconfigured state when service is null', () {
      final container = ProviderContainer(
        overrides: [
          quarterlyServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(quarterlySessionProvider);

      expect(state.isConfigured, isFalse);
    });

    test('clearError clears the error', () {
      final container = ProviderContainer(
        overrides: [
          quarterlyServiceProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(quarterlySessionProvider.notifier);
      notifier.clearError();

      final state = container.read(quarterlySessionProvider);
      expect(state.error, isNull);
    });
  });
}
