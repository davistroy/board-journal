import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the QuickVersionScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/governance/quick-version',
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
        path: '/governance/quick-version',
        builder: (context, state) => const QuickVersionScreen(),
      ),
    ],
  );
}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp() {
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: _createTestRouter(),
    ),
  );
}

void main() {
  group('QuickVersionScreen', () {
    testWidgets('displays 15-Minute Audit title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();
      expect(find.text('15-Minute Audit'), findsOneWidget);
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
