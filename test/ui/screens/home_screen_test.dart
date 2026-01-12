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

/// Helper to pump widget and wait for animations.
/// Uses pump with duration instead of pumpAndSettle to handle infinite animations.
Future<void> pumpWithAnimations(WidgetTester tester, {int frames = 10}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await pumpWithAnimations(tester);

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

      await pumpWithAnimations(tester);

      await tester.tap(find.byIcon(Icons.history));
      await pumpWithAnimations(tester);

      expect(find.text('History'), findsOneWidget);
    });
  });
}
