import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/data/enums/signal_type.dart';
import 'package:boardroom_journal/services/ai/models/extracted_signal.dart';
import 'package:boardroom_journal/ui/widgets/signal_list_widget.dart';

void main() {
  Widget createTestWidget({
    required ExtractedSignals signals,
    bool isExtracting = false,
    VoidCallback? onReExtract,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SignalListWidget(
            signals: signals,
            isExtracting: isExtracting,
            onReExtract: onReExtract,
          ),
        ),
      ),
    );
  }

  group('SignalListWidget', () {
    testWidgets('displays empty state when no signals', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signals: const ExtractedSignals([]),
      ));

      expect(find.text('No signals extracted yet'), findsOneWidget);
      expect(find.text('Extracted Signals'), findsOneWidget);
    });

    testWidgets('displays extract button in empty state when callback provided',
        (tester) async {
      var extractCalled = false;

      await tester.pumpWidget(createTestWidget(
        signals: const ExtractedSignals([]),
        onReExtract: () => extractCalled = true,
      ));

      expect(find.text('Extract Signals'), findsOneWidget);

      await tester.tap(find.text('Extract Signals'));
      await tester.pump();

      expect(extractCalled, isTrue);
    });

    testWidgets('displays signals grouped by type', (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Completed the project'),
        ExtractedSignal(type: SignalType.wins, text: 'Got promoted'),
        ExtractedSignal(type: SignalType.blockers, text: 'Budget constraints'),
        ExtractedSignal(type: SignalType.actions, text: 'Schedule meeting'),
      ]);

      await tester.pumpWidget(createTestWidget(signals: signals));

      // Check signal type headers
      expect(find.text('Wins'), findsOneWidget);
      expect(find.text('Blockers'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);

      // Check signal content
      expect(find.text('Completed the project'), findsOneWidget);
      expect(find.text('Got promoted'), findsOneWidget);
      expect(find.text('Budget constraints'), findsOneWidget);
      expect(find.text('Schedule meeting'), findsOneWidget);
    });

    testWidgets('displays total count in header', (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
      ]);

      await tester.pumpWidget(createTestWidget(signals: signals));

      expect(find.text('3'), findsAtLeast(1));
    });

    testWidgets('displays re-extract button when callback provided',
        (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
      ]);

      await tester.pumpWidget(createTestWidget(
        signals: signals,
        onReExtract: () {},
      ));

      expect(find.text('Re-extract'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('re-extract button triggers callback', (tester) async {
      var extractCalled = false;
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
      ]);

      await tester.pumpWidget(createTestWidget(
        signals: signals,
        onReExtract: () => extractCalled = true,
      ));

      await tester.tap(find.text('Re-extract'));
      await tester.pump();

      expect(extractCalled, isTrue);
    });

    testWidgets('shows loading state when extracting', (tester) async {
      await tester.pumpWidget(createTestWidget(
        signals: const ExtractedSignals([]),
        isExtracting: true,
      ));

      expect(find.text('Extracting signals...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('disables re-extract button when extracting', (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
      ]);
      var extractCalled = false;

      await tester.pumpWidget(createTestWidget(
        signals: signals,
        isExtracting: true,
        onReExtract: () => extractCalled = true,
      ));

      expect(find.text('Extracting...'), findsOneWidget);

      // Button should be disabled
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('does not show empty signal types', (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
      ]);

      await tester.pumpWidget(createTestWidget(signals: signals));

      expect(find.text('Wins'), findsOneWidget);
      expect(find.text('Blockers'), findsNothing);
      expect(find.text('Risks'), findsNothing);
      expect(find.text('Actions'), findsNothing);
    });

    testWidgets('displays all 7 signal types when present', (tester) async {
      final signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker'),
        ExtractedSignal(type: SignalType.risks, text: 'Risk'),
        ExtractedSignal(type: SignalType.avoidedDecision, text: 'Avoided'),
        ExtractedSignal(type: SignalType.comfortWork, text: 'Comfort'),
        ExtractedSignal(type: SignalType.actions, text: 'Action'),
        ExtractedSignal(type: SignalType.learnings, text: 'Learning'),
      ]);

      await tester.pumpWidget(createTestWidget(signals: signals));

      expect(find.text('Wins'), findsOneWidget);
      expect(find.text('Blockers'), findsOneWidget);
      expect(find.text('Risks'), findsOneWidget);
      expect(find.text('Avoided Decision'), findsOneWidget);
      expect(find.text('Comfort Work'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Learnings'), findsOneWidget);
    });
  });

  group('SignalSummaryChip', () {
    testWidgets('displays count with icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalSummaryChip(
              type: SignalType.wins,
              count: 5,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('returns empty widget when count is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalSummaryChip(
              type: SignalType.wins,
              count: 0,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('displays correct icon for each signal type', (tester) async {
      final iconMap = {
        SignalType.wins: Icons.emoji_events_outlined,
        SignalType.blockers: Icons.block_outlined,
        SignalType.risks: Icons.warning_amber_outlined,
        SignalType.avoidedDecision: Icons.hourglass_empty_outlined,
        SignalType.comfortWork: Icons.beach_access_outlined,
        SignalType.actions: Icons.task_alt_outlined,
        SignalType.learnings: Icons.lightbulb_outline,
      };

      for (final entry in iconMap.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SignalSummaryChip(
                type: entry.key,
                count: 1,
              ),
            ),
          ),
        );

        expect(
          find.byIcon(entry.value),
          findsOneWidget,
          reason: 'Expected icon for ${entry.key}',
        );
      }
    });
  });
}
