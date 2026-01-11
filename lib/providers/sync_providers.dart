import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/api.dart';
import '../services/sync/sync.dart';
import 'auth_providers.dart';
import 'database_provider.dart';
import 'scheduling_providers.dart';

// ==================
// Configuration Providers
// ==================

/// Provider for API configuration.
///
/// Defaults to development config. Override for staging/production.
final apiConfigProvider = Provider<ApiConfig>((ref) {
  // In a real app, this would be determined by build flavor or environment
  return ApiConfig.development();
});

// ==================
// Service Providers
// ==================

// Note: sharedPreferencesProvider is imported from scheduling_providers.dart

/// Provider for the API client.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(apiConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final authService = ref.watch(authServiceProvider);

  final client = ApiClient(
    config: config,
    tokenStorage: tokenStorage,
    authService: authService,
  );

  ref.onDispose(() {
    client.close();
  });

  return client;
});

/// Provider for the sync queue.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncQueue(prefs);
});

/// Provider for the conflict resolver.
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  final resolver = ConflictResolver(
    onConflictNotification: (_) {
      // This would typically trigger a UI notification
      // The message is also available via the conflict stream
    },
  );

  ref.onDispose(() {
    resolver.dispose();
  });

  return resolver;
});

/// Provider for the sync service.
final syncServiceProvider = Provider<SyncService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final config = ref.watch(apiConfigProvider);
  final database = ref.watch(databaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final conflictResolver = ref.watch(conflictResolverProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  final service = SyncService(
    apiClient: apiClient,
    config: config,
    database: database,
    queue: queue,
    conflictResolver: conflictResolver,
    prefs: prefs,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ==================
// Sync State Provider
// ==================

/// Notifier for managing sync state.
class SyncNotifier extends StateNotifier<SyncStatus> {
  final SyncService _syncService;
  StreamSubscription<SyncStatus>? _statusSubscription;

  SyncNotifier(this._syncService) : super(SyncStatus.initial()) {
    _initialize();
  }

  /// Initializes the notifier and subscribes to sync status.
  void _initialize() {
    // Subscribe to sync service status updates
    _statusSubscription = _syncService.statusStream.listen((status) {
      state = status;
    });

    // Initialize the sync service
    _syncService.initialize();
  }

  /// Triggers a full sync.
  Future<void> syncAll() async {
    await _syncService.syncAll();
  }

  /// Triggers an incremental sync.
  Future<void> syncChanges() async {
    await _syncService.syncChanges();
  }

  /// Triggers a full download.
  Future<void> fullDownload() async {
    await _syncService.fullDownload();
  }

  /// Notifies that a local change was made.
  void notifyLocalChange() {
    _syncService.notifyLocalChange();
  }

  /// Notifies that the app resumed.
  void onAppResumed() {
    _syncService.onAppResumed();
  }

  /// Notifies that the app paused.
  void onAppPaused() {
    _syncService.onAppPaused();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for sync state notifier.
final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return SyncNotifier(syncService);
});

// ==================
// Derived Providers
// ==================

/// Provider for whether sync is currently in progress.
final isSyncingProvider = Provider<bool>((ref) {
  final status = ref.watch(syncNotifierProvider);
  return status.isSyncing;
});

/// Provider for the current sync state.
final syncStateProvider = Provider<SyncState>((ref) {
  final status = ref.watch(syncNotifierProvider);
  return status.state;
});

/// Provider for the number of pending changes.
final pendingChangesCountProvider = Provider<int>((ref) {
  final status = ref.watch(syncNotifierProvider);
  return status.pendingCount;
});

/// Provider for whether there are pending changes.
final hasPendingChangesProvider = Provider<bool>((ref) {
  final count = ref.watch(pendingChangesCountProvider);
  return count > 0;
});

/// Provider for the last sync time.
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  final status = ref.watch(syncNotifierProvider);
  return status.lastSyncTime;
});

/// Provider for sync error message.
final syncErrorProvider = Provider<String?>((ref) {
  final status = ref.watch(syncNotifierProvider);
  return status.errorMessage;
});

/// Provider for whether the app is offline.
final isOfflineProvider = Provider<bool>((ref) {
  final state = ref.watch(syncStateProvider);
  return state == SyncState.offline;
});

// ==================
// Connectivity Provider
// ==================

/// Provider for connectivity status stream.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider for current connectivity status.
final connectivityProvider = FutureProvider<List<ConnectivityResult>>((ref) async {
  return Connectivity().checkConnectivity();
});

/// Provider for whether there is network connectivity.
final hasConnectivityProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);

  return connectivityAsync.maybeWhen(
    data: (result) => result.isNotEmpty && !result.contains(ConnectivityResult.none),
    orElse: () => true, // Assume connected by default
  );
});

// ==================
// Conflict Providers
// ==================

/// Provider for conflict stream.
final conflictStreamProvider = StreamProvider<SyncConflict>((ref) {
  final resolver = ref.watch(conflictResolverProvider);
  return resolver.conflictStream;
});

/// Provider for conflict log.
final conflictLogProvider = Provider<List<ConflictLogEntry>>((ref) {
  final resolver = ref.watch(conflictResolverProvider);
  return resolver.getConflictLog();
});

// ==================
// Action Providers
// ==================

/// Provider for triggering a sync action.
///
/// Usage:
/// ```dart
/// ref.read(triggerSyncProvider)();
/// ```
final triggerSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(syncNotifierProvider.notifier).syncAll();
  };
});

/// Provider for triggering a pull-to-refresh sync.
final pullToRefreshProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(syncNotifierProvider.notifier).syncAll();
  };
});

