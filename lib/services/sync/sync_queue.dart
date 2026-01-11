import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Priority levels for sync queue items.
///
/// Per requirements - priority order:
/// 1. Auth refresh
/// 2. Transcription requests
/// 3. Signal extraction requests
/// 4. Local edits (entries, briefs)
/// 5. Server changes download
enum SyncPriority {
  /// Highest priority: auth refresh.
  authRefresh(1),

  /// High priority: transcription requests.
  transcription(2),

  /// High priority: signal extraction.
  signalExtraction(3),

  /// Normal priority: local edits.
  localEdits(4),

  /// Low priority: server changes download.
  serverDownload(5);

  final int value;
  const SyncPriority(this.value);
}

/// Type of sync operation.
enum SyncOperationType {
  /// Create a new record.
  create,

  /// Update an existing record.
  update,

  /// Delete a record.
  delete,

  /// Full sync download.
  fullDownload,

  /// Incremental pull.
  pull,

  /// AI processing request.
  aiProcess,
}

/// Type of entity being synced.
enum SyncEntityType {
  dailyEntry,
  weeklyBrief,
  problem,
  boardMember,
  bet,
  evidenceItem,
  governanceSession,
  portfolioHealth,
  portfolioVersion,
}

/// A queued sync operation.
///
/// Represents a local change waiting to be synced to the server.
class SyncQueueItem {
  /// Unique identifier for this queue item.
  final String id;

  /// Entity ID being synced.
  final String entityId;

  /// Type of entity.
  final SyncEntityType entityType;

  /// Type of operation.
  final SyncOperationType operationType;

  /// Priority of this operation.
  final SyncPriority priority;

  /// JSON payload for the operation.
  final Map<String, dynamic>? payload;

  /// When this item was queued.
  final DateTime queuedAt;

  /// Number of sync attempts.
  final int attempts;

  /// Last error message if sync failed.
  final String? lastError;

  /// When the last sync attempt was made.
  final DateTime? lastAttemptAt;

  const SyncQueueItem({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.operationType,
    required this.priority,
    this.payload,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
    this.lastAttemptAt,
  });

  /// Creates a copy with updated fields.
  SyncQueueItem copyWith({
    int? attempts,
    String? lastError,
    DateTime? lastAttemptAt,
  }) {
    return SyncQueueItem(
      id: id,
      entityId: entityId,
      entityType: entityType,
      operationType: operationType,
      priority: priority,
      payload: payload,
      queuedAt: queuedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  /// Serializes to JSON for persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityId': entityId,
      'entityType': entityType.name,
      'operationType': operationType.name,
      'priority': priority.value,
      'payload': payload,
      'queuedAt': queuedAt.toIso8601String(),
      'attempts': attempts,
      'lastError': lastError,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    };
  }

  /// Deserializes from JSON.
  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String,
      entityId: json['entityId'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == json['entityType'],
      ),
      operationType: SyncOperationType.values.firstWhere(
        (e) => e.name == json['operationType'],
      ),
      priority: SyncPriority.values.firstWhere(
        (e) => e.value == json['priority'],
      ),
      payload: json['payload'] as Map<String, dynamic>?,
      queuedAt: DateTime.parse(json['queuedAt'] as String),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
    );
  }
}

/// Manages the offline sync queue.
///
/// Per requirements:
/// - Queue changes when offline
/// - Persist queue to survive app restart
/// - Priority ordering
/// - Process queue when connectivity returns
/// - Never delete local data on sync failure
class SyncQueue {
  static const String _queueKey = 'sync_queue';
  static const int _maxAttempts = 5;

  final SharedPreferences _prefs;

  /// In-memory queue (loaded from storage).
  List<SyncQueueItem> _queue = [];

  /// Creates a SyncQueue instance.
  SyncQueue(this._prefs) {
    _loadQueue();
  }

