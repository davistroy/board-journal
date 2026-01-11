import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/repositories/base_repository.dart';

void main() {
  group('SyncStatus', () {
    test('has all expected values', () {
      expect(SyncStatus.values, hasLength(3));
      expect(SyncStatus.values, contains(SyncStatus.pending));
      expect(SyncStatus.values, contains(SyncStatus.synced));
      expect(SyncStatus.values, contains(SyncStatus.conflict));
    });
  });

  group('SyncStatusExtension', () {
    group('value getter', () {
      test('pending returns "pending"', () {
        expect(SyncStatus.pending.value, 'pending');
      });

      test('synced returns "synced"', () {
        expect(SyncStatus.synced.value, 'synced');
      });

      test('conflict returns "conflict"', () {
        expect(SyncStatus.conflict.value, 'conflict');
      });
    });

    group('fromString', () {
      test('parses "pending"', () {
        expect(SyncStatusExtension.fromString('pending'), SyncStatus.pending);
      });

      test('parses "synced"', () {
        expect(SyncStatusExtension.fromString('synced'), SyncStatus.synced);
      });

      test('parses "conflict"', () {
        expect(SyncStatusExtension.fromString('conflict'), SyncStatus.conflict);
      });

      test('returns pending for unknown values', () {
        expect(SyncStatusExtension.fromString('unknown'), SyncStatus.pending);
        expect(SyncStatusExtension.fromString(''), SyncStatus.pending);
        expect(SyncStatusExtension.fromString('PENDING'), SyncStatus.pending);
      });
    });

    group('roundtrip', () {
      test('all values roundtrip correctly', () {
        for (final status in SyncStatus.values) {
          final stringValue = status.value;
          final parsed = SyncStatusExtension.fromString(stringValue);
          expect(parsed, status);
        }
      });
    });
  });

  group('PaginatedResult', () {
    group('constructor', () {
      test('creates with required fields', () {
        final result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          totalCount: 10,
          offset: 0,
          limit: 3,
        );

        expect(result.items, ['a', 'b', 'c']);
        expect(result.totalCount, 10);
        expect(result.offset, 0);
        expect(result.limit, 3);
      });

      test('creates with empty items', () {
        final result = PaginatedResult<int>(
          items: [],
          totalCount: 0,
          offset: 0,
          limit: 10,
        );

        expect(result.items, isEmpty);
        expect(result.totalCount, 0);
      });
    });

    group('hasMore', () {
      test('returns true when more items exist', () {
        final result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          totalCount: 10,
          offset: 0,
          limit: 3,
        );

        expect(result.hasMore, isTrue);
      });

      test('returns false when at end', () {
        final result = PaginatedResult<String>(
          items: ['h', 'i', 'j'],
          totalCount: 10,
          offset: 7,
          limit: 3,
        );

        expect(result.hasMore, isFalse);
      });

      test('returns false when items equal total', () {
        final result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          totalCount: 3,
          offset: 0,
          limit: 10,
        );

        expect(result.hasMore, isFalse);
      });

      test('returns false for empty result with zero total', () {
        final result = PaginatedResult<String>(
          items: [],
          totalCount: 0,
          offset: 0,
          limit: 10,
        );

        expect(result.hasMore, isFalse);
      });

      test('returns true when partially through results', () {
        final result = PaginatedResult<int>(
          items: [4, 5, 6],
          totalCount: 10,
          offset: 3,
          limit: 3,
        );

        expect(result.hasMore, isTrue);
      });
    });

    group('nextOffset', () {
      test('returns offset plus items length', () {
        final result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          totalCount: 10,
          offset: 0,
          limit: 3,
        );

        expect(result.nextOffset, 3);
      });

      test('calculates correctly for middle page', () {
        final result = PaginatedResult<String>(
          items: ['d', 'e', 'f'],
          totalCount: 10,
          offset: 3,
          limit: 3,
        );

        expect(result.nextOffset, 6);
      });

      test('returns offset for empty items', () {
        final result = PaginatedResult<String>(
          items: [],
          totalCount: 0,
          offset: 5,
          limit: 10,
        );

        expect(result.nextOffset, 5);
      });
    });
  });

  group('DateRange', () {
    group('constructor', () {
      test('creates with start and end dates', () {
        final start = DateTime.utc(2025, 1, 1);
        final end = DateTime.utc(2025, 1, 31);
        final range = DateRange(start: start, end: end);

        expect(range.start, start);
        expect(range.end, end);
      });
    });

    group('forWeek', () {
      test('returns Monday to Sunday for mid-week date', () {
        // Wednesday Jan 15, 2025
        final wednesday = DateTime.utc(2025, 1, 15);
        final range = DateRange.forWeek(wednesday);

        // Should be Monday Jan 13 to Sunday Jan 19
        expect(range.start, DateTime.utc(2025, 1, 13));
        expect(range.end.year, 2025);
        expect(range.end.month, 1);
        expect(range.end.day, 19);
        expect(range.end.hour, 23);
        expect(range.end.minute, 59);
        expect(range.end.second, 59);
      });

      test('returns correct week for Monday', () {
        // Monday Jan 13, 2025
        final monday = DateTime.utc(2025, 1, 13);
        final range = DateRange.forWeek(monday);

        expect(range.start, DateTime.utc(2025, 1, 13));
        expect(range.end.day, 19);
      });

      test('returns correct week for Sunday', () {
        // Sunday Jan 19, 2025
        final sunday = DateTime.utc(2025, 1, 19);
        final range = DateRange.forWeek(sunday);

        expect(range.start, DateTime.utc(2025, 1, 13));
        expect(range.end.day, 19);
      });

      test('handles week spanning month boundary', () {
        // Thursday Jan 30, 2025 - week spans Jan/Feb
        final thursday = DateTime.utc(2025, 1, 30);
        final range = DateRange.forWeek(thursday);

        // Monday Jan 27 to Sunday Feb 2
        expect(range.start, DateTime.utc(2025, 1, 27));
        expect(range.end.month, 2);
        expect(range.end.day, 2);
      });

      test('handles week spanning year boundary', () {
        // Wednesday Jan 1, 2025 - week starts in Dec 2024
        final newYearsDay = DateTime.utc(2025, 1, 1);
        final range = DateRange.forWeek(newYearsDay);

        // Monday Dec 30, 2024 to Sunday Jan 5, 2025
        expect(range.start.year, 2024);
        expect(range.start.month, 12);
        expect(range.start.day, 30);
        expect(range.end.year, 2025);
        expect(range.end.month, 1);
        expect(range.end.day, 5);
      });
    });

    group('forMonth', () {
      test('returns correct range for January', () {
        final range = DateRange.forMonth(2025, 1);

        expect(range.start, DateTime.utc(2025, 1, 1));
        expect(range.end.year, 2025);
        expect(range.end.month, 1);
        expect(range.end.day, 31);
        expect(range.end.hour, 23);
        expect(range.end.minute, 59);
        expect(range.end.second, 59);
      });

      test('returns correct range for February in non-leap year', () {
        final range = DateRange.forMonth(2025, 2);

        expect(range.start, DateTime.utc(2025, 2, 1));
        expect(range.end.day, 28);
      });

      test('returns correct range for February in leap year', () {
        final range = DateRange.forMonth(2024, 2);

        expect(range.start, DateTime.utc(2024, 2, 1));
        expect(range.end.day, 29);
      });

      test('returns correct range for month with 30 days', () {
        final range = DateRange.forMonth(2025, 4); // April

        expect(range.start, DateTime.utc(2025, 4, 1));
        expect(range.end.day, 30);
      });

      test('returns correct range for December', () {
        final range = DateRange.forMonth(2025, 12);

        expect(range.start, DateTime.utc(2025, 12, 1));
        expect(range.end.month, 12);
        expect(range.end.day, 31);
      });
    });
  });
}
