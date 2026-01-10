import 'dart:convert';

import '../../data/database/database.dart';
import '../../data/enums/signal_type.dart';
import 'claude_client.dart';
import 'models/extracted_signal.dart';

/// Options for brief regeneration.
///
/// Per PRD Section 4.2: Regeneration options are combinable multi-select checkboxes.
class BriefRegenerationOptions {
  /// Shorter: 2 bullets max per section, 1-sentence headline, omit open loops (~40% reduction)
  final bool shorter;

  /// More Actionable: Every bullet includes verb/next step, add "Suggested Actions" section
  final bool moreActionable;

  /// More Strategic: Connect to portfolio health, add "Strategic Implications" section
  final bool moreStrategic;

  const BriefRegenerationOptions({
    this.shorter = false,
    this.moreActionable = false,
    this.moreStrategic = false,
  });

  bool get hasAnyOption => shorter || moreActionable || moreStrategic;

  Map<String, dynamic> toJson() => {
        'shorter': shorter,
        'moreActionable': moreActionable,
        'moreStrategic': moreStrategic,
      };

  factory BriefRegenerationOptions.fromJson(Map<String, dynamic> json) {
    return BriefRegenerationOptions(
      shorter: json['shorter'] as bool? ?? false,
      moreActionable: json['moreActionable'] as bool? ?? false,
      moreStrategic: json['moreStrategic'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());
}

/// Result of weekly brief generation.
class GeneratedBrief {
  /// The main brief markdown content.
  final String briefMarkdown;

  /// Board micro-review markdown (one sentence per active role).
  final String? boardMicroReviewMarkdown;

  /// Number of entries included in this brief.
  final int entryCount;

  /// Whether this is a zero-entry reflection brief.
  final bool isReflectionBrief;

  const GeneratedBrief({
    required this.briefMarkdown,
    this.boardMicroReviewMarkdown,
    required this.entryCount,
    this.isReflectionBrief = false,
  });
}

/// Service for generating weekly briefs from journal entries.
///
/// Per PRD Section 4.2 (Weekly Brief Generation):
/// - Target ~600 words, max 800 words
/// - Strict section caps enforced
/// - Zero-entry weeks get reflection brief (~100 words)
/// - Board micro-review included by default
class WeeklyBriefGenerationService {
  final ClaudeClient _client;

  WeeklyBriefGenerationService(this._client);

  /// System prompt for weekly brief generation.
  static const String _systemPrompt = '''
You are an expert executive assistant generating weekly career briefs.

Your task is to synthesize a week of journal entries into a concise, actionable executive brief.

## Output Format (STRICT)

Generate a markdown brief with these EXACT sections:

# Weekly Brief: [Week Date Range]

## Headline
[1-2 sentences summarizing the week's theme]

## Wins
- [Accomplishment 1]
- [Accomplishment 2]
- [Accomplishment 3 - if applicable]

## Blockers
- [Current obstacle 1]
- [Current obstacle 2]
- [Current obstacle 3 - if applicable]

## Risks
- [Potential future problem 1]
- [Potential future problem 2]
- [Potential future problem 3 - if applicable]

## Open Loops
- [Unfinished item 1]
- [Unfinished item 2]
- [Unfinished item 3]
- [Unfinished item 4]
- [Unfinished item 5 - if applicable]

## Next Week Focus
1. [Top priority]
2. [Second priority]
3. [Third priority]

## Avoided Decision
[One specific decision being put off, or "None identified this week"]

## Comfort Work
[One example of busy work that felt productive but didn't advance goals, or "None identified this week"]

## STRICT RULES
- Headline: MAX 2 sentences
- Wins/Blockers/Risks: MAX 3 bullets each
- Open Loops: MAX 5 bullets
- Next Week Focus: EXACTLY 3 items
- Avoided Decision: 1 item or "None identified this week"
- Comfort Work: 1 item or "None identified this week"
- Total brief: Target ~600 words, MAX 800 words
- Use the user's own words when possible (quote if impactful)
- Be specific and concrete, not vague
- Focus on career/professional growth themes
''';

  /// Additional prompt modifiers for regeneration.
  static const String _shorterModifier = '''
ADDITIONAL REQUIREMENT - SHORTER VERSION:
- Maximum 2 bullets per section (Wins, Blockers, Risks)
- Headline must be 1 sentence only
- OMIT the Open Loops section entirely
- Target ~350 words total (40% reduction)
''';

  static const String _actionableModifier = '''
ADDITIONAL REQUIREMENT - MORE ACTIONABLE:
- Every bullet must include a specific verb or next step
- Add a "## Suggested Actions" section after Next Week Focus with 3 concrete actions
- Reframe blockers as "To unblock: [specific action]"
- Focus on what the user can DO, not just observe
''';

  static const String _strategicModifier = '''
ADDITIONAL REQUIREMENT - MORE STRATEGIC:
- Add a "## Strategic Implications" section connecting to long-term career trajectory
- Frame wins and blockers in terms of skill development and market positioning
- Consider appreciating vs depreciating skills context
- Add one sentence about portfolio health implications if patterns emerge
''';

  /// System prompt for zero-entry week reflection.
  static const String _reflectionSystemPrompt = '''
You are a supportive career coach generating a brief reflection for a week with no journal entries.

Generate a short (~100 words) reflection brief that:
1. Acknowledges the quiet week without judgment
2. Offers 2-3 reflection questions for the coming week
3. Maintains an encouraging, warm tone

## Output Format

# Weekly Reflection: [Week Date Range]

No entries this week. Sometimes we're too busy living to document—that's okay.

## Questions for Next Week
- [Reflection question 1 based on career growth]
- [Reflection question 2 based on decision-making]
- [Reflection question 3 based on progress]

Keep the total under 100 words. Be warm and encouraging, not preachy.
''';

  /// System prompt for board micro-review.
  static const String _microReviewSystemPrompt = '''
You are generating a board micro-review—quick commentary from an AI board of directors.

Generate ONE sentence from each of the following board roles, commenting on something relevant from this week's brief:

## Board Roles (5 core):
1. **Accountability**: Demands receipts for commitments. Ask about evidence.
2. **Market Reality**: Challenges assumptions. Question if classifications are accurate.
3. **Avoidance**: Probes avoided decisions. Call out what's being dodged.
4. **Long-term Positioning**: Asks strategic 5-year questions. Focus on career trajectory.
5. **Devil's Advocate**: Argues against the user's path. Challenge the strongest assumption.

## Output Format

Return EXACTLY 5 sentences, one per role, in this format:
**Accountability**: [One sentence commentary]
**Market Reality**: [One sentence commentary]
**Avoidance**: [One sentence commentary]
**Long-term Positioning**: [One sentence commentary]
**Devil's Advocate**: [One sentence commentary]

## Rules
- Each sentence should be specific to THIS week's content
- Tone: warm-direct blunt (supportive but challenging)
- Total: ~100 words
- If nothing relevant for a role, make a general observation about the week
''';

  /// Generates a weekly brief from the provided entries.
  ///
  /// [entries] - List of daily entries for the week.
  /// [weekStart] - Start of the week (Monday).
  /// [weekEnd] - End of the week (Sunday).
  /// [options] - Optional regeneration modifiers.
  /// [existingPortfolio] - If user has portfolio, used for strategic context.
  Future<GeneratedBrief> generateBrief({
    required List<DailyEntry> entries,
    required DateTime weekStart,
    required DateTime weekEnd,
    BriefRegenerationOptions options = const BriefRegenerationOptions(),
    String? existingPortfolio,
  }) async {
    // Handle zero-entry weeks
    if (entries.isEmpty) {
      return _generateReflectionBrief(weekStart, weekEnd);
    }

    // Aggregate signals and content from entries
    final aggregatedContent = _aggregateEntryContent(entries);
    final weekRange = _formatWeekRange(weekStart, weekEnd);

    // Build the system prompt with any modifiers
    final systemPrompt = _buildSystemPrompt(options);

    // Build user prompt with aggregated content
    final userPrompt = _buildUserPrompt(
      aggregatedContent,
      weekRange,
      options,
      existingPortfolio,
    );

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 2048,
      );

      final briefMarkdown = response.content.trim();

      // Generate board micro-review
      String? microReview;
      try {
        microReview = await _generateMicroReview(briefMarkdown, weekRange);
      } catch (_) {
        // Micro-review is optional - don't fail the whole brief
      }

      return GeneratedBrief(
        briefMarkdown: briefMarkdown,
        boardMicroReviewMarkdown: microReview,
        entryCount: entries.length,
        isReflectionBrief: false,
      );
    } on ClaudeError catch (e) {
      throw BriefGenerationError(
        'Failed to generate brief: ${e.message}',
        isRetryable: e.isRetryable,
      );
    } catch (e) {
      throw BriefGenerationError(
        'Failed to generate brief: $e',
        isRetryable: false,
      );
    }
  }

