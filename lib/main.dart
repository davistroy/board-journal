import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'models/models.dart';
import 'providers/providers.dart';
import 'router/router.dart';
import 'services/scheduling/scheduling.dart';
import 'ui/screens/screens.dart';
import 'ui/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data for scheduling
  tz.initializeTimeZones();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize the brief scheduler
  await _initializeScheduler();

  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BoardroomJournalApp(),
    ),
  );
}

/// Initializes the brief scheduler service.
///
/// Sets up workmanager and schedules the weekly brief generation task.
Future<void> _initializeScheduler() async {
  try {
    final scheduler = BriefSchedulerService();
    await scheduler.initialize(callbackDispatcher);
    await scheduler.scheduleWeeklyBrief();
  } catch (e) {
    // Log error but don't crash the app
    debugPrint('Failed to initialize brief scheduler: $e');
  }
}

class BoardroomJournalApp extends ConsumerStatefulWidget {
  const BoardroomJournalApp({super.key});

  @override
  ConsumerState<BoardroomJournalApp> createState() => _BoardroomJournalAppState();
}

class _BoardroomJournalAppState extends ConsumerState<BoardroomJournalApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _createAuthAwareRouter();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for missed briefs when app resumes (important for iOS)
      _checkForMissedBriefs();
    }
  }

  /// Checks if a brief generation was missed while app was in background.
  ///
  /// This is especially important for iOS where background tasks
  /// may not execute reliably.
  Future<void> _checkForMissedBriefs() async {
    try {
      final scheduler = BriefSchedulerService();
      final wasRescheduled = await scheduler.checkAndReschedule();
      if (wasRescheduled) {
        debugPrint('Brief schedule was updated after app resume');
      }
    } catch (e) {
      debugPrint('Failed to check for missed briefs: $e');
    }
  }

  /// Creates a router with auth-aware redirect logic.
  GoRouter _createAuthAwareRouter() {
    return GoRouter(
      initialLocation: AppRoutes.home,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final authState = ref.read(authNotifierProvider);
        final currentPath = state.uri.path;

        // Onboarding paths
        final isOnboardingPath = currentPath.startsWith('/onboarding');

        // Still initializing - don't redirect yet
        if (authState.status == AuthStatus.initial ||
            authState.status == AuthStatus.loading) {
          return null;
        }

        // Not onboarded yet - redirect to welcome (unless already on onboarding)
        if (!authState.onboardingCompleted) {
          if (!isOnboardingPath) {
            return AppRoutes.onboardingWelcome;
          }
          return null;
        }

        // Onboarded - redirect away from onboarding screens
        if (isOnboardingPath && authState.onboardingCompleted) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        // Onboarding routes
        GoRoute(
          path: AppRoutes.onboardingWelcome,
          name: 'onboardingWelcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingPrivacy,
          name: 'onboardingPrivacy',
          builder: (context, state) => const PrivacyScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboardingSignin,
          name: 'onboardingSignin',
          builder: (context, state) => const SigninScreen(),
        ),

        // Main app routes
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
          path: AppRoutes.personaEditor,
          name: 'personaEditor',
          builder: (context, state) => const PersonaEditorScreen(),
        ),
        GoRoute(
          path: AppRoutes.portfolioEditor,
          name: 'portfolioEditor',
          builder: (context, state) => const PortfolioEditorScreen(),
        ),
        GoRoute(
          path: AppRoutes.versionHistory,
          name: 'versionHistory',
          builder: (context, state) => const VersionHistoryScreen(),
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

  @override
  Widget build(BuildContext context) {
    // Watch auth state to trigger rebuilds on auth changes
    ref.watch(authNotifierProvider);

    return MaterialApp.router(
      title: 'Boardroom Journal',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // Follow system setting per PRD
      routerConfig: _router,
    );
  }
}
