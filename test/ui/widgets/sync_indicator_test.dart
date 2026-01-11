import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/providers/sync_providers.dart';
import 'package:boardroom_journal/services/sync/sync_service.dart';
import 'package:boardroom_journal/ui/widgets/sync_indicator.dart';

void main() {
  group('SyncIndicator', () {
    Widget createTestWidget({
      required SyncStatus syncStatus,
      int pendingCount = 0,
      double iconSize = 24.0,
      bool showBadge = true,
      bool showDetailsOnTap = false, // Disable for simpler testing
    }) {
      return ProviderScope(
        overrides: [
          syncNotifierProvider.overrideWith((ref) {
            return _MockSyncNotifier(syncStatus);
          }),
          pendingChangesCountProvider.overrideWithValue(pendingCount),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SyncIndicator(
              iconSize: iconSize,
              showBadge: showBadge,
              showDetailsOnTap: showDetailsOnTap,
            ),
          ),
        ),
      );
    }

    group('icon rendering', () {
      testWidgets('shows cloud_done icon when idle', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(state: SyncState.idle),
        ));

        expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      });

      testWidgets('shows cloud_upload icon when syncing with pending changes',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.syncing,
            pendingCount: 5,
            isSyncing: true,
          ),
          pendingCount: 5,
        ));

        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      });

      testWidgets('shows cloud_download icon when syncing without pending',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.syncing,
            pendingCount: 0,
            isSyncing: true,
          ),
          pendingCount: 0,
        ));

        expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
      });

      testWidgets('shows cloud_off icon when error', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.error,
            errorMessage: 'Connection failed',
          ),
        ));

        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('shows cloud_off_outlined icon when offline', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(state: SyncState.offline),
        ));

        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      });

      testWidgets('shows cloud_upload icon when pendingChanges',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.pendingChanges,
            pendingCount: 3,
          ),
          pendingCount: 3,
        ));

        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      });
    });

    group('badge display', () {
      testWidgets('shows badge when pendingCount > 0 and showBadge true',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.pendingChanges,
            pendingCount: 5,
          ),
          pendingCount: 5,
          showBadge: true,
        ));

        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('hides badge when pendingCount is 0', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(state: SyncState.idle),
          pendingCount: 0,
          showBadge: true,
        ));

        // Should not find any number badge
        expect(find.text('0'), findsNothing);
      });

      testWidgets('hides badge when showBadge is false', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.pendingChanges,
            pendingCount: 5,
          ),
          pendingCount: 5,
          showBadge: false,
        ));

        expect(find.text('5'), findsNothing);
      });

      testWidgets('shows 99+ when count exceeds 99', (tester) async {
        await tester.pumpWidget(createTestWidget(
          syncStatus: const SyncStatus(
            state: SyncState.pendingChanges,
            pendingCount: 150,
          ),
          pendingCount: 150,
          showBadge: true,
        ));

        expect(find.text('99+'), findsOneWidget);
      });
    });

    testWidgets('respects custom iconSize', (tester) async {
      await tester.pumpWidget(createTestWidget(
        syncStatus: const SyncStatus(state: SyncState.idle),
        iconSize: 32.0,
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done_outlined));
      expect(icon.size, 32.0);
    });
  });

  group('EntrySyncBadge', () {
    Widget createBadgeWidget({
      required String syncStatus,
      double size = 12,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: EntrySyncBadge(
            syncStatus: syncStatus,
            size: size,
          ),
        ),
      );
    }

    testWidgets('shows cloud_done icon for synced status', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'synced'));

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('shows cloud_upload icon for pending status', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'pending'));

      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    });

    testWidgets('shows warning icon for conflict status', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'conflict'));

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows cloud_off icon for unknown status', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'unknown'));

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(createBadgeWidget(
        syncStatus: 'synced',
        size: 20,
      ));

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
      expect(icon.size, 20);
    });

    testWidgets('has tooltip with correct message for synced', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'synced'));

      expect(find.byType(Tooltip), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Synced');
    });

    testWidgets('has tooltip with correct message for pending', (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'pending'));

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Pending sync');
    });

    testWidgets('has tooltip with correct message for conflict',
        (tester) async {
      await tester.pumpWidget(createBadgeWidget(syncStatus: 'conflict'));

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Sync conflict');
    });
  });

  group('OfflineBanner', () {
    Widget createBannerWidget({required bool isOffline}) {
      return ProviderScope(
        overrides: [
          isOfflineProvider.overrideWithValue(isOffline),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OfflineBanner(),
                Expanded(child: Placeholder()),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('shows banner when offline', (tester) async {
      await tester.pumpWidget(createBannerWidget(isOffline: true));

      expect(find.text('You are offline'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('hides banner when online', (tester) async {
      await tester.pumpWidget(createBannerWidget(isOffline: false));

      expect(find.text('You are offline'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('ConflictNotification', () {
    Widget createNotificationWidget({
      required String entityType,
      VoidCallback? onDismiss,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ConflictNotification(
            entityType: entityType,
            onDismiss: onDismiss,
          ),
        ),
      );
    }

    testWidgets('displays entity type in message', (tester) async {
      await tester.pumpWidget(createNotificationWidget(entityType: 'entry'));

      expect(
        find.text(
            'This entry was also edited on another device. Showing most recent version.'),
        findsOneWidget,
      );
    });

    testWidgets('displays info icon', (tester) async {
      await tester.pumpWidget(createNotificationWidget(entityType: 'brief'));

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('shows close button when onDismiss provided', (tester) async {
      await tester.pumpWidget(createNotificationWidget(
        entityType: 'entry',
        onDismiss: () {},
      ));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides close button when onDismiss is null', (tester) async {
      await tester.pumpWidget(createNotificationWidget(
        entityType: 'entry',
        onDismiss: null,
      ));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onDismiss when close button tapped', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(createNotificationWidget(
        entityType: 'entry',
        onDismiss: () => dismissed = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('works with different entity types', (tester) async {
      await tester.pumpWidget(createNotificationWidget(entityType: 'problem'));

      expect(
        find.textContaining('This problem was also edited'),
        findsOneWidget,
      );
    });
  });
}

/// Mock sync notifier for testing.
class _MockSyncNotifier extends SyncNotifier {
  _MockSyncNotifier(SyncStatus status) : super(null) {
    state = status;
  }
}
