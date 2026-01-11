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
  SetupSessionState? initialState,
  List<Override> overrides = const [],
}) {
  final allOverrides = <Override>[
    // Override the setupSessionProvider with initial state
    if (initialState != null)
      setupSessionProvider.overrideWith(
        () => _TestSetupSessionNotifier(initialState),
      ),
    hasInProgressSetupProvider.overrideWith(
      (ref) async => null,
    ),
    rememberedSetupAbstractionModeProvider.overrideWith(
      (ref) async => null,
    ),
    // Override the setup service to prevent actual initialization
    setupServiceProvider.overrideWith(
      (ref) => null,
    ),
    ...overrides,
  ];

  return ProviderScope(
    overrides: allOverrides,
    child: MaterialApp.router(
      routerConfig: _createTestRouter(),
    ),
  );
}

/// Test notifier that returns a fixed state and prevents initialization.
class _TestSetupSessionNotifier extends SetupSessionNotifier {
  final SetupSessionState _initialState;

  _TestSetupSessionNotifier(this._initialState);

  @override
  SetupSessionState build() => _initialState;

  // Override methods to prevent actual operations
  @override
  Future<void> startSession({bool? abstractionMode}) async {}

  @override
  Future<void> resumeSession(String sessionId) async {}
}

void main() {
  group('SetupScreen', () {
    testWidgets('displays initial state in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          data: SetupSessionData(
            currentState: SetupState.sensitivityGate,
          ),
        ),
      ));

      await tester.pump();

      // Should show the current state name
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialState: const SetupSessionState(
          data: SetupSessionData(
            currentState: SetupState.initial,
          ),
          isLoading: true,
        ),
      ));

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has close button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          data: SetupSessionData(
            currentState: SetupState.sensitivityGate,
          ),
        ),
      ));

      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows progress percentage when active', (tester) async {
      // isActive requires sessionId != null and state not finalized/abandoned
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          sessionId: 'test-session',
          data: SetupSessionData(
            currentState: SetupState.collectProblem1,
          ),
        ),
      ));

      await tester.pump();

      // Should show progress indicator
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('SetupScreen - Sensitivity Gate', () {
    testWidgets('displays sensitivity gate options', (tester) async {
      // Need sessionId for isActive to be true and isConfigured to be true
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          sessionId: 'test-session',
          data: SetupSessionData(
            currentState: SetupState.sensitivityGate,
          ),
          isConfigured: true,
        ),
      ));

      await tester.pump();

      // Should show abstraction mode toggle - the text is 'Abstraction Mode'
      expect(find.text('Abstraction Mode'), findsOneWidget);
    });
  });

  group('SetupScreen - Exit Confirmation', () {
    testWidgets('close button shows exit confirmation', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          sessionId: 'test-session',
          data: SetupSessionData(
            currentState: SetupState.collectProblem1,
          ),
        ),
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
      // Need sessionId for isActive and isConfigured for the view to render
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          sessionId: 'test-session',
          data: SetupSessionData(
            currentState: SetupState.collectProblem1,
          ),
          isConfigured: true,
        ),
      ));

      await tester.pump();

      // ProblemFormView uses TextFormField widgets which are built on TextField
      expect(find.byType(TextFormField), findsWidgets);
    });
  });

  group('SetupScreen - Finalized State', () {
    testWidgets('shows completion view when finalized', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialState: SetupSessionState(
          sessionId: 'test-session',
          data: SetupSessionData(
            currentState: SetupState.finalized,
          ),
          isConfigured: true,
        ),
      ));

      await tester.pump();

      // Should show completion state - 'Setup Complete' is the actual text
      expect(find.text('Setup Complete'), findsOneWidget);
    });
  });
}
