import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/settings_providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the SettingsScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/personas',
        builder: (context, state) => const Scaffold(body: Text('Personas')),
      ),
      GoRoute(
        path: '/settings/portfolio',
        builder: (context, state) => const Scaffold(body: Text('Portfolio')),
      ),
      GoRoute(
        path: '/settings/versions',
        builder: (context, state) => const Scaffold(body: Text('Versions')),
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
  group('SettingsScreen', () {
    testWidgets('displays Settings title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays Account section', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Sign-in Methods'), findsOneWidget);
    });

    testWidgets('displays Privacy section with abstraction toggle', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Abstraction Mode'), findsOneWidget);
    });

    testWidgets('displays Data section with export/import options', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Export Data'), findsOneWidget);
    });

    testWidgets('displays Board section', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Board Personas'), findsOneWidget);
    });

    testWidgets('displays Portfolio section', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text('Edit Problems'), findsOneWidget);
      expect(find.text('Version History'), findsOneWidget);
    });

    testWidgets('displays About section', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('has scrollable content', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows delete account option in Account section', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          abstractionModeNotifierProvider.overrideWith(
            (ref) => AbstractionModeNotifier()..state = false,
          ),
          analyticsNotifierProvider.overrideWith(
            (ref) => AnalyticsNotifier()..state = true,
          ),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('7-day grace period'), findsOneWidget);
    });
  });
}
