import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/services/services.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the QuickVersionScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/governance/quick',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/governance',
        builder: (context, state) => const Scaffold(body: Text('Governance Hub')),
      ),
      GoRoute(
        path: '/governance/quick',
        builder: (context, state) => const QuickVersionScreen(),
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
  group('QuickVersionScreen', () {
    testWidgets('displays 15-Minute Audit title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.sensitivityGate,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.text('15-Minute Audit'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = const QuickVersionSessionData(
                currentState: QuickVersionState.initial,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(seconds: 10),
              () => null,
            ),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has close button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.sensitivityGate,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows progress indicator', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.q1RoleContext,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('QuickVersionScreen - Sensitivity Gate', () {
    testWidgets('displays sensitivity gate on initial state', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.sensitivityGate,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show abstraction mode option
      expect(find.textContaining('Abstraction'), findsWidgets);
    });
  });

  group('QuickVersionScreen - Abandon Dialog', () {
    testWidgets('close button shows abandon confirmation', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.q1RoleContext,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Abandon Session?'), findsOneWidget);
      expect(find.text('Continue Session'), findsOneWidget);
      expect(find.text('Abandon'), findsOneWidget);
    });

    testWidgets('Continue Session dismisses dialog', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.q1RoleContext,
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue Session'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Abandon Session?'), findsNothing);
      // Should still be on the screen
      expect(find.text('15-Minute Audit'), findsOneWidget);
    });
  });

  group('QuickVersionScreen - Question Flow', () {
    testWidgets('displays question 1 content', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.q1RoleContext,
                currentQuestion: 'What is your current role and context?',
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show the question
      expect(find.textContaining('role'), findsWidgets);
    });

    testWidgets('has text input for answers', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.q1RoleContext,
                currentQuestion: 'What is your current role?',
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('QuickVersionScreen - Completed State', () {
    testWidgets('shows output view when finalized', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quickVersionSessionProvider.overrideWith(
            (ref) => QuickVersionSessionNotifier(ref)
              ..state = QuickVersionSessionData(
                currentState: QuickVersionState.finalized,
                outputMarkdown: '# Quick Audit Complete\n\nResults here.',
              ),
          ),
          hasInProgressQuickVersionProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show completed state
      expect(find.textContaining('Complete'), findsWidgets);
    });
  });
}
