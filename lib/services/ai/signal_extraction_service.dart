import 'dart:convert';

import '../../data/enums/signal_type.dart';
import 'claude_client.dart';
import 'models/extracted_signal.dart';

/// Service for extracting signals from journal entry text.
///
/// Per PRD Section 3.1 and 9, extracts 7 signal types:
/// - Wins: Completed accomplishments
/// - Blockers: Current obstacles
/// - Risks: Potential future problems
/// - Avoided Decision: Decisions being put off
/// - Comfort Work: Tasks that feel productive but don't advance goals
/// - Actions: Forward commitments
/// - Learnings: Realizations and reflections
class SignalExtractionService {
  final ClaudeClient _client;

  SignalExtractionService(this._client);

  /// System prompt for signal extraction.
  static const String _systemPrompt = '''
You are an expert at analyzing journal entries to extract career-relevant signals.

Your task is to identify and extract specific types of signals from the user's journal entry.

## Signal Types (extract ALL that apply)

1. **wins**: Completed accomplishments - things the user has done/achieved
2. **blockers**: Current obstacles - things preventing progress right now
3. **risks**: Potential future problems - things that could go wrong
4. **avoidedDecision**: Decisions being put off - things the user should decide but hasn't
5. **comfortWork**: Tasks that feel productive but don't advance goals - busy work, procrastination activities
6. **actions**: Forward commitments - things the user plans/commits to do
7. **learnings**: Realizations and reflections - insights, lessons learned

## Important Distinctions
- Blockers = NOW (current obstacles) vs Risks = FUTURE (potential problems)
- Wins = DONE (completed) vs Actions = TO DO (commitments)
- Comfort Work = feels productive but isn't advancing important goals

## Output Format

Return a valid JSON object with this exact structure:
{
  "wins": ["specific win 1", "specific win 2"],
  "blockers": ["specific blocker"],
  "risks": ["potential risk"],
  "avoidedDecision": ["decision being avoided"],
  "comfortWork": ["comfort work example"],
  "actions": ["committed action"],
  "learnings": ["insight or reflection"]
}

## Rules
- Only include signals that are explicitly or clearly implied in the entry
- Keep each signal concise but specific (one sentence max)
- Use the user's own words when possible
- If a category has no signals, use an empty array: []
- Return ONLY the JSON object, no other text
- Do not fabricate signals that aren't in the entry
''';

  /// Extracts signals from the given entry text.
  ///
  /// Returns [ExtractedSignals] containing all identified signals.
  /// Throws [SignalExtractionError] if extraction fails.
  Future<ExtractedSignals> extractSignals(String entryText) async {
    // Handle empty or very short entries
    if (entryText.trim().isEmpty) {
      return const ExtractedSignals([]);
    }

    if (entryText.trim().split(RegExp(r'\s+')).length < 5) {
      // Very short entries (< 5 words) - skip AI call
      return const ExtractedSignals([]);
    }

    try {
      final response = await _client.sendMessage(
        systemPrompt: _systemPrompt,
        userMessage: _buildUserPrompt(entryText),
        maxTokens: 2048,
      );

      return _parseResponse(response.content);
    } on ClaudeError catch (e) {
      throw SignalExtractionError(
        'Failed to extract signals: ${e.message}',
        isRetryable: e.isRetryable,
      );
    } catch (e) {
      throw SignalExtractionError(
        'Failed to extract signals: $e',
        isRetryable: false,
      );
    }
  }

  String _buildUserPrompt(String entryText) {
    return '''
Please analyze the following journal entry and extract all relevant signals.

## Journal Entry
$entryText

## Instructions
Extract all wins, blockers, risks, avoided decisions, comfort work, actions, and learnings from this entry. Return ONLY a JSON object.
''';
  }

  ExtractedSignals _parseResponse(String responseContent) {
    // Extract JSON from response (handle potential markdown code blocks)
    var jsonString = responseContent.trim();

    // Remove markdown code blocks if present
    if (jsonString.startsWith('```json')) {
      jsonString = jsonString.substring(7);
    } else if (jsonString.startsWith('```')) {
      jsonString = jsonString.substring(3);
    }
    if (jsonString.endsWith('```')) {
      jsonString = jsonString.substring(0, jsonString.length - 3);
    }
    jsonString = jsonString.trim();

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _validateAndBuildSignals(json);
    } on FormatException catch (e) {
      throw SignalExtractionError(
        'Invalid JSON response: ${e.message}',
        isRetryable: true,
      );
    }
  }

  ExtractedSignals _validateAndBuildSignals(Map<String, dynamic> json) {
    final signals = <ExtractedSignal>[];

    for (final signalType in SignalType.values) {
      final items = json[signalType.name];

      if (items == null) continue;

      if (items is! List) {
        // Log warning but continue - be resilient
        continue;
      }

      for (final item in items) {
        if (item is String && item.trim().isNotEmpty) {
          signals.add(ExtractedSignal(
            type: signalType,
            text: item.trim(),
          ));
        }
      }
    }

    return ExtractedSignals(signals);
  }
}

/// Error during signal extraction.
class SignalExtractionError implements Exception {
  final String message;
  final bool isRetryable;

  const SignalExtractionError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'SignalExtractionError: $message';
}
