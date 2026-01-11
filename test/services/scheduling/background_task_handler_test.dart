import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boardroom_journal/services/scheduling/background_task_handler.dart';
import 'package:boardroom_journal/services/scheduling/brief_scheduler_service.dart';

void main() {
  group('BackgroundTaskHandler Constants', () {
    test('briefNotificationChannelId is defined', () {
      expect(briefNotificationChannelId, 'weekly_brief_channel');
    });

    test('newBriefNotificationId is defined', () {
      expect(newBriefNotificationId, 1001);
    });

    test('lastExecutionTimeKey is defined', () {
      expect(lastExecutionTimeKey, 'brief_scheduler_last_execution');
    });

    test('retryCountKey is defined', () {
      expect(retryCountKey, 'brief_scheduler_retry_count');
    });

    test('nextScheduledTimeKey is defined', () {
      expect(nextScheduledTimeKey, 'brief_scheduler_next_scheduled');
    });
  });

  group('BackgroundTaskHandler', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('creates handler with shared preferences', () {
      final handler = BackgroundTaskHandler(prefs: prefs);

      expect(handler, isNotNull);
    });

    test('getLastExecutionTime returns null when not set', () {
      final handler = BackgroundTaskHandler(prefs: prefs);

      expect(handler.getLastExecutionTime(), isNull);
    });

    test('getLastExecutionTime returns stored time', () async {
      final testTime = DateTime(2026, 1, 10, 20, 0);
      await prefs.setString(lastExecutionTimeKey, testTime.toIso8601String());

      final handler = BackgroundTaskHandler(prefs: prefs);
      final result = handler.getLastExecutionTime();

      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 1);
      expect(result.day, 10);
    });

    test('getRetryCount returns 0 when not set', () {
      final handler = BackgroundTaskHandler(prefs: prefs);

      expect(handler.getRetryCount(), 0);
    });

    test('getRetryCount returns stored count', () async {
      await prefs.setInt(retryCountKey, 3);

      final handler = BackgroundTaskHandler(prefs: prefs);

      expect(handler.getRetryCount(), 3);
    });

    test('getNextScheduledTime returns null when not set', () {
      final handler = BackgroundTaskHandler(prefs: prefs);

      expect(handler.getNextScheduledTime(), isNull);
    });

    test('getNextScheduledTime returns stored time', () async {
      final testTime = DateTime(2026, 1, 12, 20, 0); // Next Sunday 8pm
      await prefs.setString(nextScheduledTimeKey, testTime.toIso8601String());

      final handler = BackgroundTaskHandler(prefs: prefs);
      final result = handler.getNextScheduledTime();

      expect(result, isNotNull);
      expect(result!.hour, 20);
    });

    test('onBackgroundTask returns false for unknown task', () async {
      final handler = BackgroundTaskHandler(prefs: prefs);

      final result = await handler.onBackgroundTask('unknown_task');

      expect(result, isFalse);
    });
  });

  group('BackgroundTaskState', () {
    test('loadState returns empty map when file does not exist', () async {
      final state = await BackgroundTaskState.loadState();

      expect(state, isEmpty);
    });
  });

  group('weeklyBriefTaskName constant', () {
    test('task name is defined correctly', () {
      expect(weeklyBriefTaskName, 'weekly_brief_generation');
    });
  });

  group('maxRetryAttempts constant', () {
    test('max retry attempts is defined', () {
      expect(maxRetryAttempts, isA<int>());
      expect(maxRetryAttempts, greaterThan(0));
    });
  });
}