  /// Generates a reflection brief for zero-entry weeks.
  Future<GeneratedBrief> _generateReflectionBrief(
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final weekRange = _formatWeekRange(weekStart, weekEnd);

    try {
      final response = await _client.sendMessage(
        systemPrompt: _reflectionSystemPrompt,
        userMessage:
            'Generate a reflection brief for the week of $weekRange. No journal entries were recorded this week.',
        maxTokens: 512,
      );

      return GeneratedBrief(
        briefMarkdown: response.content.trim(),
        boardMicroReviewMarkdown: null,
        entryCount: 0,
        isReflectionBrief: true,
      );
    } on ClaudeError catch (e) {
      throw BriefGenerationError(
        'Failed to generate reflection brief: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  /// Generates board micro-review for the brief.
  Future<String> _generateMicroReview(
    String briefMarkdown,
    String weekRange,
  ) async {
    final response = await _client.sendMessage(
      systemPrompt: _microReviewSystemPrompt,
      userMessage: '''
Generate a board micro-review for this weekly brief ($weekRange):

$briefMarkdown
''',
      maxTokens: 512,
    );

    return response.content.trim();
  }

  String _buildSystemPrompt(BriefRegenerationOptions options) {
    final buffer = StringBuffer(_systemPrompt);

    if (options.shorter) {
      buffer.writeln();
      buffer.write(_shorterModifier);
    }
    if (options.moreActionable) {
      buffer.writeln();
      buffer.write(_actionableModifier);
    }
    if (options.moreStrategic) {
      buffer.writeln();
      buffer.write(_strategicModifier);
    }

    return buffer.toString();
  }

  String _buildUserPrompt(
    _AggregatedContent content,
    String weekRange,
    BriefRegenerationOptions options,
    String? existingPortfolio,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('Generate a weekly brief for: $weekRange');
    buffer.writeln();
    buffer.writeln('## Entry Count: ${content.entryCount}');
    buffer.writeln();

    // Include raw entries
    buffer.writeln('## Journal Entries');
    for (final entry in content.entries) {
      buffer.writeln('---');
      buffer.writeln('Entry (${_formatDate(entry.createdAtUtc)}):');
      buffer.writeln(entry.transcriptEdited);
      buffer.writeln();
    }

    // Include aggregated signals
    if (content.hasSignals) {
      buffer.writeln('## Extracted Signals (aggregated from all entries)');
      buffer.writeln();

      for (final type in SignalType.values) {
        final signals = content.signalsByType[type];
        if (signals != null && signals.isNotEmpty) {
          buffer.writeln('### ${type.displayName}');
          for (final signal in signals) {
            buffer.writeln('- $signal');
          }
          buffer.writeln();
        }
      }
    }

    // Include portfolio context if available and strategic modifier selected
    if (options.moreStrategic && existingPortfolio != null) {
      buffer.writeln('## Portfolio Context (for strategic framing)');
      buffer.writeln(existingPortfolio);
      buffer.writeln();
    }

    return buffer.toString();
  }

  _AggregatedContent _aggregateEntryContent(List<DailyEntry> entries) {
    final signalsByType = <SignalType, List<String>>{};

    for (final entry in entries) {
      try {
        final signals = ExtractedSignals.fromJsonString(entry.extractedSignalsJson);
        for (final signal in signals.signals) {
          signalsByType.putIfAbsent(signal.type, () => []).add(signal.text);
        }
      } catch (_) {
        // Skip malformed signal JSON
      }
    }

    return _AggregatedContent(
      entries: entries,
      signalsByType: signalsByType,
    );
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Internal class for aggregated entry content.
class _AggregatedContent {
  final List<DailyEntry> entries;
  final Map<SignalType, List<String>> signalsByType;

  _AggregatedContent({
    required this.entries,
    required this.signalsByType,
  });

  int get entryCount => entries.length;
  bool get hasSignals => signalsByType.values.any((list) => list.isNotEmpty);
}

/// Error during brief generation.
class BriefGenerationError implements Exception {
  final String message;
  final bool isRetryable;

  const BriefGenerationError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'BriefGenerationError: $message';
}
