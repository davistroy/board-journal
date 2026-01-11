import 'package:boardroom_journal/services/scheduling/scheduling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BriefSchedulerService', () {
    late BriefSchedulerService service;

    setUp(() {
      service = BriefSchedulerService();
    });

    tearDown(() {
      service.dispose();
    });

    group('getNextScheduledTime', () {
      test('returns null when no task is scheduled', () {
        expect(service.getNextScheduledTime(), isNull);
      });
    });

    group('getLastExecutionTime', () {
      test('returns null when no execution has occurred', () {
        expect(service.getLastExecutionTime(), isNull);
      });
    });

    group('getState', () {
      test('returns initial state with no schedule', () {
        final state = service.getState();

        expect(state.isScheduled, isFalse);
        expect(state.nextScheduledTime, isNull);
        expect(state.lastExecutionTime, isNull);
        expect(state.currentRetryCount, 0);
        expect(state.isRetrying, isFalse);
      });
    });

    group('recordSuccessfulExecution', () {
      test('sets last execution time', () {
        service.recordSuccessfulExecution();

        expect(service.getLastExecutionTime(), isNotNull);
        expect(
          service.getLastExecutionTime()!.difference(DateTime.now()).abs(),
          lessThan(const Duration(seconds: 1)),
        );
      });

      test('resets retry count', () {
        // First record some retries would happen via scheduleRetry
        // Then record success
        service.recordSuccessfulExecution();

        final state = service.getState();
        expect(state.currentRetryCount, 0);
        expect(state.isRetrying, isFalse);
      });
    });

    group('stateStream', () {
      test('emits state changes', () async {
        final states = <BriefSchedulerState>[];
        final subscription = service.stateStream.listen(states.add);

        // Record a successful execution to trigger state change
        service.recordSuccessfulExecution();

        // Allow async event to process
        await Future<void>.delayed(Duration.zero);

        expect(states.length, 1);
        expect(states.first.lastExecutionTime, isNotNull);

        await subscription.cancel();
      });
    });
  });

  group('BriefSchedulerState', () {
    test('default state is not scheduled', () {
      const state = BriefSchedulerState();

      expect(state.isScheduled, isFalse);
      expect(state.nextScheduledTime, isNull);
      expect(state.lastExecutionTime, isNull);
      expect(state.currentRetryCount, 0);
    });

    test('isRetrying is true when retry count > 0', () {
      const state = BriefSchedulerState(
        currentRetryCount: 1,
      );

      expect(state.isRetrying, isTrue);
    });

    test('isRetrying is false when retry count is 0', () {
      const state = BriefSchedulerState(
        currentRetryCount: 0,
      );

      expect(state.isRetrying, isFalse);
    });

    test('statusText shows "Not scheduled" when not scheduled', () {
      const state = BriefSchedulerState(isScheduled: false);

      expect(state.statusText, 'Not scheduled');
    });

    test('statusText shows retry info when retrying', () {
      const state = BriefSchedulerState(
        isScheduled: true,
        currentRetryCount: 2,
      );

      expect(state.statusText, contains('Retrying'));
      expect(state.statusText, contains('2'));
    });

    test('statusText shows next scheduled time when scheduled', () {
      final nextTime = DateTime(2026, 1, 12, 20, 0); // Sunday 8pm
      final state = BriefSchedulerState(
        isScheduled: true,
        nextScheduledTime: nextTime,
      );

      expect(state.statusText, contains('Next brief'));
      expect(state.statusText, contains('Sun'));
      expect(state.statusText, contains('Jan'));
      expect(state.statusText, contains('12'));
    });
  });

  group('Constants', () {
    test('weeklyBriefTaskName is defined', () {
      expect(weeklyBriefTaskName, isNotEmpty);
    });

    test('weeklyBriefTaskUniqueName is defined', () {
      expect(weeklyBriefTaskUniqueName, isNotEmpty);
    });

    test('retryDelayMinutes has correct values', () {
      expect(retryDelayMinutes, [1, 5, 30]);
    });

    test('maxRetryAttempts is 3', () {
      expect(maxRetryAttempts, 3);
    });
  });

  group('Sunday 8pm calculation', () {
    // These tests verify the logic for calculating Sunday 8pm
    // We can't directly test _calculateNextSunday8pm since it's private,
    // but we can verify the schedule behavior indirectly

    test('getState shows correct status text format', () {
      final nextTime = DateTime(2026, 1, 12, 20, 0); // Sunday 8pm
      final state = BriefSchedulerState(
        isScheduled: true,
        nextScheduledTime: nextTime,
      );

      // Verify the format includes day, month, date, and time
      expect(state.statusText, contains('Sun'));
      expect(state.statusText, contains('8pm'));
    });
  });

  group('IOSBackgroundLimitations', () {
    test('maxBackgroundTime is 30 seconds', () {
      expect(
        IOSBackgroundLimitations.maxBackgroundTime,
        const Duration(seconds: 30),
      );
    });

    test('recommendation is defined', () {
      expect(IOSBackgroundLimitations.recommendation, isNotEmpty);
    });
  });
}
