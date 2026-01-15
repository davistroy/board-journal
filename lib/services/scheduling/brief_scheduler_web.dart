/// Dummy type for web platform (Workmanager not available).
typedef WorkmanagerType = Object;

/// Whether background scheduling is supported on this platform.
/// Web does not support background tasks.
const bool isSupported = false;

/// Creates a dummy workmanager (not used on web).
Object? createWorkmanager() => null;

/// Not available on web.
Future<void> initialize(
  Object workmanager,
  Function callbackDispatcher,
  bool isDebugMode,
) async {
  throw UnsupportedError('Background tasks not supported on web');
}

/// Not available on web.
Future<void> registerOneOffTask(
  Object workmanager,
  String uniqueName,
  String taskName,
  Duration initialDelay,
) async {
  throw UnsupportedError('Background tasks not supported on web');
}

/// Not available on web.
Future<void> cancelByUniqueName(Object workmanager, String uniqueName) async {
  throw UnsupportedError('Background tasks not supported on web');
}
