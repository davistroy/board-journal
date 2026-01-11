import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/database.dart';
import '../../data/repositories/base_repository.dart';
import '../api/api.dart';
import 'conflict_resolver.dart';
import 'sync_queue.dart';

/// Sync status for the application.
enum SyncState {
  /// No sync in progress.
  idle,

  /// Sync is in progress.
  syncing,

  /// Sync failed with an error.
  error,

  /// No network connectivity.
  offline,

  /// Local changes waiting to sync.
  pendingChanges,
}

/// Extended sync state with additional information.
class SyncStatus {
  /// Current sync state.
  final SyncState state;

  /// Error message if state is error.
  final String? errorMessage;

  /// Number of pending changes.
  final int pendingCount;

  /// Last successful sync time.
  final DateTime? lastSyncTime;

  /// Whether a sync is currently running.
  final bool isSyncing;

  const SyncStatus({
    required this.state,
    this.errorMessage,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  /// Initial sync status.
  factory SyncStatus.initial() {
    return const SyncStatus(state: SyncState.idle);
  }

  /// Creates a copy with updated fields.
  SyncStatus copyWith({
    SyncState? state,
    String? errorMessage,
    int? pendingCount,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return SyncStatus(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Orchestrates sync operations between local database and server.
///
/// Per PRD Section 3B.2:
/// - Local-first SQLite (existing)
/// - Sync triggers:
///   - App launch
///   - Pull-to-refresh
///   - After local changes (debounced 2 seconds)
///   - Every 5 minutes while foregrounded
/// - Last-write-wins conflict resolution
/// - User notification on conflict
class SyncService {
  static const String _lastSyncTimeKey = 'sync_last_sync_time';

  final ApiClient _apiClient;
  final ApiConfig _config;
  final AppDatabase _database;
  final SyncQueue _queue;
  final ConflictResolver _conflictResolver;
  final SharedPreferences _prefs;
  final Connectivity _connectivity;

  /// Stream controller for sync status updates.
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  /// Current sync status.
  SyncStatus _status = SyncStatus.initial();

  /// Timer for periodic sync.
  Timer? _periodicSyncTimer;

  /// Timer for debounced sync after local changes.
  Timer? _debounceTimer;

  /// Subscription to connectivity changes.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Whether the app is currently in the foreground.
  bool _isForegrounded = true;

  /// Creates a SyncService instance.
  SyncService({
    required ApiClient apiClient,
    required ApiConfig config,
    required AppDatabase database,
    required SyncQueue queue,
    required ConflictResolver conflictResolver,
    required SharedPreferences prefs,
    Connectivity? connectivity,
  })  : _apiClient = apiClient,
        _config = config,
        _database = database,
        _queue = queue,
        _conflictResolver = conflictResolver,
        _prefs = prefs,
        _connectivity = connectivity ?? Connectivity();

  /// Stream of sync status updates.
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status.
  SyncStatus get currentStatus => _status;

  /// Initializes the sync service.
  ///
  /// Call this on app launch.
  Future<void> initialize() async {
    // Load last sync time
    final lastSyncTimeStr = _prefs.getString(_lastSyncTimeKey);
    if (lastSyncTimeStr != null) {
      _status = _status.copyWith(
        lastSyncTime: DateTime.parse(lastSyncTimeStr),
      );
    }

    // Update pending count
    _status = _status.copyWith(
      pendingCount: _queue.pendingCount,
      state: _queue.hasItemsToSync ? SyncState.pendingChanges : SyncState.idle,
    );
    _emitStatus();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!_hasConnectivity(connectivityResult)) {
      _status = _status.copyWith(state: SyncState.offline);
      _emitStatus();
    }

    // Start periodic sync timer
    _startPeriodicSync();

    // Trigger initial sync
    await syncAll();
  }

  /// Handles connectivity changes.
  void _onConnectivityChanged(List<ConnectivityResult> result) {
    final hasNetwork = _hasConnectivity(result);

    if (hasNetwork) {
      // Connectivity restored - process queue
      if (_status.state == SyncState.offline) {
        _status = _status.copyWith(
          state: _queue.hasItemsToSync ? SyncState.pendingChanges : SyncState.idle,
        );
        _emitStatus();

        // Sync queued changes
        syncAll();
      }
    } else {
      // Lost connectivity
      _status = _status.copyWith(state: SyncState.offline);
      _emitStatus();
    }
  }

  /// Checks if we have connectivity.
  bool _hasConnectivity(List<ConnectivityResult> result) {
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  /// Starts the periodic sync timer.
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(
      _config.periodicSyncInterval,
      (_) {
        if (_isForegrounded) {
          syncAll();
        }
      },
    );
  }

  /// Notifies the service that a local change was made.
  ///
  /// Triggers a debounced sync after 2 seconds.
  void notifyLocalChange() {
    _status = _status.copyWith(
      pendingCount: _queue.pendingCount,
      state: SyncState.pendingChanges,
    );
    _emitStatus();

    // Debounce sync trigger
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.syncDebounce, () {
      syncChanges();
    });
  }

  /// Full sync operation.
  ///
  /// Pushes local changes and pulls server changes.
  Future<void> syncAll() async {
    if (_status.state == SyncState.offline) {
      return; // Can't sync offline
    }

    if (_status.isSyncing) {
      return; // Already syncing
    }

    _status = _status.copyWith(
      state: SyncState.syncing,
      isSyncing: true,
    );
    _emitStatus();

    try {
      // Push local changes first
      await _pushPendingChanges();

      // Then pull server changes
      await _pullServerChanges();

      // Update status
      final now = DateTime.now();
      await _setLastSyncTime(now);

      _status = _status.copyWith(
        state: SyncState.idle,
        isSyncing: false,
        lastSyncTime: now,
        pendingCount: _queue.pendingCount,
        errorMessage: null,
      );
      _emitStatus();
    } catch (e) {
      _status = _status.copyWith(
        state: SyncState.error,
        isSyncing: false,
        errorMessage: e.toString(),
      );
      _emitStatus();
    }
  }

  /// Incremental sync since last timestamp.
  Future<void> syncChanges() async {
    if (_status.state == SyncState.offline) {
      return;
    }

    if (_status.isSyncing) {
      return;
    }

    _status = _status.copyWith(
      state: SyncState.syncing,
      isSyncing: true,
    );
    _emitStatus();

    try {
      await _pushPendingChanges();

      final now = DateTime.now();
      await _setLastSyncTime(now);

      _status = _status.copyWith(
        state: _queue.hasItemsToSync ? SyncState.pendingChanges : SyncState.idle,
        isSyncing: false,
        lastSyncTime: now,
        pendingCount: _queue.pendingCount,
        errorMessage: null,
      );
      _emitStatus();
    } catch (e) {
      _status = _status.copyWith(
        state: SyncState.error,
        isSyncing: false,
        errorMessage: e.toString(),
      );
      _emitStatus();
    }
  }

  /// Pushes local changes to the server.
  Future<void> _pushPendingChanges() async {
    while (_queue.hasItemsToSync) {
      final item = _queue.getNext();
      if (item == null) break;

      try {
        final success = await _pushSingleChange(item);
        if (success) {
          await _queue.dequeue(item.id);
        }
      } catch (e) {
        await _queue.markFailed(item.id, e.toString());
        // Continue with next item, don't stop on failure
      }
    }
  }

  /// Pushes a single change to the server.
  Future<bool> _pushSingleChange(SyncQueueItem item) async {
    final endpoint = _getEndpointForEntity(item.entityType, item.entityId);

    ApiResult<Map<String, dynamic>> result;

    switch (item.operationType) {
      case SyncOperationType.create:
        result = await _apiClient.post(endpoint, body: item.payload);
        break;
      case SyncOperationType.update:
        result = await _apiClient.put(endpoint, body: item.payload);
        break;
      case SyncOperationType.delete:
        result = await _apiClient.delete(endpoint);
        break;
      default:
        return false; // Skip non-push operations
    }

    if (result.isConflict) {
      // Handle conflict
      await _handleConflict(item, result.data);
      return true; // Consider resolved
    }

    if (!result.success) {
      if (result.isNetworkError) {
        // Network error - will retry
        return false;
      }
      throw Exception(result.error);
    }

    // Update local sync status
    await _updateLocalSyncStatus(item.entityType, item.entityId, result.data);

    return true;
  }

  /// Handles a sync conflict.
  Future<void> _handleConflict(
    SyncQueueItem item,
    Map<String, dynamic>? serverResponse,
  ) async {
    if (serverResponse == null) return;

    // Fetch the latest server version
    final endpoint = _getEndpointForEntity(item.entityType, item.entityId);
    final serverResult = await _apiClient.get(endpoint);

    if (!serverResult.success || serverResult.data == null) {
      return;
    }

    // Create conflict
    final conflict = ConflictResolver.createConflict(
      entityId: item.entityId,
      entityType: item.entityType,
      localData: item.payload ?? {},
      serverData: serverResult.data!,
    );

    // Resolve conflict
    final resolution = _conflictResolver.resolve(conflict);

    // Apply the winning data
    if (resolution.localWon) {
      // Push local data again with correct version
      final updatedPayload = {
        ...item.payload ?? {},
        'serverVersion': conflict.serverVersion,
      };
      await _apiClient.put(endpoint, body: updatedPayload);
    } else {
      // Apply server data locally
      await _applyServerDataLocally(item.entityType, item.entityId, resolution.winningData);
    }
  }

  /// Pulls changes from the server.
  Future<void> _pullServerChanges() async {
    final since = _status.lastSyncTime ?? DateTime.fromMillisecondsSinceEpoch(0);

    final result = await _apiClient.get(
      ApiEndpoints.syncPull,
      queryParams: {'since': since.toIso8601String()},
    );

    if (!result.success || result.data == null) {
      if (!result.isNetworkError) {
        throw Exception(result.error ?? 'Failed to pull changes');
      }
      return;
    }

    final changes = result.data!['changes'] as List<dynamic>? ?? [];

    for (final change in changes) {
      if (change is Map<String, dynamic>) {
        await _applyServerChange(change);
      }
    }
  }

  /// Applies a server change locally.
  Future<void> _applyServerChange(Map<String, dynamic> change) async {
    final entityType = _parseEntityType(change['entityType'] as String?);
    if (entityType == null) return;

    final entityId = change['entityId'] as String?;
    if (entityId == null) return;

    final data = change['data'] as Map<String, dynamic>?;
    if (data == null) return;

    await _applyServerDataLocally(entityType, entityId, data);
  }

  /// Applies server data to the local database.
  Future<void> _applyServerDataLocally(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    // This would be implemented based on your database structure
    // For now, we'll just update the sync status
    switch (entityType) {
      case SyncEntityType.dailyEntry:
        await _applyDailyEntryChange(entityId, data);
        break;
      case SyncEntityType.weeklyBrief:
        await _applyWeeklyBriefChange(entityId, data);
        break;
      default:
        // Other entity types would be handled here
        break;
    }
  }

  /// Applies a daily entry change from the server.
  Future<void> _applyDailyEntryChange(
    String entityId,
    Map<String, dynamic> data,
  ) async {
    // Check if entry exists locally
    final existing = await (_database.select(_database.dailyEntries)
          ..where((e) => e.id.equals(entityId)))
        .getSingleOrNull();

    if (existing != null) {
      // Check for conflict
      if (data['serverVersion'] != null &&
          data['serverVersion'] != existing.serverVersion) {
        // Conflict detected - would need to resolve
        // For now, server wins if local is already synced
        if (existing.syncStatus == 'synced') {
          await _updateDailyEntry(entityId, data);
        }
      } else {
        await _updateDailyEntry(entityId, data);
      }
    } else {
      // Insert new entry from server
      await _insertDailyEntry(entityId, data);
    }
  }

  /// Updates an existing daily entry.
  Future<void> _updateDailyEntry(String id, Map<String, dynamic> data) async {
    await (_database.update(_database.dailyEntries)
          ..where((e) => e.id.equals(id)))
        .write(
      DailyEntriesCompanion(
        transcriptEdited: data['transcriptEdited'] != null
            ? Value(data['transcriptEdited'] as String)
            : const Value.absent(),
        extractedSignalsJson: data['extractedSignalsJson'] != null
            ? Value(data['extractedSignalsJson'] as String)
            : const Value.absent(),
        updatedAtUtc: Value(DateTime.now().toUtc()),
        syncStatus: const Value('synced'),
        serverVersion: data['serverVersion'] != null
            ? Value(data['serverVersion'] as int)
            : const Value.absent(),
      ),
    );
  }

  /// Inserts a new daily entry from server.
  Future<void> _insertDailyEntry(String id, Map<String, dynamic> data) async {
    await _database.into(_database.dailyEntries).insert(
          DailyEntriesCompanion.insert(
            id: id,
            transcriptRaw: data['transcriptRaw'] as String? ?? '',
            transcriptEdited: data['transcriptEdited'] as String? ?? '',
            entryType: data['entryType'] as String? ?? 'text',
            createdAtUtc: data['createdAtUtc'] != null
                ? DateTime.parse(data['createdAtUtc'] as String)
                : DateTime.now().toUtc(),
            createdAtTimezone: data['createdAtTimezone'] as String? ?? 'UTC',
            updatedAtUtc: DateTime.now().toUtc(),
            syncStatus: const Value('synced'),
            serverVersion: Value(data['serverVersion'] as int? ?? 0),
          ),
        );
  }

  /// Applies a weekly brief change from the server.
  Future<void> _applyWeeklyBriefChange(
    String entityId,
    Map<String, dynamic> data,
  ) async {
    // Similar implementation to daily entries
    // Would check for existing, handle conflicts, and update/insert
  }

  /// Updates local sync status after successful push.
  Future<void> _updateLocalSyncStatus(
    SyncEntityType entityType,
    String entityId,
    Map<String, dynamic>? serverResponse,
  ) async {
    final serverVersion = serverResponse?['serverVersion'] as int?;

    switch (entityType) {
      case SyncEntityType.dailyEntry:
        await (_database.update(_database.dailyEntries)
              ..where((e) => e.id.equals(entityId)))
            .write(
          DailyEntriesCompanion(
            syncStatus: const Value('synced'),
            serverVersion:
                serverVersion != null ? Value(serverVersion) : const Value.absent(),
          ),
        );
        break;
      case SyncEntityType.weeklyBrief:
        await (_database.update(_database.weeklyBriefs)
              ..where((e) => e.id.equals(entityId)))
            .write(
          WeeklyBriefsCompanion(
            syncStatus: const Value('synced'),
            serverVersion:
                serverVersion != null ? Value(serverVersion) : const Value.absent(),
          ),
        );
        break;
      default:
        // Other entity types
        break;
    }
  }

  /// Gets the API endpoint for an entity.
  String _getEndpointForEntity(SyncEntityType type, String id) {
    switch (type) {
      case SyncEntityType.dailyEntry:
        return ApiEndpoints.entryById(id);
      case SyncEntityType.weeklyBrief:
        return ApiEndpoints.briefById(id);
      case SyncEntityType.problem:
        return ApiEndpoints.problemById(id);
      case SyncEntityType.boardMember:
        return ApiEndpoints.boardMemberById(id);
      case SyncEntityType.bet:
        return ApiEndpoints.betById(id);
      default:
        throw ArgumentError('Unsupported entity type: $type');
    }
  }

  /// Parses entity type from string.
  SyncEntityType? _parseEntityType(String? type) {
    if (type == null) return null;
    try {
      return SyncEntityType.values.firstWhere((e) => e.name == type);
    } catch (_) {
      return null;
    }
  }

  /// Full download of all data.
  ///
  /// Used for initial sync or recovery.
  Future<void> fullDownload() async {
    if (_status.state == SyncState.offline) {
      return;
    }

    _status = _status.copyWith(
      state: SyncState.syncing,
      isSyncing: true,
    );
    _emitStatus();

    try {
      final result = await _apiClient.get(ApiEndpoints.syncFull);

      if (!result.success || result.data == null) {
        throw Exception(result.error ?? 'Full download failed');
      }

      // Process all data from server
      final data = result.data!;

      // Apply entries
      final entries = data['entries'] as List<dynamic>? ?? [];
      for (final entry in entries) {
        if (entry is Map<String, dynamic>) {
          final id = entry['id'] as String?;
          if (id != null) {
            await _applyDailyEntryChange(id, entry);
          }
        }
      }

      // Apply briefs
      final briefs = data['briefs'] as List<dynamic>? ?? [];
      for (final brief in briefs) {
        if (brief is Map<String, dynamic>) {
          final id = brief['id'] as String?;
          if (id != null) {
            await _applyWeeklyBriefChange(id, brief);
          }
        }
      }

      // Additional entity types would be processed here

      final now = DateTime.now();
      await _setLastSyncTime(now);

      _status = _status.copyWith(
        state: SyncState.idle,
        isSyncing: false,
        lastSyncTime: now,
        errorMessage: null,
      );
      _emitStatus();
    } catch (e) {
      _status = _status.copyWith(
        state: SyncState.error,
        isSyncing: false,
        errorMessage: e.toString(),
      );
      _emitStatus();
    }
  }

  /// Gets the last successful sync time.
  DateTime? getLastSyncTime() {
    return _status.lastSyncTime;
  }

  /// Sets the last successful sync time.
  Future<void> _setLastSyncTime(DateTime time) async {
    await _prefs.setString(_lastSyncTimeKey, time.toIso8601String());
  }

  /// Notifies the service that the app entered the foreground.
  void onAppResumed() {
    _isForegrounded = true;
    _startPeriodicSync();
    syncAll(); // Sync when returning to foreground
  }

  /// Notifies the service that the app entered the background.
  void onAppPaused() {
    _isForegrounded = false;
    _periodicSyncTimer?.cancel();
  }

  /// Emits the current status to listeners.
  void _emitStatus() {
    _statusController.add(_status);
  }

  /// Disposes resources.
  void dispose() {
    _periodicSyncTimer?.cancel();
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
    _conflictResolver.dispose();
  }
}
