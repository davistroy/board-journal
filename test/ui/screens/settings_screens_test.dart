import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with settings screens.
GoRouter _createTestRouter({String initialLocation = '/settings/personas'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(body: Text('Settings')),
      ),
      GoRoute(
        path: '/settings/personas',
        builder: (context, state) => const PersonaEditorScreen(),
      ),
      GoRoute(
        path: '/settings/portfolio',
        builder: (context, state) => const PortfolioEditorScreen(),
      ),
      GoRoute(
        path: '/settings/versions',
        builder: (context, state) => const VersionHistoryScreen(),
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  String initialLocation = '/settings/personas',
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: _createTestRouter(initialLocation: initialLocation),
    ),
  );
}

void main() {
  group('PersonaEditorScreen', () {
    testWidgets('displays Board Personas title', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          boardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pump();

      expect(find.text('Board Personas'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          boardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has menu button with reset option', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          boardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows empty state when no board members', (tester) async {
      await tester.pumpWidget(createTestApp(
        overrides: [
          boardMembersStreamProvider.overrideWith(
            (ref) => Stream.value(<BoardMember>[]),
          ),
        ],
      ));

      await tester.pump();

      expect(find.textContaining('Setup'), findsWidgets);
    });
  });

  group('PortfolioEditorScreen', () {
    testWidgets('displays Portfolio title', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/portfolio',
        overrides: [
          problemsStreamProvider.overrideWith(
            (ref) => Stream.value(<Problem>[]),
          ),
          totalAllocationProvider.overrideWith(
            (ref) async => 0,
          ),
          allocationValidationProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.text('Edit Portfolio'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/portfolio',
        overrides: [
          problemsStreamProvider.overrideWith(
            (ref) => Stream.value(<Problem>[]),
          ),
          totalAllocationProvider.overrideWith(
            (ref) async => 0,
          ),
          allocationValidationProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows empty state when no problems defined', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/portfolio',
        overrides: [
          problemsStreamProvider.overrideWith(
            (ref) => Stream.value(<Problem>[]),
          ),
          totalAllocationProvider.overrideWith(
            (ref) async => 0,
          ),
          allocationValidationProvider.overrideWith(
            (ref) async => null,
          ),
        ],
      ));

      await tester.pump();

      expect(find.textContaining('Setup'), findsWidgets);
    });
  });

  group('VersionHistoryScreen', () {
    testWidgets('displays Version History title', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/versions',
        overrides: [
          allVersionsProvider.overrideWith(
            (ref) async => <PortfolioVersion>[],
          ),
        ],
      ));

      await tester.pump();

      expect(find.text('Version History'), findsOneWidget);
    });

    testWidgets('has back button', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/versions',
        overrides: [
          allVersionsProvider.overrideWith(
            (ref) async => <PortfolioVersion>[],
          ),
        ],
      ));

      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('shows empty state when no versions', (tester) async {
      await tester.pumpWidget(createTestApp(
        initialLocation: '/settings/versions',
        overrides: [
          allVersionsProvider.overrideWith(
            (ref) async => <PortfolioVersion>[],
          ),
        ],
      ));

      await tester.pump();

      expect(find.textContaining('Version'), findsWidgets);
    });
  });
}
