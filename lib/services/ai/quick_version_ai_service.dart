import 'dart:convert';

import '../governance/quick_version_state.dart';
import 'claude_client.dart';

/// AI service for Quick Version (15-min audit) sessions.
///
/// Per PRD Section 3A.1: Uses Claude Opus 4.5 for governance features.
///
/// Handles:
/// - Problem direction evaluation
/// - Output generation with quotes
/// - Bet creation with wrong-if conditions
class QuickVersionAIService {
  final ClaudeClient _client;

  QuickVersionAIService(this._client);

  /// Evaluates the direction of a problem based on user responses.
  ///
  /// Per PRD Section 4.3, produces direction classification with rationale.
  Future<DirectionEvaluation> evaluateDirection({
    required String problemName,
    required String aiCheaper,
    required String errorCost,
    required String trustRequired,
  }) async {
    const systemPrompt = '''
You are a career advisor evaluating whether a skill/problem is appreciating or depreciating in value.

## Direction Criteria

**Appreciating** (becoming MORE valuable):
- AI can't easily do it (or won't for a while)
- Errors are costly (high stakes)
- Trust/access required (relationship-dependent)

**Depreciating** (becoming LESS valuable):
- AI is getting better at it
- Errors are low-impact
- No special access/trust needed

**Stable** (unclear direction):
- Mixed signals or uncertainty
- Revisit classification next quarter

## Output Format
Return a valid JSON object:
{
  "direction": "appreciating" | "depreciating" | "stable",
  "rationale": "One sentence explaining the classification, referencing the user's specific answers",
  "confidence": "high" | "medium" | "low"
}

## Rules
- Quote or reference the user's actual words in the rationale
- Be honest if signals are mixed (use "stable")
- Return ONLY the JSON object, no other text
''';

    final userPrompt = '''
Evaluate the direction for this problem:

**Problem:** $problemName

**Is AI getting cheaper at this?**
"$aiCheaper"

**What's the cost of errors?**
"$errorCost"

**Is trust/access required?**
"$trustRequired"

Classify the direction and provide a one-sentence rationale.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 512,
      );

      return _parseDirectionResponse(response.content);
    } on ClaudeError catch (e) {
      throw QuickVersionAIError(
        'Failed to evaluate direction: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  DirectionEvaluation _parseDirectionResponse(String content) {
    var jsonString = content.trim();

    // Remove markdown code blocks
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
      final directionStr = json['direction'] as String? ?? 'stable';
      final direction = ProblemDirection.values.firstWhere(
        (d) => d.name == directionStr,
        orElse: () => ProblemDirection.stable,
      );

      return DirectionEvaluation(
        direction: direction,
        rationale: json['rationale'] as String? ?? '',
        confidence: json['confidence'] as String? ?? 'medium',
      );
    } catch (e) {
      throw QuickVersionAIError(
        'Failed to parse direction response: $e',
        isRetryable: true,
      );
    }
  }

  /// Generates the final output for a Quick Version session.
  ///
  /// Per PRD Section 4.3 final output:
  /// - 2-sentence honest assessment
  /// - Avoided decision + cost
  /// - One 90-day prediction + wrong-if evidence
  Future<QuickVersionOutput> generateOutput({
    required QuickVersionSessionData sessionData,
  }) async {
    const systemPrompt = '''
You are generating the final output for a 15-minute career audit session.

## Required Output Sections

1. **Problem Direction Table** (markdown table format)
   - Use the user's actual quoted words in cells
   - Include direction classification

2. **Honest Assessment** (exactly 2 sentences)
   - Blunt, warm-direct tone
   - Reference specific answers from the session

3. **Avoided Decision** (1 item)
   - State what's being avoided
   - State the cost of avoidance

4. **90-Day Bet** (prediction + wrong-if)
   - Make it falsifiable
   - Reference the session content
   - "Wrong if" must be observable evidence

## Output Format
Return a valid JSON object:
{
  "directionTableMarkdown": "| Problem | AI cheaper? | Error cost? | Trust required? | Direction |\n|---|---|---|---|---|\n...",
  "assessment": "Two sentence honest assessment.",
  "avoidedDecision": "What's being avoided",
  "avoidedDecisionCost": "The cost of avoiding it",
  "betPrediction": "In 90 days, [specific prediction]",
  "betWrongIf": "Wrong if [observable evidence]",
  "fullOutputMarkdown": "Complete formatted markdown output"
}

## Rules
- Quote user's words using quotation marks
- Be warm but direct - no sugar-coating
- Keep the bet specific and falsifiable
- Return ONLY the JSON object
''';

    final userPrompt = _buildOutputPrompt(sessionData);

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 2048,
      );

      return _parseOutputResponse(response.content);
    } on ClaudeError catch (e) {
      throw QuickVersionAIError(
        'Failed to generate output: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  String _buildOutputPrompt(QuickVersionSessionData sessionData) {
    final buffer = StringBuffer();

    buffer.writeln('Generate the final output for this Quick Version audit session.');
    buffer.writeln();
    buffer.writeln('## Session Data');
    buffer.writeln();

    if (sessionData.roleContext != null) {
      buffer.writeln('**Role Context:**');
      buffer.writeln('"${sessionData.roleContext}"');
      buffer.writeln();
    }

    buffer.writeln('**Problems and Directions:**');
    for (final problem in sessionData.problems) {
      buffer.writeln();
      buffer.writeln('Problem: ${problem.name}');
      buffer.writeln('- AI cheaper?: "${problem.aiCheaper ?? "not answered"}"');
      buffer.writeln('- Error cost?: "${problem.errorCost ?? "not answered"}"');
      buffer.writeln('- Trust required?: "${problem.trustRequired ?? "not answered"}"');
      buffer.writeln('- Direction: ${problem.direction?.displayName ?? "not evaluated"}');
      if (problem.directionRationale != null) {
        buffer.writeln('- Rationale: ${problem.directionRationale}');
      }
    }
    buffer.writeln();

    buffer.writeln('**Avoided Decision:**');
    buffer.writeln('"${sessionData.avoidedDecision ?? "none stated"}"');
    if (sessionData.avoidedDecisionCost != null) {
      buffer.writeln('Cost: "${sessionData.avoidedDecisionCost}"');
    }
    buffer.writeln();

    buffer.writeln('**Comfort Work:**');
    buffer.writeln('"${sessionData.comfortWork ?? "none stated"}"');
    buffer.writeln();

    buffer.writeln('Generate the final output with all required sections.');

    return buffer.toString();
  }

  QuickVersionOutput _parseOutputResponse(String content) {
    var jsonString = content.trim();

    // Remove markdown code blocks
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

      return QuickVersionOutput(
        directionTableMarkdown: json['directionTableMarkdown'] as String? ?? '',
        assessment: json['assessment'] as String? ?? '',
        avoidedDecision: json['avoidedDecision'] as String? ?? '',
        avoidedDecisionCost: json['avoidedDecisionCost'] as String? ?? '',
        betPrediction: json['betPrediction'] as String? ?? '',
        betWrongIf: json['betWrongIf'] as String? ?? '',
        fullOutputMarkdown: json['fullOutputMarkdown'] as String? ?? '',
      );
    } catch (e) {
      throw QuickVersionAIError(
        'Failed to parse output response: $e',
        isRetryable: true,
      );
    }
  }

  /// Parses problems from a Q2 answer.
  ///
  /// User should list 3 problems they're paid to solve.
  Future<List<String>> parseProblems(String answer) async {
    const systemPrompt = '''
Extract the problems/challenges from the user's answer about what they're paid to solve.

## Rules
- Extract exactly 3 distinct problems (or as many as stated up to 3)
- Clean up wording but preserve the meaning
- Each problem should be a concise phrase (2-8 words)

## Output Format
Return a JSON array of strings:
["Problem 1", "Problem 2", "Problem 3"]

Return ONLY the JSON array, no other text.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: 'Extract the problems from this answer:\n\n"$answer"',
        maxTokens: 256,
      );

