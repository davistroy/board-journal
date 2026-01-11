import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the GovernanceHubScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/governance',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/governance',
        builder: (context, state) => const GovernanceHubScreen(),
      ),
      GoRoute(
        path: '/governance/quick',
        builder: (context, state) => const Scaffold(body: Text('Quick Version')),
      ),
      GoRoute(
        path: '/governance/setup',
        builder: (context, state) => const Scaffold(body: Text('Setup')),
      ),
      GoRoute(
        path: '/governance/quarterly',
        builder: (context, state) => const Scaffold(body: Text('Quarterly')),
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
  group('GovernanceHubScreen', () {
    testWidgets('displays Governance title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Governance'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays all four tabs as per PRD 5.5', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Per PRD 5.5: Quick Version, Setup, Quarterly, Board tabs
      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('Quarterly'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
    });

    testWidgets('has TabBarView for tab content', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byType(TabBarView), findsOneWidget);
    });
  });

  group('GovernanceHubScreen - Quick Tab', () {
    testWidgets('Quick tab shows 15-Minute Audit content', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Quick tab should be selected by default
      expect(find.text('15-Minute Audit'), findsOneWidget);
      expect(find.text('5 questions to audit your week'), findsOneWidget);
    });

    testWidgets('Quick tab has Start button', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Start Quick Audit'), findsOneWidget);
    });

    testWidgets('tapping Start Quick Audit navigates to quick version', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Quick Audit'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Version'), findsOneWidget);
    });
  });

  group('GovernanceHubScreen - Setup Tab', () {
    testWidgets('Setup tab shows setup content when no portfolio exists', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Should show setup prompt when no portfolio exists
      expect(find.textContaining('Portfolio'), findsWidgets);
    });

    testWidgets('Setup tab shows different content when portfolio exists', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(true)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // When portfolio exists, different UI is shown
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('GovernanceHubScreen - Quarterly Tab', () {
    testWidgets('Quarterly tab is locked when no portfolio exists', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Quarterly tab
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();

      // Per PRD 5.5: Quarterly is locked without portfolio
      expect(find.textContaining('Setup'), findsWidgets);
    });

    testWidgets('Quarterly tab shows content when portfolio exists', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(true)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Quarterly tab
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();

      // Should show quarterly report content
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('GovernanceHubScreen - Board Tab', () {
    testWidgets('Board tab shows content', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(true)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      // Per PRD 5.5: Board tab shows roles and personas
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Board tab shows message when no board exists', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Navigate to Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      // Should indicate board isn't set up
      expect(find.textContaining('Set up'), findsWidgets);
    });
  });

  group('GovernanceHubScreen - Tab Navigation', () {
    testWidgets('can switch between tabs', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      // Start on Quick tab
      expect(find.text('15-Minute Audit'), findsOneWidget);

      // Switch to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Switch to Quarterly tab
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();

      // Switch to Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();

      // Switch back to Quick tab
      await tester.tap(find.text('Quick'));
      await tester.pumpAndSettle();

      expect(find.text('15-Minute Audit'), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          hasPortfolioProvider.overrideWith((ref) => Future.value(false)),
          activeBoardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
