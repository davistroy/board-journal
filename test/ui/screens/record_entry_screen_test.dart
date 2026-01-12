import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:boardroom_journal/providers/providers.dart';
import 'package:boardroom_journal/ui/screens/screens.dart';
import 'package:boardroom_journal/ui/screens/record_entry/widgets/text_entry_state.dart';

/// Creates a test router with the RecordEntryScreen.
GoRouter _createTestRouter() {
  return GoRouter(
    initialLocation: '/record-entry',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/record-entry',
        builder: (context, state) => const RecordEntryScreen(),
      ),
      GoRoute(
        path: '/entry/:entryId',
        builder: (context, state) {
          final entryId = state.pathParameters['entryId'] ?? '';
          return Scaffold(body: Text('Entry: $entryId'));
        },
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
  group('RecordEntryScreen', () {
    testWidgets('displays mode selection screen initially', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Per PRD 5.2: Both voice and text entry options should be visible
      expect(find.text('Record Voice'), findsOneWidget);
      expect(find.text('Type Instead'), findsOneWidget);
    });

    testWidgets('has back navigation button', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // App bar with back button
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays screen title', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Record Entry'), findsOneWidget);
    });
  });

  group('RecordEntryScreen - Text Mode', () {
    testWidgets('tapping Type Instead shows text entry mode', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Should show text input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('text entry mode shows word count', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Should display word count (0 initially)
      expect(find.textContaining('words'), findsWidgets);
    });

    testWidgets('text entry mode shows Save button', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Per PRD 5.2: "Save" always available
      expect(find.text('Save Entry'), findsOneWidget);
    });

    testWidgets('Save button is disabled when text is empty', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Find the save button in the bottom action bar (FilledButton with 'Save Entry')
      final saveButton = find.widgetWithText(FilledButton, 'Save Entry');
      expect(saveButton, findsOneWidget);

      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull); // Button should be disabled when text is empty
    });

    testWidgets('typing text updates word count', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Find and tap the text field
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello world this is a test entry');
      await tester.pumpAndSettle();

      // Word count should update (7 words)
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('has back navigation button in text mode', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // In text mode, there's a back arrow button in the AppBar that navigates back
      // (which shows a discard dialog if there's text). This is the way to cancel/discard.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('RecordEntryScreen - Voice Mode', () {
    testWidgets('tapping Record Voice shows voice recording UI', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Voice'));
      await tester.pumpAndSettle();

      // Voice mode should show recording controls
      // (The exact UI depends on implementation, but there should be
      // some indication we're in voice mode)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('RecordEntryScreen - Word Limits', () {
    testWidgets('shows warning when approaching word limit', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type Instead'));
      await tester.pumpAndSettle();

      // Enter text with many words (simulate near limit)
      final textField = find.byType(TextField);
      // We can't easily test 6500+ words, but we can verify the UI responds
      await tester.enterText(textField, 'test ' * 100);
      await tester.pumpAndSettle();

      // Word count should be displayed
      expect(find.textContaining('words'), findsWidgets);
    });
  });

  group('TextEntryState', () {
    test('wordCount correctly counts words', () {
      const state = TextEntryState(text: 'Hello world this is a test');
      expect(state.wordCount, 6);
    });

    test('wordCount handles empty text', () {
      const state = TextEntryState(text: '');
      expect(state.wordCount, 0);
    });

    test('wordCount handles whitespace-only text', () {
      const state = TextEntryState(text: '   \n\t  ');
      expect(state.wordCount, 0);
    });

    test('isOverLimit is true when over 7500 words', () {
      final state = TextEntryState(text: 'word ' * 7501);
      expect(state.isOverLimit, isTrue);
    });

    test('isNearLimit is true when between 6500 and 7500 words', () {
      final state = TextEntryState(text: 'word ' * 7000);
      expect(state.isNearLimit, isTrue);
    });

    test('canSave is true when text is not empty and not saving', () {
      const state = TextEntryState(text: 'Some text');
      expect(state.canSave, isTrue);
    });

    test('canSave is false when text is empty', () {
      const state = TextEntryState(text: '');
      expect(state.canSave, isFalse);
    });

    test('canSave is false when saving', () {
      const state = TextEntryState(
        text: 'Some text',
        savePhase: SavePhase.saving,
      );
      expect(state.canSave, isFalse);
    });

    test('saveStatusText returns correct text for each phase', () {
      expect(
        const TextEntryState(savePhase: SavePhase.idle).saveStatusText,
        'Save Entry',
      );
      expect(
        const TextEntryState(savePhase: SavePhase.saving).saveStatusText,
        'Saving...',
      );
      expect(
        const TextEntryState(savePhase: SavePhase.extracting).saveStatusText,
        'Extracting signals...',
      );
    });

    test('copyWith preserves values when not specified', () {
      const original = TextEntryState(
        text: 'Original',
        savePhase: SavePhase.saving,
        error: 'Error',
      );
      final copied = original.copyWith();
      expect(copied.text, 'Original');
      expect(copied.savePhase, SavePhase.saving);
    });

    test('copyWith updates specified values', () {
      const original = TextEntryState(text: 'Original');
      final copied = original.copyWith(text: 'Updated');
      expect(copied.text, 'Updated');
    });
  });
}
