import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

/// Task name for weekly brief generation.
const String weeklyBriefTaskName = 'weekly_brief_generation';

/// Unique name for the weekly brief periodic task.
const String weeklyBriefTaskUniqueName = 'boardroom_journal_weekly_brief';

/// Retry delays for exponential backoff (in minutes).
const List<int> retryDelayMinutes = [1, 5, 30];

/// Maximum retry attempts per scheduled slot.
const int maxRetryAttempts = 3;

/// Service for scheduling automatic weekly brief generation.
///
/// Per PRD Section 4.2:
/// - Auto-generates Sunday 8pm local time
/// - Handles timezone changes gracefully
/// - Retries on failure with exponential backoff
///
/// Platform Considerations:
/// - **Android:** workmanager with periodic task (can wake device)
/// - **iOS:** Limited to background fetch (less reliable)
///   iOS may defer or skip background tasks based on system conditions.
///   Brief generation may need to happen on next app open if background
///   execution was not possible.
class BriefSchedulerService {
  final Workmanager _workmanager;

  /// Stored next scheduled time for display purposes.
  DateTime? _nextScheduledTime;

  /// Last successful execution time.
  DateTime? _lastExecutionTime;

  /// Current retry count for this scheduling slot.
  int _currentRetryCount = 0;

  /// Stream controller for scheduler state changes.
  final _stateController = StreamController<BriefSchedulerState>.broadcast();

  /// Stream of scheduler state changes.
  Stream<BriefSchedulerState> get stateStream => _stateController.stream;

  BriefSchedulerService({Workmanager? workmanager})
      : _workmanager = workmanager ?? Workmanager();

