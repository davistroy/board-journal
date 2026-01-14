import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/data.dart';
import '../ai/ai.dart';
import 'brief_scheduler_service.dart';

/// Notification channel ID for brief notifications.
const String briefNotificationChannelId = 'weekly_brief_channel';

/// Notification ID for new brief notifications.
const int newBriefNotificationId = 1001;

/// Shared preferences key for last execution time.
const String lastExecutionTimeKey = 'brief_scheduler_last_execution';

/// Shared preferences key for retry count.
const String retryCountKey = 'brief_scheduler_retry_count';

/// Shared preferences key for next scheduled time.
const String nextScheduledTimeKey = 'brief_scheduler_next_scheduled';

/// Background task handler for weekly brief generation.
///
/// This handler runs in an isolate separate from the main app.
/// It must be a top-level function (not a method).
///
/// Responsibilities:
/// - Generate weekly brief using AI service
/// - Save brief to database
/// - Show notification on success
/// - Handle errors with retry scheduling
/// - Track execution state via SharedPreferences
class BackgroundTaskHandler {
  final FlutterLocalNotificationsPlugin _notifications;
  final SharedPreferences _prefs;

  BackgroundTaskHandler({
    FlutterLocalNotificationsPlugin? notifications,
    required SharedPreferences prefs,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _prefs = prefs;

  /// Creates the handler with initialized dependencies.
  ///
  /// Use this factory in the background callback.
  static Future<BackgroundTaskHandler> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BackgroundTaskHandler(prefs: prefs);
  }

  /// Main entry point for background task execution.
  ///
  /// [taskName] identifies which task is being executed.
  /// Returns true if task completed successfully.
  Future<bool> onBackgroundTask(String taskName) async {
    if (taskName == weeklyBriefTaskName) {
      return _executeWeeklyBriefGeneration();
    }

    // Unknown task
    return false;
  }

  /// Executes weekly brief generation.
  Future<bool> _executeWeeklyBriefGeneration() async {
    try {
      // Get current week boundaries
      final now = DateTime.now();
      final weekRange = DateRange.forWeek(now);

      // Initialize database
      final db = await _initializeDatabase();

      // Check if brief already exists for this week
      final briefRepo = WeeklyBriefRepository(db);
      final existingBrief = await briefRepo.getByWeek(now);
      if (existingBrief != null) {
        // Brief already exists, skip generation
        await _recordSuccess();
        await _scheduleNextWeek();
        await db.close();
        return true;
      }

      // Get entries for the week
      final entryRepo = DailyEntryRepository(db);
      final entries = await entryRepo.getEntriesForWeek(now);

      // Initialize AI client
      final aiConfig = AIConfig.fromEnvironment();
      if (!aiConfig.isValid) {
        // AI not configured, retry later
        await _incrementRetryCount();
        await db.close();
        return false;
      }

      final claudeClient = ClaudeClient(
        config: ClaudeConfig.sonnet(apiKey: aiConfig.anthropicApiKey),
      );
      final briefService = WeeklyBriefGenerationService(claudeClient);

      // Generate the brief
      final generatedBrief = await briefService.generateBrief(
        entries: entries,
        weekStart: weekRange.start,
        weekEnd: weekRange.end,
      );

      // Save to database
      final timezone = now.timeZoneName;
      await briefRepo.create(
        weekStartUtc: weekRange.start,
        weekEndUtc: weekRange.end,
        weekTimezone: timezone,
        briefMarkdown: generatedBrief.briefMarkdown,
        boardMicroReviewMarkdown: generatedBrief.boardMicroReviewMarkdown,
        entryCount: generatedBrief.entryCount,
      );

      // Show success notification
      await _showBriefReadyNotification(
        entryCount: generatedBrief.entryCount,
        isReflection: generatedBrief.isReflectionBrief,
      );

      // Record success and schedule next week
      await _recordSuccess();
      await _scheduleNextWeek();

      await db.close();
      return true;
    } on BriefGenerationError catch (e) {
      // AI generation failed
      if (e.isRetryable) {
        await _incrementRetryCount();
      } else {
        // Non-retryable error, wait until next week
        await _resetRetryCount();
        await _scheduleNextWeek();
      }
      return false;
    } catch (e) {
      // Unexpected error
      await _incrementRetryCount();
      return false;
    }
  }

  /// Initializes the database for background execution.
  Future<AppDatabase> _initializeDatabase() async {
    // In background, we need to create a new database connection
    // The database path should be consistent with the main app
    return AppDatabase();
  }

  /// Shows notification that a new brief is ready.
  Future<void> _showBriefReadyNotification({
    required int entryCount,
    required bool isReflection,
  }) async {
    await _initializeNotifications();

    final title = 'Weekly Brief Ready';
    final body = isReflection
        ? 'Your weekly reflection is ready to view.'
        : 'Your brief from $entryCount ${entryCount == 1 ? "entry" : "entries"} is ready.';

    const androidDetails = AndroidNotificationDetails(
      briefNotificationChannelId,
      'Weekly Briefs',
      channelDescription: 'Notifications when your weekly brief is ready',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      newBriefNotificationId,
      title,
      body,
      details,
      payload: 'weekly_brief', // Used to navigate to brief on tap
    );
  }

  /// Initializes the notification plugin.
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Request at appropriate time
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  /// Records successful execution.
  Future<void> _recordSuccess() async {
    final now = DateTime.now().toIso8601String();
    await _prefs.setString(lastExecutionTimeKey, now);
    await _prefs.setInt(retryCountKey, 0);
  }

  /// Increments retry count and checks if max retries exceeded.
  Future<void> _incrementRetryCount() async {
    final currentCount = _prefs.getInt(retryCountKey) ?? 0;
    final newCount = currentCount + 1;

    if (newCount >= maxRetryAttempts) {
      // Max retries exceeded, reset and wait for next week
      await _resetRetryCount();
      await _scheduleNextWeek();
    } else {
      await _prefs.setInt(retryCountKey, newCount);
      // Retry will be scheduled by workmanager's backoff policy
    }
  }

  /// Resets retry count.
  Future<void> _resetRetryCount() async {
    await _prefs.setInt(retryCountKey, 0);
  }

  /// Schedules the next week's brief generation.
  Future<void> _scheduleNextWeek() async {
    // Calculate next Sunday 8pm
    final now = DateTime.now();
    var nextSunday = now.add(Duration(days: 7 - now.weekday % 7));
    if (now.weekday == DateTime.sunday && now.hour < 20) {
      nextSunday = now;
    } else if (now.weekday == DateTime.sunday) {
      nextSunday = now.add(const Duration(days: 7));
    }

    final next8pm = DateTime(
      nextSunday.year,
      nextSunday.month,
      nextSunday.day,
      20, // 8pm
    );

    await _prefs.setString(nextScheduledTimeKey, next8pm.toIso8601String());
  }

  /// Gets the last successful execution time.
  DateTime? getLastExecutionTime() {
    final stored = _prefs.getString(lastExecutionTimeKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  /// Gets the current retry count.
  int getRetryCount() {
    return _prefs.getInt(retryCountKey) ?? 0;
  }

  /// Gets the next scheduled time.
  DateTime? getNextScheduledTime() {
    final stored = _prefs.getString(nextScheduledTimeKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }

  /// Checks if a brief is due but hasn't been generated.
  ///
  /// Use this on app resume to catch missed background executions (especially iOS).
  Future<bool> isBriefDue() async {
    final nextScheduled = getNextScheduledTime();
    if (nextScheduled == null) return false;

    final now = DateTime.now();
    if (nextScheduled.isBefore(now)) {
      // Scheduled time has passed, check if brief exists
      final db = await _initializeDatabase();
      final briefRepo = WeeklyBriefRepository(db);
      final existingBrief = await briefRepo.getByWeek(now);
      await db.close();

      return existingBrief == null;
    }

    return false;
  }
}

/// Callback dispatcher for workmanager.
///
/// This MUST be a top-level function (not inside a class).
/// It's called by the workmanager plugin when a background task executes.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final handler = await BackgroundTaskHandler.create();
      return await handler.onBackgroundTask(taskName);
    } catch (e) {
      // Log error for debugging (using stderr since debugPrint unavailable in isolate)
      stderr.writeln('Background task error: $e');
      return false;
    }
  });
}

/// File-based state persistence for background tasks.
///
/// Used when SharedPreferences is not available or as a backup.
class BackgroundTaskState {
  static const String _stateFileName = 'brief_scheduler_state.json';

  /// Saves scheduler state to a file.
  static Future<void> saveState({
    DateTime? lastExecution,
    DateTime? nextScheduled,
    int retryCount = 0,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_stateFileName');

    final state = {
      'lastExecution': lastExecution?.toIso8601String(),
      'nextScheduled': nextScheduled?.toIso8601String(),
      'retryCount': retryCount,
    };

    await file.writeAsString(jsonEncode(state));
  }

  /// Loads scheduler state from a file.
  static Future<Map<String, dynamic>> loadState() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_stateFileName');

      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
