import 'dart:async';

import 'sync_queue.dart';

/// Represents a sync conflict between local and server versions.
class SyncConflict {
  /// Entity ID with the conflict.
  final String entityId;

  /// Type of entity.
  final SyncEntityType entityType;

  /// Local version of the data.
  final Map<String, dynamic> localData;

  /// Server version of the data.
  final Map<String, dynamic> serverData;

  /// Local server version number.
  final int localVersion;

  /// Server's current version number.
  final int serverVersion;

  /// Local updated timestamp.
  final DateTime localUpdatedAt;

  /// Server updated timestamp.
  final DateTime serverUpdatedAt;

  const SyncConflict({
    required this.entityId,
    required this.entityType,
    required this.localData,
    required this.serverData,
    required this.localVersion,
    required this.serverVersion,
    required this.localUpdatedAt,
    required this.serverUpdatedAt,
  });

  /// Determines the winner based on last-write-wins strategy.
  ///
  /// Returns true if local wins, false if server wins.
  bool get localWins => localUpdatedAt.isAfter(serverUpdatedAt);

  /// Gets the friendly entity type name for notifications.
  String get entityTypeName {
    switch (entityType) {
      case SyncEntityType.dailyEntry:
        return 'entry';
      case SyncEntityType.weeklyBrief:
        return 'brief';
      case SyncEntityType.problem:
        return 'problem';
      case SyncEntityType.boardMember:
        return 'board member';
      case SyncEntityType.bet:
        return 'bet';
      case SyncEntityType.evidenceItem:
        return 'evidence';
      case SyncEntityType.governanceSession:
        return 'session';
      case SyncEntityType.portfolioHealth:
        return 'portfolio health';
      case SyncEntityType.portfolioVersion:
        return 'portfolio version';
    }
  }
}

/// Result of conflict resolution.
class ConflictResolutionResult {
  /// The winning data.
  final Map<String, dynamic> winningData;

  /// The losing data (stored for recovery).
  final Map<String, dynamic> losingData;

  /// Whether the local version won.
  final bool localWon;

  /// User-friendly notification message.
  final String notificationMessage;

  const ConflictResolutionResult({
    required this.winningData,
    required this.losingData,
    required this.localWon,
    required this.notificationMessage,
  });
}

/// Logged conflict for recovery purposes.
class ConflictLogEntry {
  /// Unique log entry ID.
  final String id;

  /// Entity ID.
  final String entityId;

  /// Entity type.
  final SyncEntityType entityType;

  /// The data that was overwritten.
  final Map<String, dynamic> overwrittenData;

  /// The winning data.
  final Map<String, dynamic> winningData;

  /// Whether local or server won.
  final bool localWon;

  /// When the conflict was resolved.
  final DateTime resolvedAt;

  const ConflictLogEntry({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.overwrittenData,
    required this.winningData,
    required this.localWon,
    required this.resolvedAt,
  });

  /// Serializes to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityId': entityId,
      'entityType': entityType.name,
      'overwrittenData': overwrittenData,
      'winningData': winningData,
      'localWon': localWon,
      'resolvedAt': resolvedAt.toIso8601String(),
    };
  }

  /// Deserializes from JSON.
  factory ConflictLogEntry.fromJson(Map<String, dynamic> json) {
    return ConflictLogEntry(
      id: json['id'] as String,
      entityId: json['entityId'] as String,
      entityType: SyncEntityType.values.firstWhere(
        (e) => e.name == json['entityType'],
      ),
      overwrittenData: json['overwrittenData'] as Map<String, dynamic>,
      winningData: json['winningData'] as Map<String, dynamic>,
      localWon: json['localWon'] as bool,
      resolvedAt: DateTime.parse(json['resolvedAt'] as String),
    );
  }
}

/// Callback for conflict notifications.
typedef ConflictNotificationCallback = void Function(String message);

/// Resolves sync conflicts using last-write-wins strategy.
///
/// Per PRD Section 3B.2:
/// - Compare serverVersion on push
/// - If mismatch, fetch latest and compare timestamps
/// - Last-write-wins with notification
/// - Log overwritten version for recovery
///
/// Notification message format:
/// "This [entry/brief] was also edited on another device. Showing most recent version."
class ConflictResolver {
  /// Callback for conflict notifications.
  final ConflictNotificationCallback? onConflictNotification;

