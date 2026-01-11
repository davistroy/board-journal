import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/services/services.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the QuarterlyScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/governance/quarterly',
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
        path: '/governance/quarterly',
        builder: (context, state) => const QuarterlyScreen(),
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
  group('QuarterlyScreen', () {
    testWidgets('displays Quarterly Report title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.sensitivityGate,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.text('Quarterly Report'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = const QuarterlySessionData(
                currentState: QuarterlyState.initial,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
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
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.sensitivityGate,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows progress indicator when active', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.q1LastBetEvaluation,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('QuarterlyScreen - Sensitivity Gate', () {
    testWidgets('displays sensitivity gate on initial state', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.sensitivityGate,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show abstraction mode option
      expect(find.textContaining('Abstraction'), findsWidgets);
    });
  });

  group('QuarterlyScreen - Abandon Dialog', () {
    testWidgets('close button shows abandon confirmation', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.q1LastBetEvaluation,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
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
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.q1LastBetEvaluation,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
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
      expect(find.text('Quarterly Report'), findsOneWidget);
    });
  });

  group('QuarterlyScreen - Question Flow', () {
    testWidgets('displays bet evaluation question', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.q1LastBetEvaluation,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show the question content
      expect(find.textContaining('bet'), findsWidgets);
    });

    testWidgets('has text input for answers', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.q2CommitmentsVsActuals,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('QuarterlyScreen - Board Interrogation', () {
    testWidgets('displays board interrogation state', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.coreBoardInterrogation,
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show board interrogation UI
      expect(find.textContaining('Board'), findsWidgets);
    });
  });

  group('QuarterlyScreen - Report Generation', () {
    testWidgets('shows report view when finalized', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          quarterlySessionProvider.overrideWith(
            (ref) => QuarterlySessionNotifier(ref)
              ..state = QuarterlySessionData(
                currentState: QuarterlyState.finalized,
                outputMarkdown: '# Quarterly Report\n\nResults here.',
              ),
          ),
          hasInProgressQuarterlyProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show completed report
      expect(find.textContaining('Report'), findsWidgets);
    });
  });
}
