import 'dart:convert';

import '../../data/enums/board_role_type.dart';
import '../../data/enums/evidence_type.dart';
import '../governance/quarterly_state.dart';
import 'claude_client.dart';

/// AI service for Quarterly Report sessions.
///
/// Per PRD Section 3A.1: Uses Claude Opus 4.5 for governance features.
///
/// Handles:
/// - Board question generation based on anchoring
/// - Portfolio health trend analysis
/// - Final report generation
class QuarterlyAIService {
  final ClaudeClient _client;

  QuarterlyAIService(this._client);

  /// Generates a trend description for portfolio health changes.
  Future<String> generateTrendDescription({
    required int previousAppreciating,
    required int currentAppreciating,
    required int previousDepreciating,
    required int currentDepreciating,
  }) async {
    const systemPrompt = '''
You are a career advisor analyzing portfolio health trends.

## Task
Generate a brief, insightful trend description based on the changes in portfolio composition.

## Guidelines
- One sentence, 15-30 words
- Focus on the most significant change
- Be warm but direct
- If little change, acknowledge stability
- Reference specific percentages

## Output
Return ONLY the trend description sentence. No JSON, no quotes, just the sentence.
''';

    final userPrompt = '''
Analyze this portfolio health trend:

**Previous Quarter:**
- Appreciating: $previousAppreciating%
- Depreciating: $previousDepreciating%

**Current Quarter:**
- Appreciating: $currentAppreciating%
- Depreciating: $currentDepreciating%

**Changes:**
- Appreciating: ${currentAppreciating - previousAppreciating > 0 ? '+' : ''}${currentAppreciating - previousAppreciating}%
- Depreciating: ${currentDepreciating - previousDepreciating > 0 ? '+' : ''}${currentDepreciating - previousDepreciating}%

Generate the trend description.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 128,
      );

      return response.content.trim();
    } on ClaudeError catch (e) {
      throw QuarterlyAIError(
        'Failed to generate trend description: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  /// Generates a board question based on the member's role and anchoring.
  Future<String> generateBoardQuestion({
    required BoardRoleType roleType,
    required String personaName,
    String? anchoredProblemId,
    String? anchoredDemand,
    required QuarterlySessionData sessionContext,
  }) async {
    const systemPrompt = '''
You are generating a question for an AI board member to ask during a quarterly career review.

## Task
Generate ONE focused question for this board member to ask, based on:
1. Their role and function
2. Their anchored problem (if specified)
3. Their specific demand/focus area
4. The context of this quarterly session

## Guidelines
- Question should be 10-30 words
- Direct and specific, not vague
- Related to the member's role function
- If anchored demand is specified, incorporate it
- Should feel like it comes from the persona's voice
- Pushes for concrete evidence or specific plans

## Board Role Functions
- Accountability: Demands receipts for stated commitments
- Market Reality: Challenges direction classifications
- Avoidance: Probes avoided decisions
- Long-term Positioning: Asks 5-year strategic questions
- Devil's Advocate: Argues against the user's path
- Portfolio Defender: Protects and compounds strengths
- Opportunity Scout: Identifies adjacent opportunities

## Output
Return ONLY the question. No quotes, no attribution, just the question text.
''';

    final contextSummary = _buildContextSummary(sessionContext);

    final userPrompt = '''
Generate a question for this board member:

**Role:** ${roleType.displayName}
**Function:** ${roleType.function}
**Persona Name:** $personaName
**Anchored Demand:** ${anchoredDemand ?? roleType.signatureQuestion}
**Session Context:**
$contextSummary

Generate ONE question for $personaName to ask.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 128,
      );

