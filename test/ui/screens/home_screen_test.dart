import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';
import 'package:boardroom_journal/router/router.dart';

/// Creates a test router with the HomeScreen as initial route.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/record-entry',
        builder: (context, state) => const Scaffold(body: Text('Record Entry')),
      ),
      GoRoute(
        path: '/governance',
        builder: (context, state) => const Scaffold(body: Text('Governance')),
      ),
      GoRoute(
        path: '/governance/quick',
        builder: (context, state) => const Scaffold(body: Text('Quick Version')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const Scaffold(body: Text('History')),
      ),
      GoRoute(
        path: '/weekly-brief/latest',
        builder: (context, state) => const Scaffold(body: Text('Latest Brief')),
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  required Widget child,
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
  group('HomeScreen', () {
    testWidgets('displays app bar with correct title', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          // Override stream providers with empty data
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Boardroom Journal'), findsOneWidget);
    });

    testWidgets('displays Record Entry button prominently', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      // Per PRD 5.1: Record Entry should be "one tap away from app open"
      expect(find.text('Record Entry'), findsOneWidget);
    });

    testWidgets('displays History button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('displays Settings button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('shows Setup prompt when shouldShowSetupPrompt is true', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(true)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(5)),
        ],
      ));

      await tester.pumpAndSettle();

      // Per PRD 5.0: Setup prompt appears after 3-5 entries if no portfolio
      expect(find.textContaining('Set up'), findsWidgets);
    });

    testWidgets('hides Setup prompt when shouldShowSetupPrompt is false', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(true)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(10)),
        ],
      ));

      await tester.pumpAndSettle();

      // Setup prompt should not appear when user has portfolio
      expect(find.textContaining('board of directors'), findsNothing);
    });

    testWidgets('displays Quick Actions section', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      // Per PRD 5.1: Quick Actions include 15-min Audit and Governance
      expect(find.text('15-min Audit'), findsOneWidget);
      expect(find.text('Governance'), findsOneWidget);
    });

    testWidgets('displays entry statistics', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(42)),
        ],
      ));

      await tester.pumpAndSettle();

      // Should show entry count
      expect(find.textContaining('42'), findsWidgets);
    });

    testWidgets('can scroll content', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      // Find the scrollable widget and verify it exists
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('HomeScreen Navigation', () {
    testWidgets('tapping Settings navigates to settings screen', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('tapping History navigates to history screen', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const HomeScreen(),
        overrides: [
          dailyEntriesStreamProvider.overrideWith(
            (ref) => Stream.value(<DailyEntry>[]),
          ),
          weeklyBriefsStreamProvider.overrideWith(
            (ref) => Stream.value(<WeeklyBrief>[]),
          ),
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          shouldShowSetupPromptProvider.overrideWith((ref) => Future.value(false)),
          totalEntryCountProvider.overrideWith((ref) => Future.value(0)),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
    });
  });
}
