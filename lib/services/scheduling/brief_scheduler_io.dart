import 'package:workmanager/workmanager.dart';

/// Type alias for Workmanager on mobile platforms.
typedef WorkmanagerType = Workmanager;

/// Whether background scheduling is supported on this platform.
const bool isSupported = true;

/// Creates a Workmanager instance.
Workmanager createWorkmanager() => Workmanager();

/// Initializes the workmanager.
Future<void> initialize(
  Workmanager workmanager,
  Function callbackDispatcher,
  bool isDebugMode,
) async {
  await workmanager.initialize(
    callbackDispatcher,
    isInDebugMode: isDebugMode,
  );
}

/// Registers a one-off task.
Future<void> registerOneOffTask(
  Workmanager workmanager,
  String uniqueName,
  String taskName,
  Duration initialDelay,
) async {
  await workmanager.registerOneOffTask(
    uniqueName,
    taskName,
    initialDelay: initialDelay,
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 1),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Cancels a task by unique name.
Future<void> cancelByUniqueName(Workmanager workmanager, String uniqueName) async {
  await workmanager.cancelByUniqueName(uniqueName);
}