      var question = response.content.trim();
      // Remove quotes if present
      if (question.startsWith('"') && question.endsWith('"')) {
        question = question.substring(1, question.length - 1);
      }
      return question;
    } on ClaudeError catch (e) {
      // Fallback to signature question
      return anchoredDemand ?? roleType.signatureQuestion;
    }
  }

  String _buildContextSummary(QuarterlySessionData data) {
    final buffer = StringBuffer();

    if (data.betEvaluation != null) {
      buffer.writeln(
          '- Last bet "${data.betEvaluation!.prediction}" was ${data.betEvaluation!.status.name}');
    }

    if (data.commitmentsResponse != null) {
      buffer.writeln(
          '- Commitments review: ${_truncate(data.commitmentsResponse!, 100)}');
    }

    if (data.avoidedDecision != null) {
      buffer.writeln(
          '- Avoided decision: ${_truncate(data.avoidedDecision!, 100)}');
    }

    if (data.comfortWork != null) {
      buffer.writeln('- Comfort work: ${_truncate(data.comfortWork!, 100)}');
    }

    if (data.healthTrend != null) {
      buffer.writeln(
          '- Portfolio trend: Appreciating ${data.healthTrend!.appreciatingChange > 0 ? "+" : ""}${data.healthTrend!.appreciatingChange}%');
    }

    if (data.anyTriggerMet) {
      buffer.writeln('- Re-setup triggers met: Yes');
    }

    return buffer.toString();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generates the full quarterly report.
  Future<String> generateReport({
    required QuarterlySessionData sessionData,
  }) async {
    const systemPrompt = '''
You are generating a comprehensive quarterly career governance report.

## Task
Generate a structured report summarizing the quarterly review session.

## Report Structure
1. **Executive Summary** (2-3 sentences)
2. **Bet Evaluation** (what happened with the last bet)
3. **Commitments vs Actuals** (summary with evidence strength)
4. **Risk Areas** (avoided decisions, comfort work)
5. **Portfolio Health** (trend analysis)
6. **Board Insights** (key points from board interrogation)
7. **Trigger Status** (any re-setup triggers met)
8. **New Bet** (the new bet created)
9. **Action Items** (3-5 specific next steps)

## Guidelines
- Total 400-600 words
- Use markdown formatting
- Be direct and actionable
- Reference specific evidence and examples from the session
- Highlight both strengths and areas for improvement

## Output Format
Return the report as markdown. Start with "# Quarterly Report" heading.
''';

    final userPrompt = _buildReportPrompt(sessionData);

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 2048,
      );

      return response.content.trim();
    } on ClaudeError catch (e) {
      throw QuarterlyAIError(
        'Failed to generate report: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  String _buildReportPrompt(QuarterlySessionData data) {
    final buffer = StringBuffer();
    buffer.writeln('Generate a quarterly report from this session data:\n');

    // Bet evaluation
    buffer.writeln('## Bet Evaluation');
    if (data.betEvaluation != null) {
      buffer.writeln('- Prediction: "${data.betEvaluation!.prediction}"');
      buffer.writeln('- Wrong-if: "${data.betEvaluation!.wrongIf}"');
      buffer.writeln('- Result: ${data.betEvaluation!.status.name.toUpperCase()}');
      if (data.betEvaluation!.rationale != null) {
        buffer.writeln('- Rationale: ${data.betEvaluation!.rationale}');
      }
      if (data.betEvaluation!.evidence.isNotEmpty) {
        buffer.writeln('- Evidence:');
        for (final e in data.betEvaluation!.evidence) {
          buffer.writeln(
              '  - ${e.description} (${e.type.name}, ${e.strength.name})');
        }
      }
    } else {
      buffer.writeln('- No bet to evaluate');
    }

    // Commitments
    buffer.writeln('\n## Commitments vs Actuals');
    if (data.commitmentsResponse != null) {
      buffer.writeln(data.commitmentsResponse);
    }
    if (data.commitmentsEvidence.isNotEmpty) {
      buffer.writeln('\nEvidence provided:');
      for (final e in data.commitmentsEvidence) {
        buffer.writeln('- ${e.description} (${e.strength.name})');
      }
    }

    // Risk areas
    buffer.writeln('\n## Risk Areas');
    if (data.avoidedDecision != null) {
      buffer.writeln('**Avoided Decision:** ${data.avoidedDecision}');
    }
    if (data.comfortWork != null) {
      buffer.writeln('**Comfort Work:** ${data.comfortWork}');
    }

    // Portfolio health
    buffer.writeln('\n## Portfolio Health');
    if (data.healthTrend != null) {
      buffer.writeln('- Appreciating: ${data.healthTrend!.previousAppreciating}% -> ${data.healthTrend!.currentAppreciating}%');
      buffer.writeln('- Depreciating: ${data.healthTrend!.previousDepreciating}% -> ${data.healthTrend!.currentDepreciating}%');
      buffer.writeln('- Stable: ${data.healthTrend!.previousStable}% -> ${data.healthTrend!.currentStable}%');
      if (data.healthTrend!.trendDescription != null) {
        buffer.writeln('- Trend: ${data.healthTrend!.trendDescription}');
      }
    }

    // Growth role responses
    if (data.growthRolesActive) {
      buffer.writeln('\n## Growth Focus');
      if (data.protectionResponse != null) {
        buffer.writeln('**Protection Check:** ${data.protectionResponse}');
      }
      if (data.opportunityResponse != null) {
        buffer.writeln('**Opportunity Check:** ${data.opportunityResponse}');
      }
    }

    // Board interrogation
    buffer.writeln('\n## Board Interrogation');
    for (final response in data.coreBoardResponses) {
      buffer.writeln('### ${response.personaName} (${response.roleType.displayName})');
      buffer.writeln('**Q:** ${response.question}');
      buffer.writeln('**A:** ${response.response}');
      if (response.concreteExample != null) {
        buffer.writeln('**Example:** ${response.concreteExample}');
      }
    }
    for (final response in data.growthBoardResponses) {
      buffer.writeln('### ${response.personaName} (${response.roleType.displayName})');
      buffer.writeln('**Q:** ${response.question}');
      buffer.writeln('**A:** ${response.response}');
      if (response.concreteExample != null) {
        buffer.writeln('**Example:** ${response.concreteExample}');
      }
    }

    // Trigger status
    buffer.writeln('\n## Re-Setup Triggers');
    if (data.triggerStatuses.isNotEmpty) {
      for (final trigger in data.triggerStatuses) {
        buffer.writeln('- ${trigger.description}: ${trigger.isMet ? "MET" : "Not met"}');
      }
      if (data.anyTriggerMet) {
        buffer.writeln('\n**Warning:** One or more triggers are met. Consider re-setup.');
      }
    }

    // New bet
    buffer.writeln('\n## New Bet');
    if (data.newBet != null) {
      buffer.writeln('- Prediction: "${data.newBet!.prediction}"');
      buffer.writeln('- Wrong if: "${data.newBet!.wrongIf}"');
      buffer.writeln('- Duration: ${data.newBet!.durationDays} days');
    }

    buffer.writeln('\nGenerate the formatted quarterly report.');
    return buffer.toString();
  }

  /// Evaluates evidence strength based on type.
  EvidenceStrength evaluateEvidenceStrength(EvidenceType type) {
    return type.defaultStrength;
  }

  /// Extracts evidence items from a response text.
  Future<List<QuarterlyEvidence>> extractEvidence(String text) async {
    const systemPrompt = '''
You are extracting evidence items from a user's response.

## Evidence Types
- decision: A decision that was made
- artifact: An artifact created (document, code, deliverable)
- calendar: Calendar entry showing time allocated
- proxy: Indirect evidence (testimonial, metrics)
- none: No evidence

## Strength by Type
- decision/artifact = strong
- proxy = medium
- calendar = weak
- none = none

## Output Format
Return a JSON array of evidence items:
[
  {
    "description": "Brief description of the evidence",
    "type": "decision|artifact|calendar|proxy|none",
    "strength": "strong|medium|weak|none"
  }
]

If no evidence found, return empty array: []
Return ONLY the JSON array.
''';

    final userPrompt = '''
Extract evidence items from this response:

"$text"

Return the JSON array of evidence items.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 512,
      );

      return _parseEvidenceResponse(response.content);
    } on ClaudeError {
      return [];
    }
  }

  List<QuarterlyEvidence> _parseEvidenceResponse(String content) {
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
      final json = jsonDecode(jsonString) as List<dynamic>;
      return json.map((item) {
        final map = item as Map<String, dynamic>;
        return QuarterlyEvidence(
          description: map['description'] as String? ?? '',
          type: _parseEvidenceType(map['type'] as String?),
          strength: _parseEvidenceStrength(map['strength'] as String?),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  EvidenceType _parseEvidenceType(String? type) {
    switch (type?.toLowerCase()) {
      case 'decision':
        return EvidenceType.decision;
      case 'artifact':
        return EvidenceType.artifact;
      case 'calendar':
        return EvidenceType.calendar;
      case 'proxy':
        return EvidenceType.proxy;
      default:
        return EvidenceType.none;
    }
  }

  EvidenceStrength _parseEvidenceStrength(String? strength) {
    switch (strength?.toLowerCase()) {
      case 'strong':
        return EvidenceStrength.strong;
      case 'medium':
        return EvidenceStrength.medium;
      case 'weak':
        return EvidenceStrength.weak;
      default:
        return EvidenceStrength.none;
    }
  }
}

/// Error during Quarterly AI operations.
class QuarterlyAIError implements Exception {
  final String message;
  final bool isRetryable;

  const QuarterlyAIError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'QuarterlyAIError: $message';
}
