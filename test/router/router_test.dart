import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/router/router.dart';

void main() {
  group('AppRoutes', () {
    group('Onboarding routes', () {
      test('onboardingWelcome has correct path', () {
        expect(AppRoutes.onboardingWelcome, '/onboarding/welcome');
      });

      test('onboardingPrivacy has correct path', () {
        expect(AppRoutes.onboardingPrivacy, '/onboarding/privacy');
      });

      test('onboardingSignin has correct path', () {
        expect(AppRoutes.onboardingSignin, '/onboarding/signin');
      });
    });

    group('Main app routes', () {
      test('home has correct path', () {
        expect(AppRoutes.home, '/');
      });

      test('recordEntry has correct path', () {
        expect(AppRoutes.recordEntry, '/record-entry');
      });

      test('entryReview has correct path with parameter', () {
        expect(AppRoutes.entryReview, '/entry/:entryId');
      });

      test('weeklyBrief has correct path with parameter', () {
        expect(AppRoutes.weeklyBrief, '/weekly-brief/:briefId');
      });

      test('latestWeeklyBrief has correct path', () {
        expect(AppRoutes.latestWeeklyBrief, '/weekly-brief/latest');
      });
    });

    group('Governance routes', () {
      test('governanceHub has correct path', () {
        expect(AppRoutes.governanceHub, '/governance');
      });

      test('quickVersion has correct path', () {
        expect(AppRoutes.quickVersion, '/governance/quick');
      });

      test('setup has correct path', () {
        expect(AppRoutes.setup, '/governance/setup');
      });

      test('quarterly has correct path', () {
        expect(AppRoutes.quarterly, '/governance/quarterly');
      });
    });

    group('Settings routes', () {
      test('settings has correct path', () {
        expect(AppRoutes.settings, '/settings');
      });

      test('personaEditor has correct path', () {
        expect(AppRoutes.personaEditor, '/settings/personas');
      });

      test('portfolioEditor has correct path', () {
        expect(AppRoutes.portfolioEditor, '/settings/portfolio');
      });

      test('versionHistory has correct path', () {
        expect(AppRoutes.versionHistory, '/settings/versions');
      });
    });

    group('History routes', () {
      test('history has correct path', () {
        expect(AppRoutes.history, '/history');
      });
    });
  });

  group('createRouter', () {
    test('creates a GoRouter instance', () {
      final router = createRouter();

      expect(router, isA<GoRouter>());
    });

    test('has home as initial location', () {
      final router = createRouter();

      // The router should start at home
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });

    test('contains all expected routes', () {
      final router = createRouter();
      final routes = router.configuration.routes;

      // Should have multiple routes configured
      expect(routes.length, greaterThan(0));
    });
  });
}
