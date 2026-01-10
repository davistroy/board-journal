import 'dart:convert';

import 'claude_client.dart';

/// Service for detecting vague answers in governance sessions.
///
/// Per PRD Section 6.3:
/// Trigger "concrete example required" if:
/// - Answer lacks a named instance (project, meeting, decision, deliverable) AND
/// - Uses generic qualifiers ("stuff", "things", "helped", "a lot", etc.) AND
/// - No timeline or stakeholder or observable outcome is present
class VaguenessDetectionService {
  final ClaudeClient _client;

  VaguenessDetectionService(this._client);

  /// System prompt for vagueness detection.
  static const String _systemPrompt = '''
You are an expert at detecting vague answers in career coaching conversations.

Your task is to determine if an answer is VAGUE or CONCRETE.

## Definition of VAGUE (must meet ALL criteria)
An answer is VAGUE if it:
1. Lacks a named instance (no specific project, meeting, decision, deliverable, or person)
2. Uses generic qualifiers ("stuff", "things", "helped", "a lot", "various", "some", "improve", "better", "worked on")
3. Has no timeline, stakeholder name, or observable outcome

## Definition of CONCRETE
An answer is CONCRETE if it includes ANY of:
- A specific project, meeting, or deliverable name
- A named person, team, or organization
- A specific date, week, or time reference
- A measurable outcome or observable result
- A specific decision that was made

## Output Format
Return a valid JSON object:
{
  "isVague": true/false,
  "reason": "Brief explanation of why it is/isn't vague",
  "missingElements": ["list", "of", "missing", "concrete", "elements"]
}

## Rules
- Err on the side of CONCRETE if uncertain
- Short answers are not automatically vague if they contain specifics
- Industry jargon counts as concrete if it names a specific thing
- Return ONLY the JSON object, no other text
''';

  /// Checks if an answer is vague.
  ///
  /// Returns [VaguenessResult] with the determination.
  Future<VaguenessResult> checkVagueness({
    required String question,
    required String answer,
  }) async {
    // Very short answers (< 3 words) that aren't "none" are automatically vague
    final trimmedAnswer = answer.trim().toLowerCase();
    final wordCount = answer.trim().split(RegExp(r'\s+')).length;

    if (wordCount < 3 && trimmedAnswer != 'none' && trimmedAnswer != 'n/a') {
      return const VaguenessResult(
        isVague: true,
        reason: 'Answer is too brief to contain concrete details',
        missingElements: [
          'specific example',
          'named instance',
          'observable outcome'
        ],
      );
    }

    // "None" answers for avoided decision/comfort work are acceptable
    if (trimmedAnswer == 'none' || trimmedAnswer == 'n/a') {
      return const VaguenessResult(
        isVague: false,
        reason: 'Explicitly stated none/n/a',
        missingElements: [],
      );
    }

    // Quick heuristic check before AI call
    if (_hasConcreteIndicators(answer)) {
      return const VaguenessResult(
        isVague: false,
        reason: 'Contains concrete indicators',
        missingElements: [],
      );
    }

    if (_hasVagueIndicators(answer) && !_hasConcreteIndicators(answer)) {
      return const VaguenessResult(
        isVague: true,
        reason: 'Uses vague language without concrete specifics',
        missingElements: [
          'specific project or deliverable',
          'named person or team',
          'timeline or date',
          'measurable outcome'
        ],
      );
    }

    // Use AI for ambiguous cases
    try {
      final response = await _client.sendMessage(
        systemPrompt: _systemPrompt,
        userMessage: _buildPrompt(question, answer),
        maxTokens: 512,
      );

      return _parseResponse(response.content);
    } on ClaudeError catch (e) {
      // On AI error, err on the side of concrete to not block the user
      return VaguenessResult(
        isVague: false,
        reason: 'Could not verify (AI error: ${e.message})',
        missingElements: [],
      );
    } catch (e) {
      return const VaguenessResult(
        isVague: false,
        reason: 'Could not verify (error)',
        missingElements: [],
      );
    }
  }

