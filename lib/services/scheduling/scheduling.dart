/// Scheduling services for Boardroom Journal.
///
/// Provides background task scheduling for automatic weekly brief generation.
///
/// Key components:
/// - [BriefSchedulerService] - Manages scheduling of weekly briefs
/// - [BackgroundTaskHandler] - Handles background task execution
/// - [callbackDispatcher] - Top-level callback for workmanager
///
/// Platform Considerations:
/// - **Android:** Full background execution support via workmanager
/// - **iOS:** Limited background fetch, may need foreground fallback
///
/// Usage:
/// ```dart
/// // At app startup
/// final scheduler = BriefSchedulerService();
/// await scheduler.initialize(callbackDispatcher);
/// await scheduler.scheduleWeeklyBrief();
/// ```
library;

export 'background_task_handler.dart';
export 'brief_scheduler_service.dart';
