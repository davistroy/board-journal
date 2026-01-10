import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/data.dart';
import '../../models/export_format.dart';

/// Service for exporting user data to JSON and Markdown formats.
///
/// Per PRD data portability requirements, allows users to export
/// all their data for backup or migration purposes.
class ExportService {
  final DailyEntryRepository _dailyEntryRepo;
  final WeeklyBriefRepository _weeklyBriefRepo;
  final ProblemRepository _problemRepo;
  final PortfolioVersionRepository _portfolioVersionRepo;
  final BoardMemberRepository _boardMemberRepo;
  final GovernanceSessionRepository _governanceSessionRepo;
  final BetRepository _betRepo;
  final EvidenceItemRepository _evidenceItemRepo;
  final ReSetupTriggerRepository _reSetupTriggerRepo;
  final UserPreferencesRepository _userPreferencesRepo;

  ExportService({
    required DailyEntryRepository dailyEntryRepository,
    required WeeklyBriefRepository weeklyBriefRepository,
    required ProblemRepository problemRepository,
    required PortfolioVersionRepository portfolioVersionRepository,
    required BoardMemberRepository boardMemberRepository,
    required GovernanceSessionRepository governanceSessionRepository,
    required BetRepository betRepository,
    required EvidenceItemRepository evidenceItemRepository,
    required ReSetupTriggerRepository reSetupTriggerRepository,
    required UserPreferencesRepository userPreferencesRepository,
  })  : _dailyEntryRepo = dailyEntryRepository,
        _weeklyBriefRepo = weeklyBriefRepository,
        _problemRepo = problemRepository,
        _portfolioVersionRepo = portfolioVersionRepository,
        _boardMemberRepo = boardMemberRepository,
        _governanceSessionRepo = governanceSessionRepository,
        _betRepo = betRepository,
        _evidenceItemRepo = evidenceItemRepository,
        _reSetupTriggerRepo = reSetupTriggerRepository,
        _userPreferencesRepo = userPreferencesRepository;

  /// Gathers all exportable data from all repositories.
  Future<ExportData> getExportData() async {
    final dailyEntries = await _dailyEntryRepo.getAll();
    final weeklyBriefs = await _weeklyBriefRepo.getAll();
    final problems = await _problemRepo.getAll();
    final portfolioVersions = await _portfolioVersionRepo.getAll();
    final boardMembers = await _boardMemberRepo.getAll();
    final governanceSessions = await _governanceSessionRepo.getAll();
    final bets = await _betRepo.getAll();

    // Gather evidence items from all sessions
    final evidenceItems = <EvidenceItem>[];
    for (final session in governanceSessions) {
      final items = await _evidenceItemRepo.getBySession(session.id);
      evidenceItems.addAll(items);
    }

    final reSetupTriggers = await _reSetupTriggerRepo.getAll();
    final userPreferences = await _userPreferencesRepo.get();

    return ExportData(
      version: exportFormatVersion,
      exportedAt: DateTime.now().toUtc(),
      dailyEntries: dailyEntries,
      weeklyBriefs: weeklyBriefs,
      problems: problems,
      portfolioVersions: portfolioVersions,
      boardMembers: boardMembers,
      governanceSessions: governanceSessions,
      bets: bets,
      evidenceItems: evidenceItems,
      reSetupTriggers: reSetupTriggers,
      userPreferences: userPreferences,
    );
  }

  /// Exports all data to JSON format.
  Future<String> exportToJson() async {
    final data = await getExportData();
    return _convertToJson(data);
  }

