import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/screens.dart';

/// Route path constants for type-safe navigation.
abstract class AppRoutes {
  static const home = '/';
  static const recordEntry = '/record-entry';
  static const entryReview = '/entry/:entryId';
  static const weeklyBrief = '/weekly-brief/:briefId';
  static const latestWeeklyBrief = '/weekly-brief/latest';
  static const governanceHub = '/governance';
  static const quickVersion = '/governance/quick';
  static const setup = '/governance/setup';
  static const quarterly = '/governance/quarterly';
  static const settings = '/settings';
  static const history = '/history';
}

/// Creates the app router configuration.
///
/// Uses go_router for declarative routing with deep linking support.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.recordEntry,
        name: 'recordEntry',
        builder: (context, state) => const RecordEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.entryReview,
        name: 'entryReview',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId']!;
          return EntryReviewScreen(entryId: entryId);
        },
      ),
      GoRoute(
        path: AppRoutes.latestWeeklyBrief,
        name: 'latestWeeklyBrief',
        builder: (context, state) => const WeeklyBriefViewerScreen(),
      ),
      GoRoute(
        path: AppRoutes.weeklyBrief,
        name: 'weeklyBrief',
        builder: (context, state) {
          final briefId = state.pathParameters['briefId']!;
          return WeeklyBriefViewerScreen(briefId: briefId);
        },
      ),
      GoRoute(
        path: AppRoutes.governanceHub,
        name: 'governanceHub',
        builder: (context, state) => const GovernanceHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.quickVersion,
        name: 'quickVersion',
        builder: (context, state) => const QuickVersionScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.quarterly,
        name: 'quarterly',
        builder: (context, state) => const QuarterlyScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