  /// In-memory conflict log (would typically be persisted).
  final List<ConflictLogEntry> _conflictLog = [];

  /// Stream controller for conflict events.
  final StreamController<SyncConflict> _conflictStreamController =
      StreamController<SyncConflict>.broadcast();

  /// Stream of conflicts for UI observation.
  Stream<SyncConflict> get conflictStream => _conflictStreamController.stream;

  /// Creates a ConflictResolver instance.
  ConflictResolver({this.onConflictNotification});

  /// Resolves a conflict using last-write-wins strategy.
  ///
  /// Returns the resolution result with winning/losing data and notification.
  ConflictResolutionResult resolve(SyncConflict conflict) {
    final localWins = conflict.localWins;

    final winningData = localWins ? conflict.localData : conflict.serverData;
    final losingData = localWins ? conflict.serverData : conflict.localData;

    // Generate notification message
    final message =
        'This ${conflict.entityTypeName} was also edited on another device. '
        'Showing most recent version.';

    // Log the conflict for recovery
    _logConflict(
      conflict: conflict,
      winningData: winningData,
      losingData: losingData,
      localWon: localWins,
    );

    // Emit to stream
    _conflictStreamController.add(conflict);

    // Send notification
    onConflictNotification?.call(message);

    return ConflictResolutionResult(
      winningData: winningData,
      losingData: losingData,
      localWon: localWins,
      notificationMessage: message,
    );
  }

  /// Resolves multiple conflicts.
  List<ConflictResolutionResult> resolveAll(List<SyncConflict> conflicts) {
    return conflicts.map(resolve).toList();
  }

  /// Logs a conflict for recovery purposes.
  void _logConflict({
    required SyncConflict conflict,
    required Map<String, dynamic> winningData,
    required Map<String, dynamic> losingData,
    required bool localWon,
  }) {
    final entry = ConflictLogEntry(
      id: '${conflict.entityId}_${DateTime.now().millisecondsSinceEpoch}',
      entityId: conflict.entityId,
      entityType: conflict.entityType,
      overwrittenData: losingData,
      winningData: winningData,
      localWon: localWon,
      resolvedAt: DateTime.now(),
    );

    _conflictLog.add(entry);

    // Keep only last 100 entries to prevent memory issues
    while (_conflictLog.length > 100) {
      _conflictLog.removeAt(0);
    }
  }

  /// Gets the conflict log for potential recovery.
  List<ConflictLogEntry> getConflictLog() {
    return List.unmodifiable(_conflictLog);
  }

  /// Gets conflicts for a specific entity.
  List<ConflictLogEntry> getConflictsForEntity(String entityId) {
    return _conflictLog.where((c) => c.entityId == entityId).toList();
  }

  /// Gets the most recent conflict for an entity.
  ConflictLogEntry? getMostRecentConflict(String entityId) {
    final conflicts = getConflictsForEntity(entityId);
    if (conflicts.isEmpty) return null;
    return conflicts.reduce(
      (a, b) => a.resolvedAt.isAfter(b.resolvedAt) ? a : b,
    );
  }

  /// Clears the conflict log.
  void clearLog() {
    _conflictLog.clear();
  }

  /// Detects if there's a version mismatch that indicates a conflict.
  static bool hasVersionConflict({
    required int localVersion,
    required int serverVersion,
  }) {
    return localVersion != serverVersion;
  }

  /// Creates a SyncConflict from local and server data.
  static SyncConflict createConflict({
    required String entityId,
    required SyncEntityType entityType,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
  }) {
    // Extract version and timestamp from data
    final localVersion = localData['serverVersion'] as int? ?? 0;
    final serverVersion = serverData['serverVersion'] as int? ?? 0;

    final localUpdatedAt = localData['updatedAtUtc'] != null
        ? DateTime.parse(localData['updatedAtUtc'] as String)
        : DateTime.now();

    final serverUpdatedAt = serverData['updatedAtUtc'] != null
        ? DateTime.parse(serverData['updatedAtUtc'] as String)
        : DateTime.now();

    return SyncConflict(
      entityId: entityId,
      entityType: entityType,
      localData: localData,
      serverData: serverData,
      localVersion: localVersion,
      serverVersion: serverVersion,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: serverUpdatedAt,
    );
  }

  /// Disposes resources.
  void dispose() {
    _conflictStreamController.close();
  }
}
