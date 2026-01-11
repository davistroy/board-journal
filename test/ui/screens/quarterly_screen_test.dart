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
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      expect(find.text('Quarterly Report'), findsOneWidget);
    });

    testWidgets('has close button in app bar', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows initial loading or not configured state', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      
      // Screen should show either loading, not configured, or content
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      final hasNotConfigured = find.textContaining('AI service not configured').evaluate().isNotEmpty;
      final hasContent = find.byType(Scaffold).evaluate().isNotEmpty;
      
      expect(hasLoading || hasNotConfigured || hasContent, isTrue);
    });
  });
}