  /// Converts export data to JSON string.
  String _convertToJson(ExportData data) {
    final json = {
      'version': data.version,
      'exportedAt': data.exportedAt.toIso8601String(),
      'data': {
        'dailyEntries': data.dailyEntries.map((e) => _dailyEntryToJson(e)).toList(),
        'weeklyBriefs': data.weeklyBriefs.map((b) => _weeklyBriefToJson(b)).toList(),
        'problems': data.problems.map((p) => _problemToJson(p)).toList(),
        'portfolioVersions': data.portfolioVersions.map((v) => _portfolioVersionToJson(v)).toList(),
        'boardMembers': data.boardMembers.map((m) => _boardMemberToJson(m)).toList(),
        'governanceSessions': data.governanceSessions.map((s) => _governanceSessionToJson(s)).toList(),
        'bets': data.bets.map((b) => _betToJson(b)).toList(),
        'evidenceItems': data.evidenceItems.map((e) => _evidenceItemToJson(e)).toList(),
        'reSetupTriggers': data.reSetupTriggers.map((t) => _reSetupTriggerToJson(t)).toList(),
        'userPreferences': data.userPreferences != null
            ? _userPreferencesToJson(data.userPreferences!)
            : null,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Exports all data to human-readable Markdown format.
  Future<String> exportToMarkdown() async {
    final data = await getExportData();
    return _convertToMarkdown(data);
  }

  /// Converts export data to Markdown string.
  String _convertToMarkdown(ExportData data) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    // Header
    buffer.writeln('# Boardroom Journal Export');
    buffer.writeln();
    buffer.writeln('**Exported:** ${dateFormat.format(data.exportedAt)}');
    buffer.writeln('**Version:** ${data.version}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Summary
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('| Data Type | Count |');
    buffer.writeln('|-----------|-------|');
    buffer.writeln('| Daily Entries | ${data.dailyEntries.length} |');
    buffer.writeln('| Weekly Briefs | ${data.weeklyBriefs.length} |');
    buffer.writeln('| Problems | ${data.problems.length} |');
    buffer.writeln('| Portfolio Versions | ${data.portfolioVersions.length} |');
    buffer.writeln('| Board Members | ${data.boardMembers.length} |');
    buffer.writeln('| Governance Sessions | ${data.governanceSessions.length} |');
    buffer.writeln('| Bets | ${data.bets.length} |');
    buffer.writeln('| Evidence Items | ${data.evidenceItems.length} |');
    buffer.writeln('| Re-Setup Triggers | ${data.reSetupTriggers.length} |');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Daily Entries
    if (data.dailyEntries.isNotEmpty) {
      buffer.writeln('## Daily Entries');
      buffer.writeln();
      for (final entry in data.dailyEntries) {
        buffer.writeln('### ${dateFormat.format(entry.createdAtUtc)}');
        buffer.writeln();
        buffer.writeln('**Type:** ${entry.entryType}');
        if (entry.wordCount != null) {
          buffer.writeln('**Words:** ${entry.wordCount}');
        }
        buffer.writeln();
        buffer.writeln(entry.transcriptEdited ?? entry.transcriptRaw);
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Weekly Briefs
    if (data.weeklyBriefs.isNotEmpty) {
      buffer.writeln('## Weekly Briefs');
      buffer.writeln();
      for (final brief in data.weeklyBriefs) {
        final weekRange = '${DateFormat('MMM d').format(brief.weekStartUtc)} - ${DateFormat('MMM d, yyyy').format(brief.weekEndUtc)}';
        buffer.writeln('### Week of $weekRange');
        buffer.writeln();
        buffer.writeln('**Generated:** ${dateFormat.format(brief.generatedAtUtc)}');
        buffer.writeln('**Entries:** ${brief.entryCount}');
        buffer.writeln();
        buffer.writeln(brief.briefMarkdown);
        buffer.writeln();
        if (brief.boardMicroReviewMarkdown != null) {
          buffer.writeln('#### Board Micro-Review');
          buffer.writeln();
          buffer.writeln(brief.boardMicroReviewMarkdown);
          buffer.writeln();
        }
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Problems (Portfolio)
    if (data.problems.isNotEmpty) {
      buffer.writeln('## Portfolio Problems');
      buffer.writeln();
      for (final problem in data.problems) {
        buffer.writeln('### ${problem.name}');
        buffer.writeln();
        buffer.writeln('**Direction:** ${problem.direction}');
        buffer.writeln('**Time Allocation:** ${problem.timeAllocationPercent}%');
        buffer.writeln();
        buffer.writeln('**What Breaks:** ${problem.whatBreaks}');
        buffer.writeln();
        buffer.writeln('**Direction Rationale:** ${problem.directionRationale}');
        buffer.writeln();
        buffer.writeln('#### Direction Evidence');
        buffer.writeln();
        buffer.writeln('- **AI Cheaper:** ${problem.evidenceAiCheaper}');
        buffer.writeln('- **Error Cost:** ${problem.evidenceErrorCost}');
        buffer.writeln('- **Trust Required:** ${problem.evidenceTrustRequired}');
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Board Members
    if (data.boardMembers.isNotEmpty) {
      buffer.writeln('## Board Members');
      buffer.writeln();
      for (final member in data.boardMembers) {
        buffer.writeln('### ${member.personaName}');
        buffer.writeln();
        buffer.writeln('**Role:** ${member.roleType}');
        buffer.writeln('**Type:** ${member.isGrowthRole ? 'Growth Role' : 'Core Role'}');
        buffer.writeln('**Status:** ${member.isActive ? 'Active' : 'Inactive'}');
        buffer.writeln();
        buffer.writeln('**Background:** ${member.personaBackground}');
        buffer.writeln();
        buffer.writeln('**Communication Style:** ${member.personaCommunicationStyle}');
        if (member.personaSignaturePhrase != null) {
          buffer.writeln();
          buffer.writeln('**Signature Phrase:** "${member.personaSignaturePhrase}"');
        }
        if (member.anchoredDemand != null) {
          buffer.writeln();
          buffer.writeln('**Demand:** ${member.anchoredDemand}');
        }
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Governance Sessions
    if (data.governanceSessions.isNotEmpty) {
      buffer.writeln('## Governance Sessions');
      buffer.writeln();
      for (final session in data.governanceSessions) {
        final typeDisplay = _getSessionTypeDisplay(session.sessionType);
        buffer.writeln('### $typeDisplay - ${dateFormat.format(session.startedAtUtc)}');
        buffer.writeln();
        buffer.writeln('**Status:** ${session.isCompleted ? 'Completed' : 'In Progress'}');
        if (session.durationSeconds != null) {
          buffer.writeln('**Duration:** ${_formatDuration(session.durationSeconds!)}');
        }
        if (session.abstractionMode) {
          buffer.writeln('**Mode:** Abstraction Mode');
        }
        buffer.writeln();
        if (session.outputMarkdown != null) {
          buffer.writeln('#### Output');
          buffer.writeln();
          buffer.writeln(session.outputMarkdown);
          buffer.writeln();
        }
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Bets
    if (data.bets.isNotEmpty) {
      buffer.writeln('## Bets');
      buffer.writeln();
      for (final bet in data.bets) {
        buffer.writeln('### Bet: ${bet.prediction.substring(0, bet.prediction.length > 50 ? 50 : bet.prediction.length)}...');
        buffer.writeln();
        buffer.writeln('**Status:** ${bet.status}');
        buffer.writeln('**Created:** ${dateFormat.format(bet.createdAtUtc)}');
        buffer.writeln('**Due:** ${dateFormat.format(bet.dueAtUtc)}');
        buffer.writeln();
        buffer.writeln('**Prediction:** ${bet.prediction}');
        buffer.writeln();
        buffer.writeln('**Wrong If:** ${bet.wrongIf}');
        if (bet.evaluationNotes != null) {
          buffer.writeln();
          buffer.writeln('**Evaluation Notes:** ${bet.evaluationNotes}');
        }
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    // Evidence Items
    if (data.evidenceItems.isNotEmpty) {
      buffer.writeln('## Evidence Items');
      buffer.writeln();
      for (final item in data.evidenceItems) {
        buffer.writeln('### ${item.evidenceType} Evidence');
        buffer.writeln();
        buffer.writeln('**Strength:** ${item.strengthFlag}');
        buffer.writeln('**Created:** ${dateFormat.format(item.createdAtUtc)}');
        buffer.writeln();
        buffer.writeln(item.statementText);
        if (item.context != null) {
          buffer.writeln();
          buffer.writeln('**Context:** ${item.context}');
        }
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Saves export content to a file in the app's documents directory.
  ///
  /// Returns the file path where the export was saved.
  Future<String> saveExportFile(String content, String format) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final extension = format.toLowerCase() == 'markdown' ? 'md' : 'json';
    final filename = 'boardroom_journal_export_$timestamp.$extension';
    final file = File('${directory.path}/$filename');

    await file.writeAsString(content);

    return file.path;
  }

  /// Gets a preview of what will be exported without generating full content.
  Future<ExportSummary> getExportPreview() async {
    final data = await getExportData();
    return data.summary;
  }

  // JSON conversion helpers for each data type
  Map<String, dynamic> _dailyEntryToJson(DailyEntry entry) {
    return {
      'id': entry.id,
      'transcriptRaw': entry.transcriptRaw,
      'transcriptEdited': entry.transcriptEdited,
      'extractedSignalsJson': entry.extractedSignalsJson,
      'entryType': entry.entryType,
      'wordCount': entry.wordCount,
      'durationSeconds': entry.durationSeconds,
      'createdAtUtc': entry.createdAtUtc.toIso8601String(),
      'createdAtTimezone': entry.createdAtTimezone,
      'updatedAtUtc': entry.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _weeklyBriefToJson(WeeklyBrief brief) {
    return {
      'id': brief.id,
      'weekStartUtc': brief.weekStartUtc.toIso8601String(),
      'weekEndUtc': brief.weekEndUtc.toIso8601String(),
      'weekTimezone': brief.weekTimezone,
      'briefMarkdown': brief.briefMarkdown,
      'boardMicroReviewMarkdown': brief.boardMicroReviewMarkdown,
      'entryCount': brief.entryCount,
      'regenCount': brief.regenCount,
      'regenOptionsJson': brief.regenOptionsJson,
      'microReviewCollapsed': brief.microReviewCollapsed,
      'generatedAtUtc': brief.generatedAtUtc.toIso8601String(),
      'updatedAtUtc': brief.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _problemToJson(Problem problem) {
    return {
      'id': problem.id,
      'name': problem.name,
      'whatBreaks': problem.whatBreaks,
      'scarcitySignalsJson': problem.scarcitySignalsJson,
      'direction': problem.direction,
      'directionRationale': problem.directionRationale,
      'evidenceAiCheaper': problem.evidenceAiCheaper,
      'evidenceErrorCost': problem.evidenceErrorCost,
      'evidenceTrustRequired': problem.evidenceTrustRequired,
      'timeAllocationPercent': problem.timeAllocationPercent,
      'displayOrder': problem.displayOrder,
      'createdAtUtc': problem.createdAtUtc.toIso8601String(),
      'updatedAtUtc': problem.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _portfolioVersionToJson(PortfolioVersion version) {
    return {
      'id': version.id,
      'versionNumber': version.versionNumber,
      'problemsSnapshotJson': version.problemsSnapshotJson,
      'healthSnapshotJson': version.healthSnapshotJson,
      'boardAnchoringSnapshotJson': version.boardAnchoringSnapshotJson,
      'triggersSnapshotJson': version.triggersSnapshotJson,
      'triggerReason': version.triggerReason,
      'createdAtUtc': version.createdAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _boardMemberToJson(BoardMember member) {
    return {
      'id': member.id,
      'roleType': member.roleType,
      'isGrowthRole': member.isGrowthRole,
      'isActive': member.isActive,
      'anchoredProblemId': member.anchoredProblemId,
      'anchoredDemand': member.anchoredDemand,
      'personaName': member.personaName,
      'personaBackground': member.personaBackground,
      'personaCommunicationStyle': member.personaCommunicationStyle,
      'personaSignaturePhrase': member.personaSignaturePhrase,
      'originalPersonaName': member.originalPersonaName,
      'originalPersonaBackground': member.originalPersonaBackground,
      'originalPersonaCommunicationStyle': member.originalPersonaCommunicationStyle,
      'originalPersonaSignaturePhrase': member.originalPersonaSignaturePhrase,
      'createdAtUtc': member.createdAtUtc.toIso8601String(),
      'updatedAtUtc': member.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _governanceSessionToJson(GovernanceSession session) {
    return {
      'id': session.id,
      'sessionType': session.sessionType,
      'currentState': session.currentState,
      'abstractionMode': session.abstractionMode,
      'vaguenessSkipCount': session.vaguenessSkipCount,
      'transcriptJson': session.transcriptJson,
      'isCompleted': session.isCompleted,
      'outputMarkdown': session.outputMarkdown,
      'createdPortfolioVersionId': session.createdPortfolioVersionId,
      'evaluatedBetId': session.evaluatedBetId,
      'createdBetId': session.createdBetId,
      'durationSeconds': session.durationSeconds,
      'startedAtUtc': session.startedAtUtc.toIso8601String(),
      'completedAtUtc': session.completedAtUtc?.toIso8601String(),
      'updatedAtUtc': session.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _betToJson(Bet bet) {
    return {
      'id': bet.id,
      'prediction': bet.prediction,
      'wrongIf': bet.wrongIf,
      'status': bet.status,
      'sourceSessionId': bet.sourceSessionId,
      'evaluationNotes': bet.evaluationNotes,
      'evaluationSessionId': bet.evaluationSessionId,
      'createdAtUtc': bet.createdAtUtc.toIso8601String(),
      'dueAtUtc': bet.dueAtUtc.toIso8601String(),
      'evaluatedAtUtc': bet.evaluatedAtUtc?.toIso8601String(),
      'updatedAtUtc': bet.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _evidenceItemToJson(EvidenceItem item) {
    return {
      'id': item.id,
      'sessionId': item.sessionId,
      'problemId': item.problemId,
      'evidenceType': item.evidenceType,
      'statementText': item.statementText,
      'strengthFlag': item.strengthFlag,
      'context': item.context,
      'createdAtUtc': item.createdAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _reSetupTriggerToJson(ReSetupTrigger trigger) {
    return {
      'id': trigger.id,
      'triggerType': trigger.triggerType,
      'description': trigger.description,
      'condition': trigger.condition,
      'recommendedAction': trigger.recommendedAction,
      'isMet': trigger.isMet,
      'metAtUtc': trigger.metAtUtc?.toIso8601String(),
      'dueAtUtc': trigger.dueAtUtc?.toIso8601String(),
      'createdAtUtc': trigger.createdAtUtc.toIso8601String(),
      'updatedAtUtc': trigger.updatedAtUtc.toIso8601String(),
    };
  }

  Map<String, dynamic> _userPreferencesToJson(UserPreference prefs) {
    return {
      'id': prefs.id,
      'abstractionModeQuick': prefs.abstractionModeQuick,
      'abstractionModeSetup': prefs.abstractionModeSetup,
      'abstractionModeQuarterly': prefs.abstractionModeQuarterly,
      'rememberAbstractionChoice': prefs.rememberAbstractionChoice,
      'analyticsEnabled': prefs.analyticsEnabled,
      'microReviewCollapsed': prefs.microReviewCollapsed,
      'onboardingCompleted': prefs.onboardingCompleted,
      'setupPromptDismissed': prefs.setupPromptDismissed,
      'setupPromptLastShownUtc': prefs.setupPromptLastShownUtc?.toIso8601String(),
      'totalEntryCount': prefs.totalEntryCount,
      'createdAtUtc': prefs.createdAtUtc.toIso8601String(),
      'updatedAtUtc': prefs.updatedAtUtc.toIso8601String(),
    };
  }

  String _getSessionTypeDisplay(String sessionType) {
    switch (sessionType) {
      case 'quick':
        return 'Quick Audit';
      case 'setup':
        return 'Setup';
      case 'quarterly':
        return 'Quarterly Review';
      default:
        return 'Governance Session';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes min ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }
}