  /// Quick heuristic check for concrete indicators.
  bool _hasConcreteIndicators(String answer) {
    final lower = answer.toLowerCase();

    // Check for date/time patterns
    final datePatterns = [
      RegExp(r'\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b'),
      RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\b'),
      RegExp(r'\b(last|this|next)\s+(week|month|quarter|year)\b'),
      RegExp(r'\b\d{1,2}[\/\-]\d{1,2}\b'), // dates like 1/15 or 1-15
      RegExp(r'\b(q[1-4]|h[12])\b'), // Q1, Q2, H1, H2
      RegExp(r'\byesterday|today|tomorrow\b'),
    ];

    for (final pattern in datePatterns) {
      if (pattern.hasMatch(lower)) return true;
    }

    // Check for proper nouns (capitalized words that aren't sentence starters)
    final words = answer.split(RegExp(r'\s+'));
    for (var i = 1; i < words.length; i++) {
      if (words[i].isNotEmpty &&
          words[i][0] == words[i][0].toUpperCase() &&
          words[i][0] != words[i][0].toLowerCase()) {
        // Capitalized word not at sentence start
        if (!words[i - 1].endsWith('.') && !words[i - 1].endsWith('?') && !words[i - 1].endsWith('!')) {
          return true;
        }
      }
    }

    // Check for numbers/metrics
    if (RegExp(r'\b\d+%|\$\d+|\d+\s*(people|users|customers|hours|days|meetings)\b').hasMatch(lower)) {
      return true;
    }

    // Check for specific action verbs with objects
    final specificPatterns = [
      RegExp(r'\b(completed|delivered|shipped|launched|presented|submitted)\b'),
      RegExp(r'\b(met with|talked to|emailed|called|messaged)\b'),
      RegExp(r'\b(the\s+\w+\s+(project|team|meeting|report|document|proposal|presentation))\b'),
    ];

    for (final pattern in specificPatterns) {
      if (pattern.hasMatch(lower)) return true;
    }

    return false;
  }

  /// Quick heuristic check for vague indicators.
  bool _hasVagueIndicators(String answer) {
    final lower = answer.toLowerCase();

    final vagueWords = [
      'stuff',
      'things',
      'various',
      'several',
      'some',
      'a lot',
      'many',
      'lots of',
      'kind of',
      'sort of',
      'basically',
      'essentially',
      'generally',
      'usually',
      'sometimes',
      'often',
      'pretty much',
      'more or less',
      'helped',
      'improved',
      'worked on',
      'dealt with',
      'handled',
      'took care of',
      'etc',
      'and so on',
      'and stuff',
    ];

    for (final word in vagueWords) {
      if (lower.contains(word)) return true;
    }

    return false;
  }

  String _buildPrompt(String question, String answer) {
    return '''
Question asked: "$question"

User's answer: "$answer"

Analyze if this answer is VAGUE or CONCRETE based on the criteria. Return only JSON.
''';
  }

  VaguenessResult _parseResponse(String responseContent) {
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
      return VaguenessResult(
        isVague: json['isVague'] as bool? ?? false,
        reason: json['reason'] as String? ?? '',
        missingElements: (json['missingElements'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
    } catch (e) {
      // If JSON parsing fails, err on the side of concrete
      return const VaguenessResult(
        isVague: false,
        reason: 'Could not parse response',
        missingElements: [],
      );
    }
  }
}

/// Result of vagueness detection.
class VaguenessResult {
  /// Whether the answer was determined to be vague.
  final bool isVague;

  /// Reason for the determination.
  final String reason;

  /// List of missing concrete elements (if vague).
  final List<String> missingElements;

  const VaguenessResult({
    required this.isVague,
    required this.reason,
    required this.missingElements,
  });

  @override
  String toString() =>
      'VaguenessResult(isVague: $isVague, reason: $reason, missing: $missingElements)';
}

/// Error during vagueness detection.
class VaguenessDetectionError implements Exception {
  final String message;
  final bool isRetryable;

  const VaguenessDetectionError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'VaguenessDetectionError: $message';
}