  /// Loads the queue from persistent storage.
  void _loadQueue() {
    final queueJson = _prefs.getString(_queueKey);
    if (queueJson != null) {
      try {
        final List<dynamic> items = jsonDecode(queueJson);
        _queue = items
            .map((item) => SyncQueueItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _sortQueue();
      } catch (e) {
        // Reset queue on parse error
        _queue = [];
      }
    }
  }

  /// Persists the queue to storage.
  Future<void> _saveQueue() async {
    final queueJson = jsonEncode(_queue.map((item) => item.toJson()).toList());
    await _prefs.setString(_queueKey, queueJson);
  }

  /// Sorts the queue by priority and then by queued time.
  void _sortQueue() {
    _queue.sort((a, b) {
      final priorityCompare = a.priority.value.compareTo(b.priority.value);
      if (priorityCompare != 0) return priorityCompare;
      return a.queuedAt.compareTo(b.queuedAt);
    });
  }

  /// Adds an item to the queue.
  Future<void> enqueue(SyncQueueItem item) async {
    // Check for existing item with same entity ID and type
    final existingIndex = _queue.indexWhere(
      (i) => i.entityId == item.entityId && i.entityType == item.entityType,
    );

    if (existingIndex >= 0) {
      // Replace existing item (newer change supersedes older)
      _queue[existingIndex] = item;
    } else {
      _queue.add(item);
    }

    _sortQueue();
    await _saveQueue();
  }

  /// Removes an item from the queue by ID.
  Future<void> dequeue(String itemId) async {
    _queue.removeWhere((item) => item.id == itemId);
    await _saveQueue();
  }

  /// Gets the next item to process.
  ///
  /// Returns null if queue is empty or all items have exceeded max attempts.
  SyncQueueItem? getNext() {
    for (final item in _queue) {
      if (item.attempts < _maxAttempts) {
        return item;
      }
    }
    return null;
  }

  /// Gets all pending items.
  List<SyncQueueItem> getAll() {
    return List.unmodifiable(_queue);
  }

  /// Gets items by entity type.
  List<SyncQueueItem> getByEntityType(SyncEntityType type) {
    return _queue.where((item) => item.entityType == type).toList();
  }

  /// Gets the count of pending items.
  int get pendingCount => _queue.where((i) => i.attempts < _maxAttempts).length;

  /// Whether the queue is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Whether there are items ready to sync.
  bool get hasItemsToSync => pendingCount > 0;

  /// Marks an item as failed and increments attempt count.
  Future<void> markFailed(String itemId, String error) async {
    final index = _queue.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _queue[index] = _queue[index].copyWith(
        attempts: _queue[index].attempts + 1,
        lastError: error,
        lastAttemptAt: DateTime.now(),
      );
      await _saveQueue();
    }
  }

  /// Clears all items from the queue.
  ///
  /// Use with caution - typically only after a full sync.
  Future<void> clear() async {
    _queue.clear();
    await _saveQueue();
  }

  /// Clears items that have exceeded max attempts.
  ///
  /// Returns the cleared items for logging/notification.
  Future<List<SyncQueueItem>> clearFailedItems() async {
    final failed = _queue.where((i) => i.attempts >= _maxAttempts).toList();
    _queue.removeWhere((i) => i.attempts >= _maxAttempts);
    await _saveQueue();
    return failed;
  }

  /// Gets items that have failed and exceeded max attempts.
  List<SyncQueueItem> getFailedItems() {
    return _queue.where((i) => i.attempts >= _maxAttempts).toList();
  }

  /// Creates a queue item for a daily entry change.
  static SyncQueueItem createEntryItem({
    required String id,
    required String entityId,
    required SyncOperationType operationType,
    Map<String, dynamic>? payload,
  }) {
    return SyncQueueItem(
      id: id,
      entityId: entityId,
      entityType: SyncEntityType.dailyEntry,
      operationType: operationType,
      priority: SyncPriority.localEdits,
      payload: payload,
      queuedAt: DateTime.now(),
    );
  }

  /// Creates a queue item for a weekly brief change.
  static SyncQueueItem createBriefItem({
    required String id,
    required String entityId,
    required SyncOperationType operationType,
    Map<String, dynamic>? payload,
  }) {
    return SyncQueueItem(
      id: id,
      entityId: entityId,
      entityType: SyncEntityType.weeklyBrief,
      operationType: operationType,
      priority: SyncPriority.localEdits,
      payload: payload,
      queuedAt: DateTime.now(),
    );
  }

  /// Creates a queue item for a transcription request.
  static SyncQueueItem createTranscriptionItem({
    required String id,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: id,
      entityId: entityId,
      entityType: SyncEntityType.dailyEntry,
      operationType: SyncOperationType.aiProcess,
      priority: SyncPriority.transcription,
      payload: payload,
      queuedAt: DateTime.now(),
    );
  }

  /// Creates a queue item for signal extraction.
  static SyncQueueItem createSignalExtractionItem({
    required String id,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    return SyncQueueItem(
      id: id,
      entityId: entityId,
      entityType: SyncEntityType.dailyEntry,
      operationType: SyncOperationType.aiProcess,
      priority: SyncPriority.signalExtraction,
      payload: payload,
      queuedAt: DateTime.now(),
    );
  }
}
