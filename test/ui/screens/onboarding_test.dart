import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/auth_providers.dart';
import 'package:boardroom_journal/services/auth/token_storage.dart';
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
  return ProviderScope(
    overrides: [
      // Override tokenStorageProvider to avoid platform plugin calls
      tokenStorageProvider.overrideWithValue(TokenStorage.forTesting()),
    ],
    child: MaterialApp.router(
      routerConfig: _createTestRouter(initialLocation: initialLocation),
    ),
  );
}

/// Sets up a larger screen size for tests that need more space.
void setLargeScreenSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
}

/// Resets the screen size after a test.
void resetScreenSize(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

/// Helper to pump widget and wait for animations.
/// Uses pump with duration instead of pumpAndSettle to handle stagger animations.
Future<void> pumpWithAnimations(WidgetTester tester, {int frames = 15}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('WelcomeScreen', () {
    testWidgets('displays app name', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      // Updated: app name is split across two lines
      expect(find.text('Boardroom'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('displays tagline', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      expect(find.text('Your AI-Powered Board of Directors'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('displays value propositions', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      expect(find.text('Voice-First Journaling'), findsOneWidget);
      expect(find.text('Weekly Executive Briefs'), findsOneWidget);
      expect(find.text('Career Governance'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has Get Started button', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      expect(find.text('Get Started'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('Get Started navigates to privacy screen', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      await tester.tap(find.text('Get Started'));
      await pumpWithAnimations(tester);
      expect(find.byType(PrivacyScreen), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('displays app icon', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      resetScreenSize(tester);
    });
  });

  group('PrivacyScreen', () {
    testWidgets('displays Privacy and Terms title', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & Terms'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('displays privacy info', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Your Privacy Matters'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has Continue button', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has back navigation', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/privacy'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has Terms and Privacy links', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      resetScreenSize(tester);
    });
  });

  group('SigninScreen', () {
    testWidgets('displays Sign In title', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/signin'));
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('displays OAuth provider buttons', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/signin'));
      await tester.pumpAndSettle();
      // Google and Microsoft are always shown
      expect(find.textContaining('Google'), findsOneWidget);
      expect(find.textContaining('Microsoft'), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has back navigation', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/signin'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      resetScreenSize(tester);
    });

    testWidgets('has skip option', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp(initialLocation: '/onboarding/signin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Skip for now'), findsOneWidget);
      resetScreenSize(tester);
    });
  });

  group('Onboarding Flow', () {
    testWidgets('welcome to privacy flow works', (tester) async {
      setLargeScreenSize(tester);
      await tester.pumpWidget(createTestApp());
      await pumpWithAnimations(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await pumpWithAnimations(tester);
      expect(find.byType(PrivacyScreen), findsOneWidget);
      resetScreenSize(tester);
    });
  });
}