  /// Initializes the background task worker.
  ///
  /// Must be called once at app startup before scheduling any tasks.
  /// The [callbackDispatcher] is the top-level function that handles
  /// background task execution.
  Future<void> initialize(Function callbackDispatcher) async {
    await _workmanager.initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Schedules the weekly brief generation for Sunday 8pm local time.
  ///
  /// Calculates the next Sunday at 8pm based on device timezone and
  /// schedules a one-off task. When that task executes, it will
  /// reschedule itself for the next week.
  Future<void> scheduleWeeklyBrief() async {
    final nextSunday8pm = _calculateNextSunday8pm();
    _nextScheduledTime = nextSunday8pm;
    _currentRetryCount = 0;

    // Calculate initial delay from now until Sunday 8pm
    final now = DateTime.now();
    final initialDelay = nextSunday8pm.difference(now);

    // Use one-off task with specific delay rather than periodic
    // This gives us more control over the exact execution time
    await _workmanager.registerOneOffTask(
      weeklyBriefTaskUniqueName,
      weeklyBriefTaskName,
      initialDelay: initialDelay.isNegative ? Duration.zero : initialDelay,
      constraints: Constraints(
        networkType: NetworkType.connected, // Need network for AI generation
        requiresBatteryNotLow: false, // Generate even on low battery
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    _emitState();
  }

  /// Cancels the scheduled weekly brief task.
  Future<void> cancelScheduledBrief() async {
    await _workmanager.cancelByUniqueName(weeklyBriefTaskUniqueName);
    _nextScheduledTime = null;
    _currentRetryCount = 0;
    _emitState();
  }

  /// Reschedules the weekly brief.
  ///
  /// Call this when:
  /// - Device timezone changes
  /// - User manually triggers reschedule
  /// - After successful execution to schedule next week
  Future<void> reschedule() async {
    await cancelScheduledBrief();
    await scheduleWeeklyBrief();
  }

  /// Returns the next scheduled execution time.
  ///
  /// Returns null if no task is scheduled.
  DateTime? getNextScheduledTime() => _nextScheduledTime;

  /// Returns the last successful execution time.
  DateTime? getLastExecutionTime() => _lastExecutionTime;

  /// Triggers immediate brief generation.
  ///
  /// Use for manual "Generate Now" functionality.
  /// Does not affect the regular weekly schedule.
  Future<void> executeNow() async {
    await _workmanager.registerOneOffTask(
      '${weeklyBriefTaskUniqueName}_immediate',
      weeklyBriefTaskName,
      initialDelay: Duration.zero,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Checks if the current schedule is still valid and reschedules if needed.
  ///
  /// Call this when:
  /// - App resumes from background
  /// - Timezone might have changed
  ///
  /// Returns true if schedule was updated, false if already valid.
  Future<bool> checkAndReschedule() async {
    final nextScheduled = _nextScheduledTime;
    if (nextScheduled == null) {
      // No schedule exists, create one
      await scheduleWeeklyBrief();
      return true;
    }

    // Check if scheduled time is in the past (task may have failed or been missed)
    final now = DateTime.now();
    if (nextScheduled.isBefore(now)) {
      // Schedule was missed, reschedule for next week
      await reschedule();
      return true;
    }

    // Check if timezone changed by comparing expected Sunday 8pm
    final expectedSunday8pm = _calculateNextSunday8pm();
    final scheduledDiff = nextScheduled.difference(expectedSunday8pm).abs();

    // If difference is more than 1 hour, timezone likely changed
    if (scheduledDiff > const Duration(hours: 1)) {
      await reschedule();
      return true;
    }

    return false;
  }

  /// Schedules a retry with exponential backoff.
  ///
  /// Called by the background task handler when generation fails.
  /// Returns true if retry was scheduled, false if max retries exceeded.
  Future<bool> scheduleRetry() async {
    if (_currentRetryCount >= maxRetryAttempts) {
      // Max retries exceeded, wait until next Sunday
      _currentRetryCount = 0;
      await reschedule();
      return false;
    }

    final delayMinutes = retryDelayMinutes[_currentRetryCount];
    _currentRetryCount++;

    await _workmanager.registerOneOffTask(
      '${weeklyBriefTaskUniqueName}_retry_$_currentRetryCount',
      weeklyBriefTaskName,
      initialDelay: Duration(minutes: delayMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    _emitState();
    return true;
  }

  /// Records successful execution.
  ///
  /// Called by the background task handler after successful generation.
  void recordSuccessfulExecution() {
    _lastExecutionTime = DateTime.now();
    _currentRetryCount = 0;
    _emitState();
  }

  /// Gets the current scheduler state.
  BriefSchedulerState getState() {
    return BriefSchedulerState(
      nextScheduledTime: _nextScheduledTime,
      lastExecutionTime: _lastExecutionTime,
      currentRetryCount: _currentRetryCount,
      isScheduled: _nextScheduledTime != null,
    );
  }

  /// Calculates the next Sunday at 8pm local time.
  DateTime _calculateNextSunday8pm() {
    final now = DateTime.now();
    final localTimezone = tz.local;

    // Get current time in local timezone
    final localNow = tz.TZDateTime.from(now, localTimezone);

    // Calculate days until next Sunday (Sunday = 7 in DateTime.weekday)
    // If today is Sunday and it's before 8pm, use today
    // Otherwise, calculate next Sunday
    int daysUntilSunday;
    if (localNow.weekday == DateTime.sunday) {
      // Today is Sunday
      final today8pm = tz.TZDateTime(
        localTimezone,
        localNow.year,
        localNow.month,
        localNow.day,
        20, // 8pm
      );
      if (localNow.isBefore(today8pm)) {
        // It's before 8pm on Sunday, use today
        daysUntilSunday = 0;
      } else {
        // It's after 8pm on Sunday, use next Sunday
        daysUntilSunday = 7;
      }
    } else {
      // Calculate days until Sunday
      daysUntilSunday = DateTime.sunday - localNow.weekday;
      if (daysUntilSunday <= 0) {
        daysUntilSunday += 7;
      }
    }

    // Create the target Sunday at 8pm
    final targetDay = localNow.add(Duration(days: daysUntilSunday));
    final sunday8pm = tz.TZDateTime(
      localTimezone,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      20, // 8pm (20:00)
    );

    return sunday8pm;
  }

  void _emitState() {
    _stateController.add(getState());
  }

  /// Disposes the service.
  void dispose() {
    _stateController.close();
  }
}

/// State of the brief scheduler.
class BriefSchedulerState {
  /// Next scheduled execution time (null if not scheduled).
  final DateTime? nextScheduledTime;

  /// Last successful execution time.
  final DateTime? lastExecutionTime;

  /// Current retry count for this scheduling slot.
  final int currentRetryCount;

  /// Whether a task is currently scheduled.
  final bool isScheduled;

  /// Last error message (null if no error).
  final String? lastError;

  const BriefSchedulerState({
    this.nextScheduledTime,
    this.lastExecutionTime,
    this.currentRetryCount = 0,
    this.isScheduled = false,
    this.lastError,
  });

  /// Creates a copy of this state with the given fields replaced.
  BriefSchedulerState copyWith({
    DateTime? nextScheduledTime,
    DateTime? lastExecutionTime,
    int? currentRetryCount,
    bool? isScheduled,
    String? lastError,
  }) {
    return BriefSchedulerState(
      nextScheduledTime: nextScheduledTime ?? this.nextScheduledTime,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      currentRetryCount: currentRetryCount ?? this.currentRetryCount,
      isScheduled: isScheduled ?? this.isScheduled,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Whether currently in retry mode.
  bool get isRetrying => currentRetryCount > 0;

  /// Human-readable status for UI display.
  String get statusText {
    if (!isScheduled) {
      return 'Not scheduled';
    }
    if (isRetrying) {
      return 'Retrying (attempt $currentRetryCount of $maxRetryAttempts)';
    }
    if (nextScheduledTime != null) {
      return 'Next brief: ${_formatDateTime(nextScheduledTime!)}';
    }
    return 'Scheduled';
  }

  static String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    return '$weekday, $month ${dt.day} at $hour$ampm';
  }
}

/// iOS-specific notes for background execution.
///
/// iOS Background Fetch Limitations:
/// 1. iOS may defer or skip background fetch based on:
///    - Battery level
///    - User engagement patterns
///    - System resource availability
///
/// 2. Background fetch interval is determined by iOS, not the app.
///    The app can request fetch but cannot guarantee timing.
///
/// 3. Background execution time is limited (~30 seconds).
///    If brief generation takes longer, it may be terminated.
///
/// Recommended iOS Strategy:
/// - Schedule background task as usual
/// - On app launch/resume, check if brief generation is due
/// - If due but not yet generated, trigger immediate generation
/// - Show user notification that brief is being generated
///
/// This ensures users always get their weekly brief, even if
/// background execution was not possible.
class IOSBackgroundLimitations {
  /// Maximum background execution time on iOS (approximately).
  static const Duration maxBackgroundTime = Duration(seconds: 30);

  /// Recommended approach: check on app resume.
  static const String recommendation = '''
On iOS, background tasks may not execute reliably.
Check for missed briefs on app resume and generate if needed.
''';
}
