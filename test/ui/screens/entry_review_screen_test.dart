import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a mock DailyEntry for testing.
DailyEntry _createMockEntry({
  String id = 'test-entry-id',
  String transcript = 'Test transcript content',
  String? signalsJson,
}) {
  return DailyEntry(
    id: id,
    entryType: EntryType.text.name,
    transcriptRaw: transcript,
    transcriptEdited: transcript,
    signalsJson: signalsJson ?? '[]',
    wordCount: transcript.split(' ').length,
    createdAtUtc: DateTime.now().toUtc(),
    createdAtTimezone: 'America/New_York',
    updatedAtUtc: DateTime.now().toUtc(),
    deletedAtUtc: null,
    syncStatus: 'pending',
    serverVersion: 0,
  );
}

/// Creates a test router with the EntryReviewScreen.
GoRouter _createTestRouter(String entryId) {
  return GoRouter(
    initialLocation: '/entry/$entryId',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/entry/:entryId',
        builder: (context, state) {
          final id = state.pathParameters['entryId'] ?? '';
          return EntryReviewScreen(entryId: id);
        },
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  required String entryId,
  DailyEntry? mockEntry,
  List<Override> overrides = const [],
}) {
  final allOverrides = <Override>[
    // Override the entry provider if a mock entry is provided
    if (mockEntry != null)
      entryByIdProvider(entryId).overrideWith(
        (ref) async => mockEntry,
      ),
    ...overrides,
  ];

  return ProviderScope(
    overrides: allOverrides,
    child: MaterialApp.router(
      routerConfig: _createTestRouter(entryId),
    ),
  );
}

void main() {
  group('EntryReviewScreen', () {
    testWidgets('displays loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        overrides: [
          entryByIdProvider('test-id').overrideWith(
            (ref) => Future.delayed(
              const Duration(seconds: 10),
              () => _createMockEntry(),
            ),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays entry content when loaded', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(
          transcript: 'My test journal entry content',
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.textContaining('My test journal entry'), findsOneWidget);
    });

    testWidgets('displays Entry Review in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Entry Review'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has edit button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('has delete button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows not found when entry does not exist', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'nonexistent-id',
        overrides: [
          entryByIdProvider('nonexistent-id').overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.textContaining('not found'), findsOneWidget);
    });
  });

  group('EntryReviewScreen - Signals', () {
    testWidgets('displays signals section header', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(
          signalsJson: '''[
            {"type": "wins", "text": "Completed project milestone"},
            {"type": "blockers", "text": "Waiting on approval"}
          ]''',
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Extracted Signals'), findsOneWidget);
    });
  });

  group('EntryReviewScreen - Delete', () {
    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel button dismisses delete dialog', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsNothing);
    });
  });

  group('EntryReviewScreen - Edit Mode', () {
    testWidgets('tapping edit button enters edit mode', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      // In edit mode, should show a TextField instead of read-only text
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('edit mode shows save button', (tester) async {
      await tester.pumpWidget(createTestApp(
        entryId: 'test-id',
        mockEntry: _createMockEntry(),
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.save), findsOneWidget);
    });
  });
}
