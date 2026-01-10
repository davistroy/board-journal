import 'package:boardroom_journal/data/enums/signal_type.dart';
import 'package:boardroom_journal/services/ai/models/extracted_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtractedSignal', () {
    test('creates signal with required fields', () {
      const signal = ExtractedSignal(
        type: SignalType.wins,
        text: 'Completed the project',
      );

      expect(signal.type, SignalType.wins);
      expect(signal.text, 'Completed the project');
      expect(signal.confidence, isNull);
    });

    test('creates signal with optional confidence', () {
      const signal = ExtractedSignal(
        type: SignalType.blockers,
        text: 'Waiting on approval',
        confidence: 0.95,
      );

      expect(signal.type, SignalType.blockers);
      expect(signal.text, 'Waiting on approval');
      expect(signal.confidence, 0.95);
    });

    test('converts to JSON', () {
      const signal = ExtractedSignal(
        type: SignalType.actions,
        text: 'Follow up with team',
        confidence: 0.8,
      );

      final json = signal.toJson();

      expect(json['type'], 'actions');
      expect(json['text'], 'Follow up with team');
      expect(json['confidence'], 0.8);
    });

    test('converts to JSON without confidence', () {
      const signal = ExtractedSignal(
        type: SignalType.learnings,
        text: 'Important insight',
      );

      final json = signal.toJson();

      expect(json['type'], 'learnings');
      expect(json['text'], 'Important insight');
      expect(json.containsKey('confidence'), isFalse);
    });

    test('creates from JSON', () {
      final json = {
        'type': 'risks',
        'text': 'Potential delay',
        'confidence': 0.75,
      };

      final signal = ExtractedSignal.fromJson(json);

      expect(signal.type, SignalType.risks);
      expect(signal.text, 'Potential delay');
      expect(signal.confidence, 0.75);
    });

    test('creates from JSON without confidence', () {
      final json = {
        'type': 'wins',
        'text': 'Success!',
      };

      final signal = ExtractedSignal.fromJson(json);

      expect(signal.type, SignalType.wins);
      expect(signal.text, 'Success!');
      expect(signal.confidence, isNull);
    });

    test('handles unknown signal type gracefully', () {
      final json = {
        'type': 'unknown_type',
        'text': 'Some text',
      };

      final signal = ExtractedSignal.fromJson(json);

      // Falls back to learnings
      expect(signal.type, SignalType.learnings);
    });

    test('equality comparison', () {
      const signal1 = ExtractedSignal(
        type: SignalType.wins,
        text: 'Same text',
        confidence: 0.9,
      );
      const signal2 = ExtractedSignal(
        type: SignalType.wins,
        text: 'Same text',
        confidence: 0.9,
      );
      const signal3 = ExtractedSignal(
        type: SignalType.wins,
        text: 'Different text',
        confidence: 0.9,
      );

      expect(signal1, equals(signal2));
      expect(signal1, isNot(equals(signal3)));
    });
  });

  group('ExtractedSignals', () {
    test('creates from list of signals', () {
      const signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
      ]);

      expect(signals.totalCount, 3);
      expect(signals.isEmpty, isFalse);
      expect(signals.isNotEmpty, isTrue);
    });

    test('creates empty collection', () {
      const signals = ExtractedSignals([]);

      expect(signals.totalCount, 0);
      expect(signals.isEmpty, isTrue);
      expect(signals.isNotEmpty, isFalse);
    });

    test('filters by type', () {
      const signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
        ExtractedSignal(type: SignalType.actions, text: 'Action 1'),
      ]);

      final wins = signals.byType(SignalType.wins);
      expect(wins.length, 2);
      expect(wins.every((s) => s.type == SignalType.wins), isTrue);

      final blockers = signals.byType(SignalType.blockers);
      expect(blockers.length, 1);

      final risks = signals.byType(SignalType.risks);
      expect(risks.length, 0);
    });

    test('counts by type', () {
      const signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
      ]);

      expect(signals.countByType(SignalType.wins), 2);
      expect(signals.countByType(SignalType.blockers), 1);
      expect(signals.countByType(SignalType.risks), 0);
    });

    test('gets counts by type map', () {
      const signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
        ExtractedSignal(type: SignalType.learnings, text: 'Learning 1'),
      ]);

      final counts = signals.countsByType;

      expect(counts[SignalType.wins], 2);
      expect(counts[SignalType.blockers], 1);
      expect(counts[SignalType.learnings], 1);
      expect(counts.containsKey(SignalType.risks), isFalse);
    });

    test('converts to JSON', () {
      const signals = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Win 1'),
        ExtractedSignal(type: SignalType.wins, text: 'Win 2'),
        ExtractedSignal(type: SignalType.blockers, text: 'Blocker 1'),
      ]);

      final json = signals.toJson();

      expect(json['wins'], ['Win 1', 'Win 2']);
      expect(json['blockers'], ['Blocker 1']);
      expect(json.containsKey('risks'), isFalse);
    });

    test('creates from JSON with string arrays', () {
      final json = {
        'wins': ['Win 1', 'Win 2'],
        'blockers': ['Blocker 1'],
        'actions': ['Action 1', 'Action 2', 'Action 3'],
      };

      final signals = ExtractedSignals.fromJson(json);

      expect(signals.totalCount, 6);
      expect(signals.countByType(SignalType.wins), 2);
      expect(signals.countByType(SignalType.blockers), 1);
      expect(signals.countByType(SignalType.actions), 3);
    });

    test('creates from JSON with object arrays', () {
      final json = {
        'wins': [
          {'text': 'Win 1', 'confidence': 0.9},
          {'text': 'Win 2', 'confidence': 0.8},
        ],
      };

      final signals = ExtractedSignals.fromJson(json);

      expect(signals.totalCount, 2);
      final wins = signals.byType(SignalType.wins);
      expect(wins[0].confidence, 0.9);
      expect(wins[1].confidence, 0.8);
    });

    test('handles empty JSON', () {
      final signals = ExtractedSignals.fromJson({});

      expect(signals.isEmpty, isTrue);
      expect(signals.totalCount, 0);
    });

    test('handles null values in JSON', () {
      final json = {
        'wins': ['Win 1'],
        'blockers': null,
      };

      final signals = ExtractedSignals.fromJson(json);

      expect(signals.countByType(SignalType.wins), 1);
      expect(signals.countByType(SignalType.blockers), 0);
    });

    test('round trips through JSON', () {
      const original = ExtractedSignals([
        ExtractedSignal(type: SignalType.wins, text: 'Completed feature'),
        ExtractedSignal(type: SignalType.blockers, text: 'Waiting on review'),
        ExtractedSignal(type: SignalType.risks, text: 'Deadline tight'),
        ExtractedSignal(type: SignalType.avoidedDecision, text: 'Tech choice'),
        ExtractedSignal(type: SignalType.comfortWork, text: 'Code refactoring'),
        ExtractedSignal(type: SignalType.actions, text: 'Schedule meeting'),
        ExtractedSignal(type: SignalType.learnings, text: 'New pattern learned'),
      ]);

      final json = original.toJson();
      final restored = ExtractedSignals.fromJson(json);

      expect(restored.totalCount, original.totalCount);
      for (final type in SignalType.values) {
        expect(restored.countByType(type), original.countByType(type));
      }
    });
  });
}
