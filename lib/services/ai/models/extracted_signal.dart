import 'dart:convert';

import '../../../data/enums/signal_type.dart';

/// Represents a signal extracted from a journal entry.
///
/// Per PRD Section 3.1 and 9:
/// 7 signal types: wins, blockers, risks, avoidedDecision,
/// comfortWork, actions, learnings
class ExtractedSignal {
  /// The type of signal (wins, blockers, etc.)
  final SignalType type;

  /// The extracted text content.
  final String text;

  /// Confidence score from 0.0 to 1.0 (optional).
  final double? confidence;

  const ExtractedSignal({
    required this.type,
    required this.text,
    this.confidence,
  });

  /// Creates an ExtractedSignal from JSON.
  factory ExtractedSignal.fromJson(Map<String, dynamic> json) {
    return ExtractedSignal(
      type: SignalType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SignalType.learnings,
      ),
      text: json['text'] as String,
      confidence: json['confidence'] as double?,
    );
  }

  /// Converts to JSON representation.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'text': text,
      if (confidence != null) 'confidence': confidence,
    };
  }

  @override
  String toString() => 'ExtractedSignal(type: ${type.name}, text: $text)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtractedSignal &&
        other.type == type &&
        other.text == text &&
        other.confidence == confidence;
  }

  @override
  int get hashCode => Object.hash(type, text, confidence);
}

/// Groups extracted signals by type.
class ExtractedSignals {
  final List<ExtractedSignal> signals;

  const ExtractedSignals(this.signals);

  /// Creates from a JSON string stored in the database.
  factory ExtractedSignals.fromJsonString(String jsonString) {
    if (jsonString.isEmpty || jsonString == '{}') {
      return const ExtractedSignals([]);
    }
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return ExtractedSignals.fromJson(json);
  }

  /// Creates from the JSON format stored in the database.
  /// Format: {"wins": ["text1", "text2"], "blockers": [...], ...}
  factory ExtractedSignals.fromJson(Map<String, dynamic> json) {
    final signals = <ExtractedSignal>[];

    for (final signalType in SignalType.values) {
      final items = json[signalType.name] as List<dynamic>? ?? [];
      for (final item in items) {
        if (item is String) {
          signals.add(ExtractedSignal(type: signalType, text: item));
        } else if (item is Map<String, dynamic>) {
          signals.add(ExtractedSignal(
            type: signalType,
            text: item['text'] as String,
            confidence: item['confidence'] as double?,
          ));
        }
      }
    }

    return ExtractedSignals(signals);
  }

  /// Converts to the JSON format for database storage.
  /// Format: {"wins": ["text1", "text2"], "blockers": [...], ...}
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    for (final signalType in SignalType.values) {
      final items = signals
          .where((s) => s.type == signalType)
          .map((s) => s.text)
          .toList();
      if (items.isNotEmpty) {
        json[signalType.name] = items;
      }
    }

    return json;
  }

  /// Gets signals of a specific type.
  List<ExtractedSignal> byType(SignalType type) {
    return signals.where((s) => s.type == type).toList();
  }

  /// Gets the count of signals for a specific type.
  int countByType(SignalType type) {
    return signals.where((s) => s.type == type).length;
  }

  /// Total number of signals.
  int get totalCount => signals.length;

  /// Whether any signals were extracted.
  bool get isEmpty => signals.isEmpty;
  bool get isNotEmpty => signals.isNotEmpty;

  /// Gets a map of signal type to count.
  Map<SignalType, int> get countsByType {
    final counts = <SignalType, int>{};
    for (final type in SignalType.values) {
      final count = countByType(type);
      if (count > 0) {
        counts[type] = count;
      }
    }
    return counts;
  }
}
