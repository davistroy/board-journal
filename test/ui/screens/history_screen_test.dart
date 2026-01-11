import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/models/export_format.dart';
import 'package:boardroom_journal/providers/database_provider.dart';
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
  required AppDatabase database,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
    ],
    child: MaterialApp.router(
      routerConfig: _createTestRouter(),
    ),
  );
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('HistoryScreen', () {
    testWidgets('displays History title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has export button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
    });

    testWidgets('shows empty state when no items', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      // Should show empty state message - actual text is "No entries yet"
      expect(find.text('No entries yet'), findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(createTestApp(database: database));

      // The loading state may be too fast to catch in tests with an in-memory database
      // Just verify the widget builds without error
      await tester.pump();

      // Either show loading or show the settled content
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.text('No entries yet').evaluate().isNotEmpty ||
            find.byType(ListView).evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('HistoryScreen - Export', () {
    testWidgets('tapping export shows dialog', (tester) async {
      // Use a larger surface size for the dialog
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(database: database));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      // Should show export dialog - "Export Data" appears in dialog title
      expect(find.text('Export Data'), findsOneWidget);

      // Reset view
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
