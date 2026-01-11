import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

import 'package:boardroom_journal/providers/settings_providers.dart';
import 'package:boardroom_journal/services/services.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';

/// Creates a test router with the SettingsScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/personas',
        builder: (context, state) => const Scaffold(body: Text('Personas')),
      ),
      GoRoute(
        path: '/settings/portfolio',
        builder: (context, state) => const Scaffold(body: Text('Portfolio')),
      ),
      GoRoute(
        path: '/settings/versions',
        builder: (context, state) => const Scaffold(body: Text('Versions')),
      ),
    ],
  );
}

/// Test StateNotifier that returns fixed async value for abstraction mode.
class _TestAbstractionModeNotifier extends AbstractionModeNotifier {
  final AsyncValue<bool> _initialState;

  _TestAbstractionModeNotifier(bool initialValue)
      : _initialState = AsyncValue.data(initialValue),
        super(FakePrivacyService(), FakeRef());

  @override
  Future<void> _load() async {
    state = _initialState;
  }

  @override
  Future<void> toggle() async {
    state = AsyncValue.data(!(state.valueOrNull ?? false));
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    state = AsyncValue.data(enabled);
  }
}

/// Test StateNotifier that returns fixed async value for analytics.
class _TestAnalyticsNotifier extends AnalyticsNotifier {
  final AsyncValue<bool> _initialState;

  _TestAnalyticsNotifier(bool initialValue)
      : _initialState = AsyncValue.data(initialValue),
        super(FakePrivacyService(), FakeRef());

  @override
  Future<void> _load() async {
    state = _initialState;
  }

  @override
  Future<void> toggle() async {
    state = AsyncValue.data(!(state.valueOrNull ?? true));
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    state = AsyncValue.data(enabled);
  }
}

/// Fake PrivacyService for testing
class FakePrivacyService extends Fake implements PrivacyService {}

/// Fake Ref for testing
class FakeRef extends Fake implements Ref {}

/// Wraps a widget with all necessary providers for testing.
Widget createTestApp({
  bool abstractionMode = false,
  bool analyticsEnabled = true,
  List<Override> overrides = const [],
}) {
  final allOverrides = <Override>[
    abstractionModeNotifierProvider.overrideWith(
      (ref) => _TestAbstractionModeNotifier(abstractionMode),
    ),
    analyticsNotifierProvider.overrideWith(
      (ref) => _TestAnalyticsNotifier(analyticsEnabled),
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

void main() {
  group('SettingsScreen', () {
    testWidgets('displays Settings title in app bar', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('displays Account section', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Sign-in Methods'), findsOneWidget);
    });

    testWidgets('displays Privacy section with abstraction toggle', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Abstraction Mode'), findsOneWidget);
    });

    testWidgets('displays Data section with export/import options', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Export All Data'), findsOneWidget);
    });

    testWidgets('displays Board section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Board Personas'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('displays Portfolio section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('displays About section', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Scroll down to About section
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('has scrollable content', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('back button navigates to home', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows delete account option in Account section', (tester) async {
      await tester.pumpWidget(createTestApp());

      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('7-day grace period'), findsOneWidget);
    });
  });
}
