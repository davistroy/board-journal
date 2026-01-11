import 'dart:convert';

import '../../data/enums/board_role_type.dart';
import '../../data/enums/problem_direction.dart';
import '../governance/setup_state.dart';
import 'claude_client.dart';

/// AI service for Setup sessions.
///
/// Per PRD Section 3A.1: Uses Claude Opus 4.5 for governance features.
///
/// Handles:
/// - Portfolio health statement generation
/// - Board role anchoring to problems
/// - Persona generation for each role
class SetupAIService {
  final ClaudeClient _client;

  SetupAIService(this._client);

  /// Generates portfolio health statements (risk and opportunity).
  ///
  /// Per PRD Section 3.3.6:
  /// - riskStatement: One sentence - where most exposed
  /// - opportunityStatement: One sentence - where under-investing in appreciation
  Future<HealthStatements> generateHealthStatements({
    required List<SetupProblem> problems,
    required int appreciatingPercent,
    required int depreciatingPercent,
    required int stablePercent,
  }) async {
    const systemPrompt = '''
You are a career advisor analyzing a portfolio of career problems.

## Task
Generate two concise statements about the portfolio:
1. Risk statement: Where is this person most exposed?
2. Opportunity statement: Where might they be under-investing in appreciating skills?

## Guidelines
- Each statement should be one sentence (10-25 words)
- Be specific - reference the actual problems
- Be direct but warm in tone
- Focus on actionable insight

## Output Format
Return a valid JSON object:
{
  "riskStatement": "One sentence describing main risk/exposure",
  "opportunityStatement": "One sentence describing potential opportunity"
}

Return ONLY the JSON object, no other text.
''';

    final problemsDesc = problems.map((p) {
      return '- ${p.name}: ${p.direction?.displayName ?? "unknown"} direction, ${p.timeAllocationPercent}% time';
    }).join('\n');

    final userPrompt = '''
Analyze this career portfolio and generate health statements:

**Portfolio Composition:**
- Appreciating: $appreciatingPercent%
- Depreciating: $depreciatingPercent%
- Stable/Unknown: $stablePercent%

**Problems:**
$problemsDesc

Generate the risk and opportunity statements.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 512,
      );

      return _parseHealthStatementsResponse(response.content);
    } on ClaudeError catch (e) {
      throw SetupAIError(
        'Failed to generate health statements: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  HealthStatements _parseHealthStatementsResponse(String content) {
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
      return HealthStatements(
        riskStatement: json['riskStatement'] as String? ?? '',
        opportunityStatement: json['opportunityStatement'] as String? ?? '',
      );
    } catch (e) {
      throw SetupAIError(
        'Failed to parse health statements response: $e',
        isRetryable: true,
      );
    }
  }

  /// Generates anchoring for board roles to problems.
  ///
  /// Per PRD Section 3.3.4:
  /// - Each role anchored to specific problem
  /// - AI generates specific demand based on portfolio content
  Future<List<RoleAnchoring>> generateBoardAnchoring({
    required List<SetupProblem> problems,
    required List<BoardRoleType> roles,
    bool focusOnAppreciating = false,
  }) async {
    const systemPrompt = '''
You are creating a career governance board for a professional.

## Task
For each board role, determine:
1. Which problem should this role focus on (by index)?
2. What specific demand/question should this role have?

## Board Role Functions
- Accountability: Demands receipts for stated commitments
- Market Reality: Challenges direction classifications
- Avoidance: Probes avoided decisions
- Long-term Positioning: Asks 5-year strategic questions
- Devil's Advocate: Argues against the user's path
- Portfolio Defender: Protects and compounds strengths (growth role)
- Opportunity Scout: Identifies adjacent opportunities (growth role)

## Guidelines
- Match roles to problems where they can add most value
- Growth roles should focus on appreciating problems
- Demands should be specific (10-30 words) and actionable
- Reference the actual problem in the demand

## Output Format
Return a JSON array with one object per role:
[
  {
    "roleType": "accountability",
    "problemIndex": 0,
    "demand": "Specific demand or question this role will focus on"
  },
  ...
]

Return ONLY the JSON array, no other text.
''';

    final problemsDesc = problems.asMap().entries.map((e) {
      final p = e.value;
      return 'Index ${e.key}: ${p.name} (${p.direction?.displayName ?? "unknown"}), ${p.timeAllocationPercent}% - What breaks: ${p.whatBreaks ?? "N/A"}';
    }).join('\n');

    final rolesDesc = roles.map((r) => '- ${r.name}: ${r.function}').join('\n');

    final focusHint = focusOnAppreciating
        ? '\nNote: These are growth roles - prefer anchoring to appreciating problems.'
        : '';

    final userPrompt = '''
Create anchoring for these board roles to these problems.

**Problems:**
$problemsDesc

**Roles to anchor:**
$rolesDesc
$focusHint

Generate the anchoring for each role.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 1024,
      );

