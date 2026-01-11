import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/scheduling/scheduling.dart';

// ==================
// Shared Preferences Provider
// ==================

/// Provider for SharedPreferences instance.
///
/// Must be overridden in the ProviderScope at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized before use. '
    'Override this provider in ProviderScope.',
  );
});

// ==================
// Brief Scheduler Service Provider
// ==================

/// Provider for the BriefSchedulerService.
///
/// Manages scheduling of weekly brief generation tasks.
final briefSchedulerServiceProvider = Provider<BriefSchedulerService>((ref) {
  final service = BriefSchedulerService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ==================
// Background Task Handler Provider
// ==================

/// Provider for the BackgroundTaskHandler.
///
/// Used for checking missed briefs and manual generation.
final backgroundTaskHandlerProvider = Provider<BackgroundTaskHandler>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BackgroundTaskHandler(prefs: prefs);
});

// ==================
// Scheduler State Providers
// ==================

/// Stream provider for scheduler state updates.
final briefSchedulerStateStreamProvider =
    StreamProvider<BriefSchedulerState>((ref) {
  final service = ref.watch(briefSchedulerServiceProvider);
  return service.stateStream;
});

/// Provider for current scheduler state.
final briefSchedulerStateProvider = Provider<BriefSchedulerState>((ref) {
  final service = ref.watch(briefSchedulerServiceProvider);
  return service.getState();
});

/// Provider for next scheduled brief time.
final nextScheduledBriefTimeProvider = Provider<DateTime?>((ref) {
  final state = ref.watch(briefSchedulerStateProvider);
  return state.nextScheduledTime;
});

/// Provider for last successful brief execution time.
final lastBriefExecutionTimeProvider = Provider<DateTime?>((ref) {
  final state = ref.watch(briefSchedulerStateProvider);
  return state.lastExecutionTime;
});

/// Provider for whether a brief is currently scheduled.
final isBriefScheduledProvider = Provider<bool>((ref) {
  final state = ref.watch(briefSchedulerStateProvider);
  return state.isScheduled;
});

// ==================
// Scheduler Action Notifier
// ==================

/// State for scheduler actions (loading states, errors).
class SchedulerActionState {
  final bool isLoading;
  final String? error;
  final DateTime? lastActionTime;

  const SchedulerActionState({
    this.isLoading = false,
    this.error,
    this.lastActionTime,
  });

  SchedulerActionState copyWith({
    bool? isLoading,
    String? error,
    DateTime? lastActionTime,
  }) {
    return SchedulerActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastActionTime: lastActionTime ?? this.lastActionTime,
    );
  }
}

/// Notifier for managing scheduler actions.
class SchedulerActionNotifier extends AutoDisposeNotifier<SchedulerActionState> {
  @override
  SchedulerActionState build() => const SchedulerActionState();

  /// Schedules weekly brief generation.
  Future<void> scheduleWeeklyBrief() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(briefSchedulerServiceProvider);
      await service.scheduleWeeklyBrief();
      state = state.copyWith(
        isLoading: false,
        lastActionTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to schedule brief: $e',
      );
    }
  }

  /// Cancels scheduled brief.
  Future<void> cancelScheduledBrief() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(briefSchedulerServiceProvider);
      await service.cancelScheduledBrief();
      state = state.copyWith(
        isLoading: false,
        lastActionTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to cancel scheduled brief: $e',
      );
    }
  }

  /// Triggers immediate brief generation.
  Future<void> generateNow() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(briefSchedulerServiceProvider);
      await service.executeNow();
      state = state.copyWith(
        isLoading: false,
        lastActionTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to trigger immediate generation: $e',
      );
    }
  }

  /// Reschedules the weekly brief (e.g., after timezone change).
  Future<void> reschedule() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(briefSchedulerServiceProvider);
      await service.reschedule();
      state = state.copyWith(
        isLoading: false,
        lastActionTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reschedule brief: $e',
      );
    }
  }

  /// Checks and reschedules if needed.
  Future<bool> checkAndReschedule() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = ref.read(briefSchedulerServiceProvider);
      final wasRescheduled = await service.checkAndReschedule();
      state = state.copyWith(
        isLoading: false,
        lastActionTime: DateTime.now(),
      );
      return wasRescheduled;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check schedule: $e',
      );
      return false;
    }
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for scheduler action notifier.
final schedulerActionProvider =
    NotifierProvider.autoDispose<SchedulerActionNotifier, SchedulerActionState>(
  SchedulerActionNotifier.new,
);

// ==================
// Missed Brief Detection
// ==================

/// Provider for checking if a brief generation was missed.
///
/// Useful for iOS where background tasks may not execute reliably.
final isBriefDueProvider = FutureProvider<bool>((ref) async {
  final handler = ref.watch(backgroundTaskHandlerProvider);
  return handler.isBriefDue();
});

/// Notifier for handling missed briefs.
class MissedBriefNotifier extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final handler = ref.watch(backgroundTaskHandlerProvider);
    return handler.isBriefDue();
  }

  /// Generates brief if it was missed.
  ///
  /// Returns true if generation was triggered.
  Future<bool> generateIfMissed() async {
    final isDue = state.valueOrNull ?? false;

    if (!isDue) {
      return false;
    }

    // Trigger immediate generation
    final service = ref.read(briefSchedulerServiceProvider);
    await service.executeNow();

    // Refresh state
    ref.invalidateSelf();

    return true;
  }
}

/// Provider for missed brief handling.
final missedBriefProvider =
    AsyncNotifierProvider.autoDispose<MissedBriefNotifier, bool>(
  MissedBriefNotifier.new,
);

// ==================
// Initialization Helper
// ==================

/// Initializes the brief scheduler service.
///
/// Call this at app startup after WidgetsFlutterBinding.ensureInitialized().
///
/// Example:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final prefs = await SharedPreferences.getInstance();
///   await initializeBriefScheduler();
///
///   runApp(
///     ProviderScope(
///       overrides: [
///         sharedPreferencesProvider.overrideWithValue(prefs),
///       ],
///       child: const MyApp(),
///     ),
///   );
/// }
/// ```
Future<void> initializeBriefScheduler() async {
  final service = BriefSchedulerService();
  await service.initialize(callbackDispatcher);
  await service.scheduleWeeklyBrief();
}
