import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boardroom_journal/providers/scheduling_providers.dart';
import 'package:boardroom_journal/providers/sync_providers.dart';
import 'package:boardroom_journal/services/api/api.dart';
import 'package:boardroom_journal/services/sync/sync.dart';

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
      test('creates SyncQueue with SharedPreferences', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final queue = container.read(syncQueueProvider);

        expect(queue, isA<SyncQueue>());
      });
    });

    group('isSyncingProvider', () {
      test('returns false initially', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle, isSyncing: false),
              ),
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
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.syncing, isSyncing: true),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final isSyncing = container.read(isSyncingProvider);

        expect(isSyncing, isTrue);
      });
    });

    group('pendingChangesCountProvider', () {
      test('returns 0 when no pending items', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle, pendingCount: 0),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final count = container.read(pendingChangesCountProvider);

        expect(count, 0);
      });

      test('returns pending count from state', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle, pendingCount: 5),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final count = container.read(pendingChangesCountProvider);

        expect(count, 5);
      });
    });

    group('syncErrorProvider', () {
      test('returns null when no error', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle),
              ),
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
              (ref) => _MockSyncNotifier(
                const SyncStatus(
                  state: SyncState.error,
                  errorMessage: 'Network failed',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final error = container.read(syncErrorProvider);

        expect(error, 'Network failed');
      });
    });

    group('isOfflineProvider', () {
      test('returns false when not offline', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final isOffline = container.read(isOfflineProvider);

        expect(isOffline, isFalse);
      });

      test('returns true when offline', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.offline),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final isOffline = container.read(isOfflineProvider);

        expect(isOffline, isTrue);
      });
    });

    group('hasPendingChangesProvider', () {
      test('returns false when no pending changes', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.idle, pendingCount: 0),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hasPending = container.read(hasPendingChangesProvider);

        expect(hasPending, isFalse);
      });

      test('returns true when pending changes exist', () {
        final container = ProviderContainer(
          overrides: [
            syncNotifierProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const SyncStatus(state: SyncState.pendingChanges, pendingCount: 3),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final hasPending = container.read(hasPendingChangesProvider);

        expect(hasPending, isTrue);
      });
    });
  });

  group('SyncStatus', () {
    test('initial state has correct defaults', () {
      final status = SyncStatus.initial();

      expect(status.state, SyncState.idle);
      expect(status.pendingCount, 0);
      expect(status.isSyncing, false);
      expect(status.errorMessage, isNull);
      expect(status.lastSyncTime, isNull);
    });

    test('copyWith preserves values', () {
      const original = SyncStatus(
        state: SyncState.idle,
        pendingCount: 5,
        isSyncing: false,
      );
      final copied = original.copyWith(pendingCount: 10);

      expect(copied.pendingCount, 10);
      expect(copied.state, SyncState.idle);
    });

    test('copyWith can change state', () {
      const original = SyncStatus(state: SyncState.idle);
      final copied = original.copyWith(state: SyncState.syncing, isSyncing: true);

      expect(copied.state, SyncState.syncing);
      expect(copied.isSyncing, true);
    });
  });
}

/// Mock sync notifier for testing derived providers.
class _MockSyncNotifier extends StateNotifier<SyncStatus> implements SyncNotifier {
  _MockSyncNotifier(SyncStatus status) : super(status);

  @override
  Future<void> syncAll() async {}

  @override
  Future<void> syncChanges() async {}

  @override
  Future<void> fullDownload() async {}

  @override
  void notifyLocalChange() {}

  @override
  void onAppResumed() {}

  @override
  void onAppPaused() {}
}