      return _parseAnchoringResponse(response.content, roles);
    } on ClaudeError catch (e) {
      throw SetupAIError(
        'Failed to generate board anchoring: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  List<RoleAnchoring> _parseAnchoringResponse(
    String content,
    List<BoardRoleType> roles,
  ) {
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
      final anchorings = <RoleAnchoring>[];

      for (var i = 0; i < roles.length; i++) {
        if (i < json.length) {
          final item = json[i] as Map<String, dynamic>;
          anchorings.add(RoleAnchoring(
            roleType: roles[i],
            problemIndex: item['problemIndex'] as int? ?? 0,
            demand: item['demand'] as String? ?? roles[i].signatureQuestion,
          ));
        } else {
          // Fallback if AI didn't return enough entries
          anchorings.add(RoleAnchoring(
            roleType: roles[i],
            problemIndex: 0,
            demand: roles[i].signatureQuestion,
          ));
        }
      }

      return anchorings;
    } catch (e) {
      // Fallback - use default anchoring
      return roles.map((r) => RoleAnchoring(
        roleType: r,
        problemIndex: 0,
        demand: r.signatureQuestion,
      )).toList();
    }
  }

  /// Generates a persona for a board role.
  ///
  /// Per PRD Section 3.3.5:
  /// - PersonaProfile includes: brief background, communication style, signature phrases
  /// - All personas share baseline "warm-direct blunt" tone but differ in focus area
  Future<GeneratedPersona> generatePersona({
    required BoardRoleType roleType,
    SetupProblem? anchoredProblem,
    String? demand,
  }) async {
    const systemPrompt = '''
You are creating a persona for an AI career governance board member.

## Task
Generate a complete persona profile including:
1. Name (realistic first and last name)
2. Background (brief professional history, 20-50 words)
3. Communication style (10-25 words)
4. Signature phrase (optional, 5-15 words)

## Tone Guidelines
- Base tone: Warm-direct blunt (not harsh, but doesn't sugar-coat)
- Should feel like a trusted mentor or advisor
- Each role has a distinct focus area

## Output Format
Return a valid JSON object:
{
  "name": "First Last",
  "background": "Brief professional background...",
  "communicationStyle": "How they communicate...",
  "signaturePhrase": "Their catchphrase or common opening"
}

Return ONLY the JSON object, no other text.
''';

    final problemContext = anchoredProblem != null
        ? 'Anchored to problem: "${anchoredProblem.name}" (${anchoredProblem.direction?.displayName ?? "unknown"} direction)'
        : '';

    final demandContext = demand != null ? 'Focus demand: "$demand"' : '';

    final userPrompt = '''
Generate a persona for this board role:

**Role:** ${roleType.displayName}
**Function:** ${roleType.function}
**Interaction Style:** ${roleType.interactionStyle}
**Signature Question:** "${roleType.signatureQuestion}"
**Is Growth Role:** ${roleType.isGrowthRole}

$problemContext
$demandContext

Create a unique, memorable persona that embodies this role.
''';

    try {
      final response = await _client.sendMessage(
        systemPrompt: systemPrompt,
        userMessage: userPrompt,
        maxTokens: 512,
      );

      return _parsePersonaResponse(response.content, roleType);
    } on ClaudeError catch (e) {
      throw SetupAIError(
        'Failed to generate persona: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  GeneratedPersona _parsePersonaResponse(String content, BoardRoleType roleType) {
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
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return GeneratedPersona(
        name: json['name'] as String? ?? _getDefaultName(roleType),
        background: json['background'] as String? ?? _getDefaultBackground(roleType),
        communicationStyle: json['communicationStyle'] as String? ??
            _getDefaultCommunicationStyle(roleType),
        signaturePhrase: json['signaturePhrase'] as String?,
      );
    } catch (e) {
      // Return default persona if parsing fails
      return GeneratedPersona(
        name: _getDefaultName(roleType),
        background: _getDefaultBackground(roleType),
        communicationStyle: _getDefaultCommunicationStyle(roleType),
        signaturePhrase: null,
      );
    }
  }

  String _getDefaultName(BoardRoleType roleType) {
    switch (roleType) {
      case BoardRoleType.accountability:
        return 'Maya Chen';
      case BoardRoleType.marketReality:
        return 'Marcus Webb';
      case BoardRoleType.avoidance:
        return 'Sarah Blackwell';
      case BoardRoleType.longTermPositioning:
        return 'David Park';
      case BoardRoleType.devilsAdvocate:
        return 'Alexandra Reyes';
      case BoardRoleType.portfolioDefender:
        return 'James Morrison';
      case BoardRoleType.opportunityScout:
        return 'Priya Sharma';
    }
  }

  String _getDefaultBackground(BoardRoleType roleType) {
    switch (roleType) {
      case BoardRoleType.accountability:
        return 'Former executive coach with 15 years in high-performance environments. Known for holding leaders to their word.';
      case BoardRoleType.marketReality:
        return 'Tech industry veteran who has seen multiple disruption cycles. Data-driven and skeptical of narratives.';
      case BoardRoleType.avoidance:
        return 'Organizational psychologist specializing in leadership blind spots. Comfortable with uncomfortable conversations.';
      case BoardRoleType.longTermPositioning:
        return 'Strategy consultant who has guided dozens of career pivots. Always thinking about the long game.';
      case BoardRoleType.devilsAdvocate:
        return 'Former debate champion turned executive advisor. Questions everything to find the truth.';
      case BoardRoleType.portfolioDefender:
        return 'Investment mindset applied to careers. Believes in protecting and compounding advantages.';
      case BoardRoleType.opportunityScout:
        return 'Serial career changer who has found success in adjacent opportunities. Always curious about what is next.';
    }
  }

  String _getDefaultCommunicationStyle(BoardRoleType roleType) {
    switch (roleType) {
      case BoardRoleType.accountability:
        return 'Direct and evidence-focused. Asks for proof before accepting claims.';
      case BoardRoleType.marketReality:
        return 'Skeptical but fair. Backs up challenges with data and examples.';
      case BoardRoleType.avoidance:
        return 'Persistent and uncomfortable. Does not let you off the hook easily.';
      case BoardRoleType.longTermPositioning:
        return 'Forward-looking and strategic. Always connects today to tomorrow.';
      case BoardRoleType.devilsAdvocate:
        return 'Contrarian by design. Challenges your assumptions constructively.';
      case BoardRoleType.portfolioDefender:
        return 'Protective and growth-focused. Helps you see what you have to lose.';
      case BoardRoleType.opportunityScout:
        return 'Exploratory and curious. Sees connections you might miss.';
    }
  }

  /// Evaluates problem direction based on evidence.
  ///
  /// Per PRD Section 4.3: Evaluates direction based on AI cheaper,
  /// error cost, and trust required.
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
      throw SetupAIError(
        'Failed to evaluate direction: ${e.message}',
        isRetryable: e.isRetryable,
      );
    }
  }

  DirectionEvaluation _parseDirectionResponse(String content) {
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
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final directionStr = json['direction'] as String? ?? 'stable';
      final direction = _parseDirection(directionStr);

      return DirectionEvaluation(
        direction: direction,
        rationale: json['rationale'] as String? ?? '',
        confidence: json['confidence'] as String? ?? 'medium',
      );
    } catch (e) {
      throw SetupAIError(
        'Failed to parse direction response: $e',
        isRetryable: true,
      );
    }
  }

  String _parseDirection(String directionStr) {
    switch (directionStr.toLowerCase()) {
      case 'appreciating':
        return 'appreciating';
      case 'depreciating':
        return 'depreciating';
      default:
        return 'stable';
    }
  }
}

/// Result of health statement generation.
class HealthStatements {
  final String riskStatement;
  final String opportunityStatement;

  const HealthStatements({
    required this.riskStatement,
    required this.opportunityStatement,
  });
}

/// Role anchoring result.
class RoleAnchoring {
  final BoardRoleType roleType;
  final int? problemIndex;
  final String demand;

  const RoleAnchoring({
    required this.roleType,
    this.problemIndex,
    required this.demand,
  });
}

/// Generated persona profile.
class GeneratedPersona {
  final String name;
  final String background;
  final String communicationStyle;
  final String? signaturePhrase;

  const GeneratedPersona({
    required this.name,
    required this.background,
    required this.communicationStyle,
    this.signaturePhrase,
  });
}

/// Result of direction evaluation.
class DirectionEvaluation {
  final String direction;
  final String rationale;
  final String confidence;

  const DirectionEvaluation({
    required this.direction,
    required this.rationale,
    required this.confidence,
  });
}

/// Error during Setup AI operations.
class SetupAIError implements Exception {
  final String message;
  final bool isRetryable;

  const SetupAIError(this.message, {this.isRetryable = false});

  @override
  String toString() => 'SetupAIError: $message';
}
