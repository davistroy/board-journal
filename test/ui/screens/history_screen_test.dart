import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/history_providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the HistoryScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/history',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/entry/:entryId',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId'] ?? '';
          return Scaffold(body: Text('Entry: $entryId'));
        },
      ),
      GoRoute(
        path: '/weekly-brief/:briefId',
        builder: (context, state) {
          final briefId = state.pathParameters['briefId'] ?? '';
          return Scaffold(body: Text('Brief: $briefId'));
        },
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: _createTestRouter(),
    ),
  );
}

void main() {
  group('HistoryScreen', () {
    testWidgets('displays History title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has export button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.textContaining('No entries'), findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.loading(),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('HistoryScreen - Export', () {
    testWidgets('tapping export shows dialog', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          historyNotifierProvider.overrideWith(
            (ref) => HistoryNotifier(ref)..state = const AsyncValue.data([]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      // Should show export dialog
      expect(find.text('Export Data'), findsWidgets);
    });
  });
}
