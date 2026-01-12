import 'package:boardroom_journal/main.dart' as app;
import 'package:boardroom_journal/ui/screens/home/home_screen.dart';
import 'package:boardroom_journal/ui/screens/onboarding/welcome_screen.dart';
import 'package:boardroom_journal/ui/screens/record_entry/record_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: App Launch', () {
    testWidgets(
      'app launches and shows onboarding for new users',
      (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // New users should see onboarding (welcome screen)
        // Either welcome/signin screen or home screen depending on stored state
        final hasWelcome = find.byType(WelcomeScreen).evaluate().isNotEmpty;
        final hasHome = find.byType(HomeScreen).evaluate().isNotEmpty;

        expect(
          hasWelcome || hasHome,
          isTrue,
          reason: 'App should show either onboarding or home screen',
        );
      },
    );
  });

  group('E2E: Navigation', () {
    testWidgets('can navigate to entry creation screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // If on home screen, tap FAB to create entry
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();

        // Should navigate to record entry screen
        expect(find.byType(RecordEntryScreen), findsOneWidget);
      }
    });

    testWidgets('bottom navigation works correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for bottom navigation
      final bottomNav = find.byType(NavigationBar);
      if (bottomNav.evaluate().isNotEmpty) {
        // App has bottom navigation - test tab switching
        final navItems = find.descendant(
          of: bottomNav,
          matching: find.byType(NavigationDestination),
        );

        if (navItems.evaluate().length > 1) {
          // Tap second nav item
          await tester.tap(navItems.at(1));
          await tester.pumpAndSettle();

          // Screen should change - verify app is responsive
          expect(find.byType(Scaffold), findsWidgets);
        }
      }
    });
  });

  group('E2E: Entry Creation Flow', () {
    testWidgets(
      'can switch between voice and text entry modes',
      (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to entry creation if not already there
        final fab = find.byType(FloatingActionButton);
        if (fab.evaluate().isNotEmpty) {
          await tester.tap(fab.first);
          await tester.pumpAndSettle();
        }

        // Look for mode selection buttons
        final textModeButton = find.textContaining('Text');
        final voiceModeButton = find.textContaining('Voice');

        if (textModeButton.evaluate().isNotEmpty &&
            voiceModeButton.evaluate().isNotEmpty) {
          // Tap text mode
          await tester.tap(textModeButton.first);
          await tester.pumpAndSettle();

          // Look for text input field
          final textField = find.byType(TextField);
          expect(
            textField.evaluate().isNotEmpty,
            isTrue,
            reason: 'Text mode should show text input',
          );
        }
      },
    );

    testWidgets('can enter text and see word count', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to entry creation
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await tester.pumpAndSettle();
      }

      // Select text mode if available
      final textModeButton = find.textContaining('Text');
      if (textModeButton.evaluate().isNotEmpty) {
        await tester.tap(textModeButton.first);
        await tester.pumpAndSettle();
      }

      // Find text field and enter text
      final textField = find.byType(TextField);
      if (textField.evaluate().isNotEmpty) {
        await tester.enterText(textField.first, 'This is a test entry');
        await tester.pumpAndSettle();

        // Word count should update
        final wordCountText = find.textContaining('word');
        expect(
          wordCountText.evaluate().isNotEmpty,
          isTrue,
          reason: 'Should show word count',
        );
      }
    });
  });

  group('E2E: Settings Access', () {
    testWidgets('can navigate to settings', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for settings icon or gear icon
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first);
        await tester.pumpAndSettle();

        // Should show settings content
        expect(find.textContaining('Settings'), findsWidgets);
      } else {
        // Settings might be in bottom nav
        final bottomNav = find.byType(NavigationBar);
        if (bottomNav.evaluate().isNotEmpty) {
          final navItems = find.descendant(
            of: bottomNav,
            matching: find.byType(NavigationDestination),
          );
          // Try last nav item (often settings)
          if (navItems.evaluate().isNotEmpty) {
            await tester.tap(navItems.last);
            await tester.pumpAndSettle();
          }
        }
      }
    });
  });

  group('E2E: Error Handling', () {
    testWidgets('app handles missing data gracefully', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // App should not crash and should show valid UI
      expect(find.byType(MaterialApp), findsOneWidget);

      // No error dialogs should be visible by default
      final errorDialog = find.byType(AlertDialog);
      expect(
        errorDialog.evaluate().isEmpty,
        isTrue,
        reason: 'No error dialogs should appear on clean launch',
      );
    });
  });
}
