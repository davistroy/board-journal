import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with onboarding screens.
GoRouter _createTestRouter({String initialLocation = '/onboarding/welcome'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/onboarding/signin',
        builder: (context, state) => const SigninScreen(),
      ),
    ],
  );
}

/// Wraps a widget with MaterialApp.router for testing.
Widget createTestApp({String initialLocation = '/onboarding/welcome'}) {
  return MaterialApp.router(
    routerConfig: _createTestRouter(initialLocation: initialLocation),
  );
}

void main() {
  group('WelcomeScreen', () {
    testWidgets('displays app name', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Boardroom Journal'), findsOneWidget);
    });

    testWidgets('displays tagline', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Your AI-Powered Board of Directors'), findsOneWidget);
    });

    testWidgets('displays value propositions', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Voice-First Journaling'), findsOneWidget);
      expect(find.text('Weekly Executive Briefs'), findsOneWidget);
      expect(find.text('Career Governance'), findsOneWidget);
    });

    testWidgets('has Get Started button', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('Get Started navigates to privacy screen', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Should navigate to privacy screen
      expect(find.byType(PrivacyScreen), findsOneWidget);
    });

    testWidgets('displays app icon', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    });
  });

  group('PrivacyScreen', () {
    testWidgets('displays Privacy & Security title', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/privacy'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Security'), findsOneWidget);
    });

    testWidgets('displays privacy commitments', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/privacy'),
      );
      await tester.pumpAndSettle();

      // Should show key privacy points
      expect(find.textContaining('No AI Training'), findsOneWidget);
      expect(find.textContaining('Audio Deleted'), findsOneWidget);
      expect(find.textContaining('Encrypted'), findsOneWidget);
    });

    testWidgets('has Continue button', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/privacy'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('has back navigation', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/privacy'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('has Terms and Privacy links', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/privacy'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });

  group('SigninScreen', () {
    testWidgets('displays Sign In title', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/signin'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('displays OAuth provider buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/signin'),
      );
      await tester.pumpAndSettle();

      // Should show all OAuth options per PRD
      expect(find.textContaining('Apple'), findsOneWidget);
      expect(find.textContaining('Google'), findsOneWidget);
      expect(find.textContaining('Microsoft'), findsOneWidget);
    });

    testWidgets('has back navigation', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/signin'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays account linking note', (tester) async {
      await tester.pumpWidget(
        createTestApp(initialLocation: '/onboarding/signin'),
      );
      await tester.pumpAndSettle();

      // Should explain email-based account linking
      expect(find.textContaining('email'), findsWidgets);
    });
  });

  group('Onboarding Flow', () {
    testWidgets('complete onboarding flow navigates correctly', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Start on Welcome
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Should be on Privacy
      expect(find.byType(PrivacyScreen), findsOneWidget);

      // Tap Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should be on Sign In
      expect(find.byType(SigninScreen), findsOneWidget);
    });
  });
}
