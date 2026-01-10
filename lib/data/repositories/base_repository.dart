/// Base types and utilities for repositories.
///
/// Provides common abstractions for sync status management,
/// soft delete, and pagination across all repositories.
library;

/// Sync status values for local-first sync strategy.
///
/// Per PRD Section 3B.2:
/// - pending: Local changes not yet synced
/// - synced: Matches server state
/// - conflict: Server has different version (last-write-wins with notification)
enum SyncStatus {
  pending,
  synced,
  conflict,
}

extension SyncStatusExtension on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.conflict:
        return 'conflict';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'synced':
        return SyncStatus.synced;
      case 'conflict':
        return SyncStatus.conflict;
      default:
        return SyncStatus.pending;
    }
  }
}

/// Result wrapper for paginated queries.
class PaginatedResult<T> {
  final List<T> items;
  final int totalCount;
  final int offset;
  final int limit;

  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.offset,
    required this.limit,
  });

  bool get hasMore => offset + items.length < totalCount;

  int get nextOffset => offset + items.length;
}

/// Date range for querying entries by time period.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Creates a date range for a specific week (Monday to Sunday).
  factory DateRange.forWeek(DateTime anyDayInWeek) {
    // Find Monday of this week
    final monday = anyDayInWeek.subtract(
      Duration(days: anyDayInWeek.weekday - 1),
    );
    final startOfWeek = DateTime.utc(monday.year, monday.month, monday.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateRange(start: startOfWeek, end: endOfWeek);
  }

  /// Creates a date range for a specific month.
  factory DateRange.forMonth(int year, int month) {
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 0, 23, 59, 59);
    return DateRange(start: start, end: end);
  }
}
