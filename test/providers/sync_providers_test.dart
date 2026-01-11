import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boardroom_journal/providers/sync_providers.dart';
import 'package:boardroom_journal/services/api/api.dart';
import 'package:boardroom_journal/services/sync/sync.dart';

@GenerateMocks([SharedPreferences])
import 'sync_providers_test.mocks.dart';

void main() {
  group('Sync Providers', () {
    group('apiConfigProvider', () {
      test('returns development config by default', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final config = container.read(apiConfigProvider);

        expect(config, isA<ApiConfig>());
        expect(config.baseUrl, contains('localhost'));
      });
    });

    group('conflictResolverProvider', () {
      test('creates ConflictResolver instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final resolver = container.read(conflictResolverProvider);

        expect(resolver, isA<ConflictResolver>());
      });

      test('disposes resolver on container dispose', () {
        final container = ProviderContainer();

        final resolver = container.read(conflictResolverProvider);
        expect(resolver, isNotNull);

        container.dispose();
        // Resolver should be disposed (no error thrown)
      });
    });

    group('syncQueueProvider', () {
      test('returns null when SharedPreferences not loaded', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // SharedPreferences is async, so initially null
        final queue = container.read(syncQueueProvider);

        expect(queue, isNull);
      });
    });

    group('connectivityProvider', () {
      test('provides connectivity stream', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final connectivity = container.read(connectivityProvider);

        expect(connectivity, isA<Stream>());
      });
    });

    group('isSyncingProvider', () {
      test('returns false initially', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle()),
            ),
          ],
        );
        addTearDown(container.dispose);

        final isSyncing = container.read(isSyncingProvider);

        expect(isSyncing, isFalse);
      });

      test('returns true when syncing', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.syncing()),
            ),
          ],
        );
        addTearDown(container.dispose);

        final isSyncing = container.read(isSyncingProvider);

        expect(isSyncing, isTrue);
      });
    });

    group('pendingSyncCountProvider', () {
      test('returns 0 when no pending items', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle(pendingCount: 0)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final count = container.read(pendingSyncCountProvider);

        expect(count, 0);
      });

      test('returns pending count from state', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle(pendingCount: 5)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final count = container.read(pendingSyncCountProvider);

        expect(count, 5);
      });
    });

    group('syncErrorProvider', () {
      test('returns null when no error', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle()),
            ),
          ],
        );
        addTearDown(container.dispose);

        final error = container.read(syncErrorProvider);

        expect(error, isNull);
      });

      test('returns error message when error state', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.error('Network failed')),
            ),
          ],
        );
        addTearDown(container.dispose);

        final error = container.read(syncErrorProvider);

        expect(error, 'Network failed');
      });
    });

    group('hasConflictsProvider', () {
      test('returns false when no conflicts', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle(hasConflicts: false)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hasConflicts = container.read(hasConflictsProvider);

        expect(hasConflicts, isFalse);
      });

      test('returns true when conflicts exist', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => MockSyncNotifier(SyncState.idle(hasConflicts: true)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hasConflicts = container.read(hasConflictsProvider);

        expect(hasConflicts, isTrue);
      });
    });
  });

  group('SyncState', () {
    test('idle state has correct defaults', () {
      final state = SyncState.idle();

      expect(state.status, SyncStatus.idle);
      expect(state.pendingCount, 0);
      expect(state.hasConflicts, false);
      expect(state.error, isNull);
    });

    test('syncing state has correct status', () {
      final state = SyncState.syncing();

      expect(state.status, SyncStatus.syncing);
    });

    test('error state contains message', () {
      final state = SyncState.error('Test error');

      expect(state.status, SyncStatus.error);
      expect(state.error, 'Test error');
    });

    test('copyWith preserves values', () {
      final original = SyncState.idle(pendingCount: 5, hasConflicts: true);
      final copied = original.copyWith(pendingCount: 10);

      expect(copied.pendingCount, 10);
      expect(copied.hasConflicts, true);
    });
  });
}

/// Mock sync notifier for testing derived providers.
class MockSyncNotifier extends StateNotifier<SyncState> implements SyncNotifier {
  MockSyncNotifier(super.state);

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> cancelSync() async {}

  @override
  Future<void> resolveConflict(String entityId, ConflictResolution resolution) async {}

  @override
  void clearError() {}
}
