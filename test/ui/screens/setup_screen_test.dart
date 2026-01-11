import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/services/services.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the SetupScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/governance/setup',
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
        path: '/governance/setup',
        builder: (context, state) => const SetupScreen(),
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
  group('SetupScreen', () {
    testWidgets('displays initial state in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.sensitivityGate,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show the current state name
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = const SetupSessionData(
                currentState: SetupState.initial,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) => Future.delayed(
              const Duration(seconds: 10),
              () => null,
            ),
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has close button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.sensitivityGate,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows progress percentage when active', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.collectProblem1,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show progress indicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('SetupScreen - Sensitivity Gate', () {
    testWidgets('displays sensitivity gate options', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.sensitivityGate,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show abstraction mode toggle
      expect(find.textContaining('Abstraction'), findsWidgets);
    });
  });

  group('SetupScreen - Exit Confirmation', () {
    testWidgets('close button shows exit confirmation', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.collectProblem1,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.textContaining('Exit'), findsWidgets);
    });
  });

  group('SetupScreen - Problem Collection', () {
    testWidgets('displays problem collection view', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.collectProblem1,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show problem collection UI
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('SetupScreen - Finalized State', () {
    testWidgets('shows completion view when finalized', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          setupSessionProvider.overrideWith(
            (ref) => SetupSessionNotifier(ref)
              ..state = SetupSessionData(
                currentState: SetupState.finalized,
              ),
          ),
          hasInProgressSetupProvider.overrideWith(
            (ref) async => null,
          ),
          rememberedSetupAbstractionModeProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      // Should show completion state
      expect(find.textContaining('Complete'), findsWidgets);
    });
  });
}