      return _parseProblemsResponse(response.content);
    } on ClaudeError catch (e) {
      // Fallback: try simple splitting
      return _fallbackParsing(answer);
    } catch (e) {
      return _fallbackParsing(answer);
    }
  }

  List<String> _parseProblemsResponse(String content) {
    var jsonString = content.trim();

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
      final json = jsonDecode(jsonString) as List<dynamic>;
      return json.map((e) => e.toString()).take(3).toList();
    } catch (e) {
      return [];
    }
  }

  List<String> _fallbackParsing(String answer) {
    // Try to split by common patterns
    final patterns = [
      RegExp(r'\d+[\.\)]\s*'),  // "1. " or "1) "
      RegExp(r'[-•]\s*'),        // "- " or "• "
      RegExp(r',\s*(?=\w)'),     // ", " followed by word
    ];

    for (final pattern in patterns) {
      final parts = answer.split(pattern).where((p) => p.trim().isNotEmpty).toList();
      if (parts.length >= 2) {
        return parts.take(3).map((p) => p.trim()).toList();
      }
    }

    // Last resort: split by newlines
    final lines = answer.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length >= 2) {
      return lines.take(3).map((l) => l.trim()).toList();
    }

    // Just return the whole answer as one problem
    return [answer.trim()];
  }
}

/// Result of direction evaluation.
class DirectionEvaluation {
  final ProblemDirection direction;
  final String rationale;
  final String confidence;

  const DirectionEvaluation({
    required this.direction,
    required this.rationale,
    required this.confidence,
  });
}

/// Generated output for Quick Version session.
class QuickVersionOutput {
  /// Markdown table of problem directions.
  final String directionTableMarkdown;

  /// Two-sentence honest assessment.
  final String assessment;

  /// The avoided decision.
  final String avoidedDecision;

  /// Cost of avoiding the decision.
  final String avoidedDecisionCost;

  /// 90-day bet prediction.
  final String betPrediction;

  /// Wrong-if condition for the bet.
  final String betWrongIf;

  /// Full formatted markdown output.
  final String fullOutputMarkdown;

  const QuickVersionOutput({
    required this.directionTableMarkdown,
    required this.assessment,
    required this.avoidedDecision,
    required this.avoidedDecisionCost,
    required this.betPrediction,
    required this.betWrongIf,
    required this.fullOutputMarkdown,
  });

  /// Generates complete markdown if fullOutputMarkdown is empty.
  String get markdown {
    if (fullOutputMarkdown.isNotEmpty) {
      return fullOutputMarkdown;
    }

    return '''
# 15-Minute Audit Results

## Problem Directions

$directionTableMarkdown

## Honest Assessment

$assessment

## Avoided Decision

**What you're avoiding:** $avoidedDecision

**Cost:** $avoidedDecisionCost

## 90-Day Bet

**Prediction:** $betPrediction

**Wrong if:** $betWrongIf
''';
  }
}

/// Error during Quick Version AI operations.
class QuickVersionAIError implements Exception {
  final String message;
  final bool isRetryable;

  const QuickVersionAIError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'QuickVersionAIError: $message';
}
