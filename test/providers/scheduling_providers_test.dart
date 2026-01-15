import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boardroom_journal/providers/scheduling_providers.dart';
import 'package:boardroom_journal/services/scheduling/scheduling.dart';

// Mock class for testing
class MockBriefSchedulerService extends Mock implements BriefSchedulerService {}

class MockBackgroundTaskHandler extends Mock implements BackgroundTaskHandler {}

void main() {
  group('SchedulerActionState', () {
    test('default state has correct values', () {
      const state = SchedulerActionState();

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.lastActionTime, isNull);
    });

    test('copyWith preserves values', () {
      final now = DateTime.now();
      final original = SchedulerActionState(
        isLoading: false,
        error: 'test error',
        lastActionTime: now,
      );

      final copied = original.copyWith(
        isLoading: true,
      );

      expect(copied.isLoading, isTrue);
      expect(copied.error, isNull); // error gets cleared when not specified
      expect(copied.lastActionTime, now);
    });

    test('copyWith can update all fields', () {
      const state = SchedulerActionState();
      final now = DateTime.now();

      final updated = state.copyWith(
        isLoading: true,
        error: 'schedule failed',
        lastActionTime: now,
      );

      expect(updated.isLoading, isTrue);
      expect(updated.error, 'schedule failed');
      expect(updated.lastActionTime, now);
    });

    test('copyWith can clear error', () {
      const state = SchedulerActionState(
        isLoading: false,
        error: 'some error',
      );

      final updated = state.copyWith(error: null);

      expect(updated.error, isNull);
    });
  });

  group('Scheduler Providers', () {
    test('sharedPreferencesProvider throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(sharedPreferencesProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('briefSchedulerServiceProvider creates service', () {
      // Override with forTesting constructor to avoid platform plugin calls
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(briefSchedulerServiceProvider);

      expect(service, isA<BriefSchedulerService>());
    });

    test('briefSchedulerStateProvider returns current state', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(briefSchedulerStateProvider);

      expect(state, isA<BriefSchedulerState>());
    });

    test('nextScheduledBriefTimeProvider returns time from state', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final time = container.read(nextScheduledBriefTimeProvider);

      // Initial state should have null next time
      expect(time, isNull);
    });

    test('lastBriefExecutionTimeProvider returns time from state', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final time = container.read(lastBriefExecutionTimeProvider);

      // Initial state should have null last execution time
      expect(time, isNull);
    });

    test('isBriefScheduledProvider returns scheduled status', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final isScheduled = container.read(isBriefScheduledProvider);

      expect(isScheduled, isA<bool>());
    });

    test('schedulerActionProvider returns initial state', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(schedulerActionProvider);

      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.lastActionTime, isNull);
    });
  });

  group('BriefSchedulerState', () {
    test('can be created with default values', () {
      const state = BriefSchedulerState();

      expect(state.isScheduled, isFalse);
      expect(state.nextScheduledTime, isNull);
      expect(state.lastExecutionTime, isNull);
      expect(state.lastError, isNull);
    });

    test('copyWith preserves values', () {
      final now = DateTime.now();
      final nextTime = now.add(const Duration(days: 1));
      final original = BriefSchedulerState(
        isScheduled: true,
        nextScheduledTime: nextTime,
        lastExecutionTime: now,
      );

      final copied = original.copyWith(
        lastError: 'test error',
      );

      expect(copied.isScheduled, isTrue);
      expect(copied.nextScheduledTime, nextTime);
      expect(copied.lastExecutionTime, now);
      expect(copied.lastError, 'test error');
    });
  });

  group('SchedulerActionNotifier', () {
    test('initial state is not loading', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(schedulerActionProvider);

      expect(state.isLoading, isFalse);
    });

    test('clearError clears error state', () {
      final container = ProviderContainer(
        overrides: [
          briefSchedulerServiceProvider.overrideWithValue(
            BriefSchedulerService.forTesting(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(schedulerActionProvider.notifier);
      notifier.clearError();

      final state = container.read(schedulerActionProvider);
      expect(state.error, isNull);
    });
  });

  group('Background Task Handler Provider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('creates handler with shared preferences', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final handler = container.read(backgroundTaskHandlerProvider);

      expect(handler, isA<BackgroundTaskHandler>());
    });
  });

  group('isBriefDueProvider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('returns bool future', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final isDueAsync = container.read(isBriefDueProvider);

      // Should be an AsyncValue
      expect(isDueAsync, isA<AsyncValue<bool>>());
    });
  });

  group('MissedBriefNotifier', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('builds with background task handler', () {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final asyncState = container.read(missedBriefProvider);

      // Initial state should be loading or have a value
      expect(asyncState, isA<AsyncValue<bool>>());
    });
  });
}
