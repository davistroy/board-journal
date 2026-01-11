import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/ui/widgets/silence_countdown_widget.dart';

void main() {
  group('SilenceCountdownWidget', () {
    Widget createTestWidget({
      int silenceSeconds = 0,
      int silenceTimeout = 8,
      int countdownStart = 3,
      VoidCallback? onDismiss,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SilenceCountdownWidget(
            silenceSeconds: silenceSeconds,
            silenceTimeout: silenceTimeout,
            countdownStart: countdownStart,
            onDismiss: onDismiss,
          ),
        ),
      );
    }

    testWidgets('hides when silence is below countdown threshold',
        (tester) async {
      // 8 - 4 = 4 seconds remaining, countdown starts at 3
      await tester.pumpWidget(createTestWidget(silenceSeconds: 4));

      expect(find.text('Silence detected'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows when remaining seconds are within countdown threshold',
        (tester) async {
      // 8 - 6 = 2 seconds remaining, countdown starts at 3
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));

      expect(find.text('Silence detected'), findsOneWidget);
      expect(find.text('Tap anywhere to keep recording'), findsOneWidget);
    });

    testWidgets('displays correct remaining seconds', (tester) async {
      // 8 - 5 = 3 seconds remaining
      await tester.pumpWidget(createTestWidget(silenceSeconds: 5));
      expect(find.text('3'), findsOneWidget);

      // 8 - 6 = 2 seconds remaining
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // 8 - 7 = 1 second remaining
      await tester.pumpWidget(createTestWidget(silenceSeconds: 7));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('hides when remaining is 0 (timeout reached)', (tester) async {
      // 8 - 8 = 0 seconds remaining
      await tester.pumpWidget(createTestWidget(silenceSeconds: 8));

      expect(find.text('Silence detected'), findsNothing);
    });

    testWidgets('calls onDismiss when tapped', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(createTestWidget(
        silenceSeconds: 6,
        onDismiss: () => dismissed = true,
      ));

      await tester.tap(find.text('Silence detected'));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('respects custom silenceTimeout', (tester) async {
      // With timeout of 10, 10 - 8 = 2 remaining (should show countdown at 3)
      await tester.pumpWidget(createTestWidget(
        silenceSeconds: 8,
        silenceTimeout: 10,
        countdownStart: 3,
      ));

      expect(find.text('Silence detected'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('respects custom countdownStart', (tester) async {
      // With countdownStart of 5, should show at 8 - 4 = 4 remaining
      await tester.pumpWidget(createTestWidget(
        silenceSeconds: 4,
        silenceTimeout: 8,
        countdownStart: 5,
      ));

      expect(find.text('Silence detected'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('has error-themed container', (tester) async {
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));

      // Should have a decorated container
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });

  group('SilenceCountdownOverlay', () {
    Widget createTestWidget({
      int silenceSeconds = 0,
      int silenceTimeout = 8,
      int countdownStart = 3,
      VoidCallback? onDismiss,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Placeholder(),
              SilenceCountdownOverlay(
                silenceSeconds: silenceSeconds,
                silenceTimeout: silenceTimeout,
                countdownStart: countdownStart,
                onDismiss: onDismiss,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('hides when silence is below countdown threshold',
        (tester) async {
      await tester.pumpWidget(createTestWidget(silenceSeconds: 4));

      expect(find.text('Silence detected'), findsNothing);
      expect(find.text('Recording will stop automatically'), findsNothing);
    });

    testWidgets('shows fullscreen overlay when in countdown range',
        (tester) async {
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));

      expect(find.text('Silence detected'), findsOneWidget);
      expect(find.text('Recording will stop automatically'), findsOneWidget);
      expect(find.text('Tap anywhere to keep recording'), findsOneWidget);
    });

    testWidgets('displays large countdown number', (tester) async {
      // 8 - 6 = 2 seconds remaining
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('hides when timeout is reached', (tester) async {
      await tester.pumpWidget(createTestWidget(silenceSeconds: 8));

      expect(find.text('Silence detected'), findsNothing);
    });

    testWidgets('calls onDismiss when tapped', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(createTestWidget(
        silenceSeconds: 6,
        onDismiss: () => dismissed = true,
      ));

      // Tap on the overlay
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('has semi-transparent background', (tester) async {
      await tester.pumpWidget(createTestWidget(silenceSeconds: 6));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasOverlayBackground = containers.any((container) {
        return container.color == Colors.black54;
      });
      expect(hasOverlayBackground, isTrue);
    });

    testWidgets('respects custom timeout and countdown values', (tester) async {
      await tester.pumpWidget(createTestWidget(
        silenceSeconds: 12,
        silenceTimeout: 15,
        countdownStart: 5,
      ));

      // 15 - 12 = 3 remaining, within countdown of 5
      expect(find.text('Silence detected'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('SilenceIndicator', () {
    Widget createTestWidget({
      bool isSilent = false,
      int silenceSeconds = 0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SilenceIndicator(
            isSilent: isSilent,
            silenceSeconds: silenceSeconds,
          ),
        ),
      );
    }

    testWidgets('hides when not silent', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: false,
        silenceSeconds: 5,
      ));

      expect(find.byIcon(Icons.volume_off), findsNothing);
      expect(find.textContaining('Silence'), findsNothing);
    });

    testWidgets('hides when silent for less than 2 seconds', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 1,
      ));

      expect(find.byIcon(Icons.volume_off), findsNothing);
    });

    testWidgets('shows when silent for 2+ seconds', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 2,
      ));

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.text('Silence 2s'), findsOneWidget);
    });

    testWidgets('displays correct silence duration', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 5,
      ));

      expect(find.text('Silence 5s'), findsOneWidget);
    });

    testWidgets('updates display when silence seconds change', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 3,
      ));
      expect(find.text('Silence 3s'), findsOneWidget);

      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 4,
      ));
      await tester.pump();
      expect(find.text('Silence 4s'), findsOneWidget);
    });

    testWidgets('has volume_off icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 3,
      ));

      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('has tertiary container styling', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 3,
      ));

      // Should have a decorated container
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('hides immediately when silence ends', (tester) async {
      await tester.pumpWidget(createTestWidget(
        isSilent: true,
        silenceSeconds: 5,
      ));
      expect(find.text('Silence 5s'), findsOneWidget);

      await tester.pumpWidget(createTestWidget(
        isSilent: false,
        silenceSeconds: 0,
      ));
      await tester.pump();
      expect(find.textContaining('Silence'), findsNothing);
    });
  });
}
