import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a mock WeeklyBrief for testing.
WeeklyBrief _createMockBrief({
  String id = 'test-brief-id',
  String briefMarkdown = '# Weekly Brief\n\nTest content here.',
  int regenCount = 0,
}) {
  final now = DateTime.now().toUtc();
  return WeeklyBrief(
    id: id,
    weekStartDate: now.subtract(const Duration(days: 7)),
    weekEndDate: now,
    briefMarkdown: briefMarkdown,
    boardMicroReviewMarkdown: '## Board Review\n\nBoard notes here.',
    generatedAtUtc: now,
    regenCount: regenCount,
    createdAtUtc: now,
    updatedAtUtc: now,
    deletedAtUtc: null,
    syncStatus: 'pending',
    serverVersion: 0,
  );
}

/// Creates a test router with the WeeklyBriefViewerScreen.
GoRouter _createTestRouter({String? briefId}) {
  final initialLocation = briefId != null ? '/weekly-brief/$briefId' : '/weekly-brief/latest';

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/weekly-brief/latest',
        builder: (context, state) => const WeeklyBriefViewerScreen(),
      ),
      GoRoute(
        path: '/weekly-brief/:briefId',
        builder: (context, state) {
          final id = state.pathParameters['briefId'];
          return WeeklyBriefViewerScreen(briefId: id);
        },
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  String? briefId,
  List<WeeklyBrief>? mockBriefs,
  List<Override> overrides = const [],
}) {
  final allOverrides = <Override>[
    if (mockBriefs != null)
      weeklyBriefsStreamProvider.overrideWith(
        (ref) => Stream.value(mockBriefs),
      ),
    ...overrides,
  ];

  return ProviderScope(
    overrides: allOverrides,
    child: MaterialApp.router(
      routerConfig: _createTestRouter(briefId: briefId),
    ),
  );
}

void main() {
  group('WeeklyBriefViewerScreen', () {
    testWidgets('displays Weekly Brief title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief()],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Weekly Brief'), findsOneWidget);
    });

    testWidgets('displays loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.fromFuture(
              Future.delayed(const Duration(seconds: 10), () => <WeeklyBrief>[]),
            ),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays brief content when loaded', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [
          _createMockBrief(briefMarkdown: '# My Weekly Brief\n\nGreat progress this week.'),
        ],
      ));

      await tester.pumpAndSettle();

      // Should display the brief content
      expect(find.textContaining('Weekly Brief'), findsWidgets);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief()],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows no brief message when empty', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [],
      ));

      await tester.pumpAndSettle();

      expect(find.textContaining('No brief'), findsOneWidget);
    });

    testWidgets('has share button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief()],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('has more options menu button', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief()],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('WeeklyBriefViewerScreen - Regeneration', () {
    testWidgets('shows regeneration count', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief(regenCount: 2)],
      ));

      await tester.pumpAndSettle();

      // Should show regeneration info
      expect(find.textContaining('2'), findsWidgets);
    });
  });

  group('WeeklyBriefViewerScreen - Board Review', () {
    testWidgets('has board review section', (tester) async {
      await tester.pumpWidget(createTestApp(
        mockBriefs: [_createMockBrief()],
      ));

      await tester.pumpAndSettle();

      // Should have board micro-review section
      expect(find.textContaining('Board'), findsWidgets);
    });
  });
}
