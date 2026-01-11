import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/config.dart';
import '../middleware/auth_middleware.dart';
import '../models/api_models.dart';

/// AI proxy routes for external AI services.
///
/// Per PRD Section 3A.2:
/// - POST /ai/transcribe - Proxy to Deepgram for speech-to-text
/// - POST /ai/extract - Proxy to Claude for signal extraction
/// - POST /ai/generate - Proxy to Claude for brief generation
///
/// Per PRD:
/// - Claude Opus 4.5 for governance (Setup, Quarterly)
/// - Claude Sonnet 4.5 for daily operations (extraction, briefs)
/// - Deepgram Nova-2 for speech-to-text
class AiRoutes {
  final Config _config;
  final http.Client _httpClient;

  AiRoutes(this._config, [http.Client? httpClient])
      : _httpClient = httpClient ?? http.Client();

  Router get router {
    final router = Router();

    // Transcribe audio
    router.post('/transcribe', _handleTranscribe);

    // Extract signals from transcript
    router.post('/extract', _handleExtract);

    // Generate content (briefs, reviews, etc.)
    router.post('/generate', _handleGenerate);

    return router;
  }

  /// Transcribe audio using Deepgram Nova-2.
  ///
  /// Per PRD Section 4.1:
  /// - Max 15 minutes per recording (~2500 words)
  Future<Response> _handleTranscribe(Request request) async {
    // Ensure user is authenticated
    final _ = request.requiredUserId;

    if (_config.deepgramApiKey == null) {
      return _jsonResponse(
        503,
        ApiError.serviceUnavailable('Transcription service not configured').toJson(),
      );
    }

    final body = await request.readAsString();
    Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Invalid JSON body').toJson(),
      );
    }

    final transcribeRequest = TranscribeRequest.fromJson(json);

    // Validate audio size (approximate 15 min limit)
    final audioBytes = base64Decode(transcribeRequest.audioBase64);
    final maxBytes = 50 * 1024 * 1024; // 50MB max for audio

    if (audioBytes.length > maxBytes) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Audio file too large. Maximum size: 50MB').toJson(),
      );
    }

    try {
      // Call Deepgram API
      final response = await _callDeepgram(
        audioBytes,
        transcribeRequest.mimeType,
        transcribeRequest.language,
      );

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Transcription failed: $e').toJson(),
      );
    }
  }

  /// Extract signals from transcript using Claude Sonnet.
  ///
  /// Per PRD Section 3.1:
  /// Extracts 7 signal types: wins, blockers, risks, avoidedDecision,
  /// comfortWork, actions, learnings
  Future<Response> _handleExtract(Request request) async {
    final _ = request.requiredUserId;

    if (_config.claudeApiKey == null) {
      return _jsonResponse(
        503,
        ApiError.serviceUnavailable('AI service not configured').toJson(),
      );
    }

    final body = await request.readAsString();
    Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Invalid JSON body').toJson(),
      );
    }

    final extractRequest = ExtractRequest.fromJson(json);

    // Validate transcript length
    final wordCount = extractRequest.transcript.split(RegExp(r'\s+')).length;
    if (wordCount > 7500) {
      return _jsonResponse(
        400,
        ApiError.badRequest(
          'Transcript exceeds maximum length of 7500 words (current: $wordCount)',
        ).toJson(),
      );
    }

    try {
      // Call Claude API for signal extraction
      final response = await _callClaudeExtract(extractRequest.transcript);

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Signal extraction failed: $e').toJson(),
      );
    }
  }

  /// Generate content using Claude.
  ///
  /// Types:
  /// - weekly_brief: Generate weekly executive brief
  /// - board_review: Generate board micro-review
  /// - governance_output: Generate governance session output
  Future<Response> _handleGenerate(Request request) async {
    final _ = request.requiredUserId;

    if (_config.claudeApiKey == null) {
      return _jsonResponse(
        503,
        ApiError.serviceUnavailable('AI service not configured').toJson(),
      );
    }

    final body = await request.readAsString();
    Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      return _jsonResponse(
        400,
        ApiError.badRequest('Invalid JSON body').toJson(),
      );
    }

    final generateRequest = GenerateRequest.fromJson(json);

    // Validate type
    final validTypes = ['weekly_brief', 'board_review', 'governance_output'];
    if (!validTypes.contains(generateRequest.type)) {
      return _jsonResponse(
        400,
        ApiError.badRequest(
          'Invalid type. Must be one of: ${validTypes.join(", ")}',
        ).toJson(),
      );
    }

    try {
      // Call Claude API for content generation
      final response = await _callClaudeGenerate(generateRequest);

      return _jsonResponse(200, response.toJson());
    } catch (e) {
      return _jsonResponse(
        500,
        ApiError.serverError('Content generation failed: $e').toJson(),
      );
    }
  }

  /// Call Deepgram API for transcription.
  Future<TranscribeResponse> _callDeepgram(
    List<int> audioBytes,
    String mimeType,
    String? language,
  ) async {
    final url = Uri.parse('https://api.deepgram.com/v1/listen')
        .replace(queryParameters: {
      'model': 'nova-2',
      'smart_format': 'true',
      'punctuate': 'true',
      'diarize': 'false',
      if (language != null) 'language': language,
    });

    final response = await _httpClient.post(
      url,
      headers: {
        'Authorization': 'Token ${_config.deepgramApiKey}',
        'Content-Type': mimeType,
      },
      body: audioBytes,
    );

    if (response.statusCode != 200) {
      throw Exception('Deepgram API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as Map<String, dynamic>;
    final channels = results['channels'] as List<dynamic>;
    final channel = channels.first as Map<String, dynamic>;
    final alternatives = channel['alternatives'] as List<dynamic>;
    final alternative = alternatives.first as Map<String, dynamic>;

    final transcript = alternative['transcript'] as String;
    final confidence = alternative['confidence'] as double;
    final wordsData = alternative['words'] as List<dynamic>?;

    // Get duration from metadata
    final metadata = results['metadata'] as Map<String, dynamic>?;
    final duration = metadata?['duration'] as double? ?? 0.0;

    List<TranscriptWord>? words;
    if (wordsData != null) {
      words = wordsData.map((w) {
        final word = w as Map<String, dynamic>;
        return TranscriptWord(
          word: word['word'] as String,
          start: (word['start'] as num).toDouble(),
          end: (word['end'] as num).toDouble(),
          confidence: (word['confidence'] as num).toDouble(),
        );
      }).toList();
    }

    return TranscribeResponse(
      transcript: transcript,
      confidence: confidence,
      durationSeconds: duration.toInt(),
      words: words,
    );
  }

  /// Call Claude API for signal extraction.
  Future<ExtractResponse> _callClaudeExtract(String transcript) async {
    final prompt = '''Extract career signals from the following journal entry transcript.

Categorize each signal into one of these 7 types:
- wins: Completed accomplishments (things that were done)
- blockers: Current obstacles (things blocking progress now)
- risks: Potential future problems (upcoming issues to watch)
- avoidedDecision: Decisions being put off (things not being decided)
- comfortWork: Tasks that feel productive but don't advance goals
- actions: Forward commitments (things to do)
- learnings: Realizations and reflections

Return a JSON object with each signal type as a key and an array of extracted signals as the value.
Each signal should be a concise statement (one sentence max).
If no signals are found for a type, return an empty array.

Transcript:
$transcript

Return only valid JSON, no explanations or markdown.''';

    final response = await _callClaudeApi(
      prompt,
      model: 'claude-sonnet-4-20250514', // Sonnet for daily operations
      maxTokens: 2000,
    );

    // Parse the JSON response
    final signals = jsonDecode(response) as Map<String, dynamic>;

    return ExtractResponse(
      signals: signals.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).cast<String>(),
        ),
      ),
    );
  }

  /// Call Claude API for content generation.
  Future<GenerateResponse> _callClaudeGenerate(GenerateRequest request) async {
    String prompt;
    String model;
    int maxTokens;

    switch (request.type) {
      case 'weekly_brief':
        prompt = _buildWeeklyBriefPrompt(request.context);
        model = 'claude-sonnet-4-20250514'; // Sonnet for briefs
        maxTokens = 2000;
        break;

      case 'board_review':
        prompt = _buildBoardReviewPrompt(request.context);
        model = 'claude-sonnet-4-20250514';
        maxTokens = 500;
        break;

      case 'governance_output':
        prompt = _buildGovernancePrompt(request.context);
        model = 'claude-opus-4-20250514'; // Opus for governance
        maxTokens = 4000;
        break;

      default:
        throw ArgumentError('Unknown generation type: ${request.type}');
    }

    final content = await _callClaudeApi(
      prompt,
      model: model,
      maxTokens: maxTokens,
    );

    final wordCount = content.split(RegExp(r'\s+')).length;

    return GenerateResponse(
      content: content,
      wordCount: wordCount,
      model: model,
    );
  }

  /// Build prompt for weekly brief generation.
  String _buildWeeklyBriefPrompt(Map<String, dynamic> context) {
    final entries = context['entries'] as List<dynamic>?;
    final portfolio = context['portfolio'] as Map<String, dynamic>?;
    final previousBrief = context['previous_brief'] as String?;

    return '''Generate a weekly executive brief for a career journal.

Target length: 600 words (max 800 words).
Tone: Professional but personable, actionable insights.

${entries != null && entries.isNotEmpty ? '''
Journal entries this week:
${entries.map((e) => '- ${e['transcript_edited']}').join('\n')}
''' : 'No journal entries this week. Generate a reflection brief (~100 words) encouraging the user to journal.'}

${portfolio != null ? '''
Current portfolio context:
- Problems: ${portfolio['problems']}
- Directions: ${portfolio['directions']}
''' : ''}

${previousBrief != null ? '''
Previous week's brief for context:
$previousBrief
''' : ''}

Generate a markdown-formatted executive brief with:
1. Executive Summary (2-3 sentences)
2. Key Wins This Week
3. Challenges & Blockers
4. Strategic Insights
5. Actions for Next Week

Return only the markdown content.''';
  }

  /// Build prompt for board micro-review.
  String _buildBoardReviewPrompt(Map<String, dynamic> context) {
    final brief = context['brief'] as String;
    final boardMembers = context['board_members'] as List<dynamic>;

    final roles = boardMembers.map((m) {
      return '- ${m['role_type']}: ${m['persona_name']} - ${m['anchored_demand']}';
    }).join('\n');

    return '''Generate a brief board micro-review for a weekly brief.

Each board member should provide ONE sentence of feedback.
Target total: ~100 words.

Weekly brief summary:
$brief

Board members:
$roles

Generate one sentence from each board member, staying in character.
Format: **[Role Name] ([Persona Name]):** [One sentence feedback]

Return only the formatted review.''';
  }

  /// Build prompt for governance session output.
  String _buildGovernancePrompt(Map<String, dynamic> context) {
    final sessionType = context['session_type'] as String;
    final transcript = context['transcript'] as List<dynamic>;
    final portfolio = context['portfolio'] as Map<String, dynamic>?;

    final transcriptText = transcript.map((t) {
      return 'Q: ${t['question']}\nA: ${t['answer']}';
    }).join('\n\n');

    return '''Generate the output for a $sessionType governance session.

Session transcript:
$transcriptText

${portfolio != null ? '''
Current portfolio:
${jsonEncode(portfolio)}
''' : ''}

${sessionType == 'quick' ? '''
Generate a Quick Version (15-min audit) summary with:
1. Audit Summary (3-5 bullet points)
2. Key Insights
3. Recommended Actions
4. Accountability Check Results

Target: 400-500 words.
''' : sessionType == 'quarterly' ? '''
Generate a Quarterly Review report with:
1. Executive Summary
2. Portfolio Health Assessment
3. Direction Analysis (appreciating/depreciating/stable)
4. Board Interrogation Results
5. Bet Evaluation
6. Strategic Recommendations

Target: 800-1000 words.
''' : '''
Generate a Setup session summary with:
1. Portfolio Overview
2. Problem Breakdown
3. Direction Rationale
4. Board Anchoring Summary
5. Re-setup Triggers

Target: 600-800 words.
'''}

Return only the markdown content.''';
  }

  /// Call Claude API.
  Future<String> _callClaudeApi(
    String prompt, {
    required String model,
    required int maxTokens,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _config.claudeApiKey!,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    final textBlock = content.first as Map<String, dynamic>;

    return textBlock['text'] as String;
  }

  Response _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
