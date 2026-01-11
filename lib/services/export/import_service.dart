import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/data.dart';
import '../../models/export_format.dart';

/// Service for importing user data from JSON format.
///
/// Per PRD data portability requirements, allows users to restore
/// their data from a backup or migrate from another device.
class ImportService {
  final AppDatabase _db;
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

  ImportService({
    required AppDatabase database,
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
  })  : _db = database,
        _dailyEntryRepo = dailyEntryRepository,
        _weeklyBriefRepo = weeklyBriefRepository,
        _problemRepo = problemRepository,
        _portfolioVersionRepo = portfolioVersionRepository,
        _boardMemberRepo = boardMemberRepository,
        _governanceSessionRepo = governanceSessionRepository,
        _betRepo = betRepository,
        _evidenceItemRepo = evidenceItemRepository,
        _reSetupTriggerRepo = reSetupTriggerRepository,
        _userPreferencesRepo = userPreferencesRepository;

  /// Validates an import file and returns validation result.
  ///
  /// Checks:
  /// - JSON format is valid
  /// - Required fields are present
  /// - Version is compatible
  /// - Data structures match expected format
  ImportValidationResult validateImportFile(String content) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check if content is valid JSON
    Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return ImportValidationResult.failure(['Invalid JSON format: $e']);
    }

    // Check required top-level fields
    if (!json.containsKey('version')) {
      errors.add('Missing required field: version');
    }
    if (!json.containsKey('exportedAt')) {
      errors.add('Missing required field: exportedAt');
    }
    if (!json.containsKey('data')) {
      errors.add('Missing required field: data');
    }

    if (errors.isNotEmpty) {
      return ImportValidationResult.failure(errors);
    }

    // Check version compatibility
    final version = json['version'] as String?;
    if (version == null) {
      errors.add('Version field is null');
    } else if (!_isVersionCompatible(version)) {
      warnings.add('Export version ($version) differs from current version ($exportFormatVersion). Some data may not import correctly.');
    }

    // Validate exportedAt timestamp
    try {
      DateTime.parse(json['exportedAt'] as String);
    } catch (e) {
      errors.add('Invalid exportedAt timestamp: ${json['exportedAt']}');
    }

    if (errors.isNotEmpty) {
      return ImportValidationResult.failure(errors);
    }

    // Try to parse the full data
    try {
      final data = parseImportFile(content);
      return ImportValidationResult.success(data, warnings: warnings);
    } catch (e) {
      return ImportValidationResult.failure(['Failed to parse export data: $e']);
    }
  }

  /// Parses an import file into ExportData structure.
  ///
  /// Throws if the content is invalid.
  ExportData parseImportFile(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>;

    return ExportData(
      version: json['version'] as String,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      dailyEntries: _parseDailyEntries(data['dailyEntries'] as List?),
      weeklyBriefs: _parseWeeklyBriefs(data['weeklyBriefs'] as List?),
      problems: _parseProblems(data['problems'] as List?),
      portfolioVersions: _parsePortfolioVersions(data['portfolioVersions'] as List?),
      boardMembers: _parseBoardMembers(data['boardMembers'] as List?),
      governanceSessions: _parseGovernanceSessions(data['governanceSessions'] as List?),
      bets: _parseBets(data['bets'] as List?),
      evidenceItems: _parseEvidenceItems(data['evidenceItems'] as List?),
      reSetupTriggers: _parseReSetupTriggers(data['reSetupTriggers'] as List?),
      userPreferences: data['userPreferences'] != null
          ? _parseUserPreferences(data['userPreferences'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Returns a preview of what will be imported.
  ExportSummary previewImport(String content) {
    final validationResult = validateImportFile(content);
    if (!validationResult.isValid || validationResult.data == null) {
      return const ExportSummary();
    }
    return validationResult.data!.summary;
  }

  /// Performs the import with the specified conflict strategy.
  Future<ImportResult> importData(
    ExportData data,
    ConflictStrategy strategy,
  ) async {
    final importedCounts = <String, int>{};
    final skippedCounts = <String, int>{};
    final errorCounts = <String, int>{};
    final errors = <String>[];

    try {
      // Import each data type
      await _importDailyEntries(data.dailyEntries, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importWeeklyBriefs(data.weeklyBriefs, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importProblems(data.problems, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importPortfolioVersions(data.portfolioVersions, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importBoardMembers(data.boardMembers, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importGovernanceSessions(data.governanceSessions, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importBets(data.bets, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importEvidenceItems(data.evidenceItems, strategy, importedCounts, skippedCounts, errorCounts, errors);
      await _importReSetupTriggers(data.reSetupTriggers, strategy, importedCounts, skippedCounts, errorCounts, errors);

      if (data.userPreferences != null) {
        await _importUserPreferences(data.userPreferences!, strategy, importedCounts, skippedCounts, errorCounts, errors);
      }

      return ImportResult(
        success: errors.isEmpty,
        importedCounts: importedCounts,
        skippedCounts: skippedCounts,
        errorCounts: errorCounts,
        errors: errors,
      );
    } catch (e) {
      return ImportResult.failure(['Import failed: $e']);
    }
  }

  bool _isVersionCompatible(String version) {
    // For now, accept version 1.x
    return version.startsWith('1.');
  }

  // Parse helpers
  List<DailyEntry> _parseDailyEntries(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseDailyEntry(e as Map<String, dynamic>)).toList();
  }

  DailyEntry _parseDailyEntry(Map<String, dynamic> json) {
    return DailyEntry(
      id: json['id'] as String,
      transcriptRaw: json['transcriptRaw'] as String,
      transcriptEdited: json['transcriptEdited'] as String,
      extractedSignalsJson: json['extractedSignalsJson'] as String? ?? '{}',
      entryType: json['entryType'] as String,
      wordCount: json['wordCount'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      createdAtTimezone: json['createdAtTimezone'] as String,
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<WeeklyBrief> _parseWeeklyBriefs(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseWeeklyBrief(e as Map<String, dynamic>)).toList();
  }

  WeeklyBrief _parseWeeklyBrief(Map<String, dynamic> json) {
    return WeeklyBrief(
      id: json['id'] as String,
      weekStartUtc: DateTime.parse(json['weekStartUtc'] as String),
      weekEndUtc: DateTime.parse(json['weekEndUtc'] as String),
      weekTimezone: json['weekTimezone'] as String,
      briefMarkdown: json['briefMarkdown'] as String,
      boardMicroReviewMarkdown: json['boardMicroReviewMarkdown'] as String?,
      entryCount: json['entryCount'] as int? ?? 0,
      regenCount: json['regenCount'] as int? ?? 0,
      regenOptionsJson: json['regenOptionsJson'] as String? ?? '[]',
      microReviewCollapsed: json['microReviewCollapsed'] as bool? ?? false,
      generatedAtUtc: DateTime.parse(json['generatedAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<Problem> _parseProblems(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseProblem(e as Map<String, dynamic>)).toList();
  }

  Problem _parseProblem(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] as String,
      name: json['name'] as String,
      whatBreaks: json['whatBreaks'] as String,
      scarcitySignalsJson: json['scarcitySignalsJson'] as String,
      direction: json['direction'] as String,
      directionRationale: json['directionRationale'] as String,
      evidenceAiCheaper: json['evidenceAiCheaper'] as String,
      evidenceErrorCost: json['evidenceErrorCost'] as String,
      evidenceTrustRequired: json['evidenceTrustRequired'] as String,
      timeAllocationPercent: json['timeAllocationPercent'] as int,
      displayOrder: json['displayOrder'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<PortfolioVersion> _parsePortfolioVersions(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parsePortfolioVersion(e as Map<String, dynamic>)).toList();
  }

  PortfolioVersion _parsePortfolioVersion(Map<String, dynamic> json) {
    return PortfolioVersion(
      id: json['id'] as String,
      versionNumber: json['versionNumber'] as int,
      problemsSnapshotJson: json['problemsSnapshotJson'] as String,
      healthSnapshotJson: json['healthSnapshotJson'] as String,
      boardAnchoringSnapshotJson: json['boardAnchoringSnapshotJson'] as String,
      triggersSnapshotJson: json['triggersSnapshotJson'] as String,
      triggerReason: json['triggerReason'] as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<BoardMember> _parseBoardMembers(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseBoardMember(e as Map<String, dynamic>)).toList();
  }

  BoardMember _parseBoardMember(Map<String, dynamic> json) {
    return BoardMember(
      id: json['id'] as String,
      roleType: json['roleType'] as String,
      isGrowthRole: json['isGrowthRole'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      anchoredProblemId: json['anchoredProblemId'] as String?,
      anchoredDemand: json['anchoredDemand'] as String?,
      personaName: json['personaName'] as String,
      personaBackground: json['personaBackground'] as String,
      personaCommunicationStyle: json['personaCommunicationStyle'] as String,
      personaSignaturePhrase: json['personaSignaturePhrase'] as String?,
      originalPersonaName: json['originalPersonaName'] as String,
      originalPersonaBackground: json['originalPersonaBackground'] as String,
      originalPersonaCommunicationStyle: json['originalPersonaCommunicationStyle'] as String,
      originalPersonaSignaturePhrase: json['originalPersonaSignaturePhrase'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<GovernanceSession> _parseGovernanceSessions(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseGovernanceSession(e as Map<String, dynamic>)).toList();
  }

  GovernanceSession _parseGovernanceSession(Map<String, dynamic> json) {
    return GovernanceSession(
      id: json['id'] as String,
      sessionType: json['sessionType'] as String,
      currentState: json['currentState'] as String,
      abstractionMode: json['abstractionMode'] as bool? ?? false,
      vaguenessSkipCount: json['vaguenessSkipCount'] as int? ?? 0,
      transcriptJson: json['transcriptJson'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      outputMarkdown: json['outputMarkdown'] as String?,
      createdPortfolioVersionId: json['createdPortfolioVersionId'] as String?,
      evaluatedBetId: json['evaluatedBetId'] as String?,
      createdBetId: json['createdBetId'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      startedAtUtc: DateTime.parse(json['startedAtUtc'] as String),
      completedAtUtc: json['completedAtUtc'] != null
          ? DateTime.parse(json['completedAtUtc'] as String)
          : null,
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<Bet> _parseBets(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseBet(e as Map<String, dynamic>)).toList();
  }

  Bet _parseBet(Map<String, dynamic> json) {
    return Bet(
      id: json['id'] as String,
      prediction: json['prediction'] as String,
      wrongIf: json['wrongIf'] as String,
      status: json['status'] as String? ?? 'open',
      sourceSessionId: json['sourceSessionId'] as String?,
      evaluationNotes: json['evaluationNotes'] as String?,
      evaluationSessionId: json['evaluationSessionId'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      dueAtUtc: DateTime.parse(json['dueAtUtc'] as String),
      evaluatedAtUtc: json['evaluatedAtUtc'] != null
          ? DateTime.parse(json['evaluatedAtUtc'] as String)
          : null,
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      deletedAtUtc: null,
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<EvidenceItem> _parseEvidenceItems(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseEvidenceItem(e as Map<String, dynamic>)).toList();
  }

  EvidenceItem _parseEvidenceItem(Map<String, dynamic> json) {
    return EvidenceItem(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      problemId: json['problemId'] as String?,
      evidenceType: json['evidenceType'] as String,
      statementText: json['statementText'] as String,
      strengthFlag: json['strengthFlag'] as String,
      context: json['context'] as String?,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  List<ReSetupTrigger> _parseReSetupTriggers(List? jsonList) {
    if (jsonList == null) return [];
    return jsonList.map((e) => _parseReSetupTrigger(e as Map<String, dynamic>)).toList();
  }

  ReSetupTrigger _parseReSetupTrigger(Map<String, dynamic> json) {
    return ReSetupTrigger(
      id: json['id'] as String,
      triggerType: json['triggerType'] as String,
      description: json['description'] as String,
      condition: json['condition'] as String,
      recommendedAction: json['recommendedAction'] as String,
      isMet: json['isMet'] as bool? ?? false,
      metAtUtc: json['metAtUtc'] != null
          ? DateTime.parse(json['metAtUtc'] as String)
          : null,
      dueAtUtc: json['dueAtUtc'] != null
          ? DateTime.parse(json['dueAtUtc'] as String)
          : null,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  UserPreference _parseUserPreferences(Map<String, dynamic> json) {
    return UserPreference(
      id: json['id'] as String,
      abstractionModeQuick: json['abstractionModeQuick'] as bool? ?? false,
      abstractionModeSetup: json['abstractionModeSetup'] as bool? ?? false,
      abstractionModeQuarterly: json['abstractionModeQuarterly'] as bool? ?? false,
      rememberAbstractionChoice: json['rememberAbstractionChoice'] as bool? ?? true,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      microReviewCollapsed: json['microReviewCollapsed'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      setupPromptDismissed: json['setupPromptDismissed'] as bool? ?? false,
      setupPromptLastShownUtc: json['setupPromptLastShownUtc'] != null
          ? DateTime.parse(json['setupPromptLastShownUtc'] as String)
          : null,
      totalEntryCount: json['totalEntryCount'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String),
      syncStatus: 'pending',
      serverVersion: 0,
    );
  }

  // Import helpers
  Future<void> _importDailyEntries(
    List<DailyEntry> entries,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'dailyEntries';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final entry in entries) {
      try {
        final existing = await _dailyEntryRepo.getById(entry.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(entry.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          // Overwrite or merge (imported is newer)
          await _updateDailyEntry(entry);
        } else {
          await _insertDailyEntry(entry);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import daily entry ${entry.id}: $e');
      }
    }
  }

  Future<void> _insertDailyEntry(DailyEntry entry) async {
    await _db.into(_db.dailyEntries).insert(
      DailyEntriesCompanion.insert(
        id: entry.id,
        transcriptRaw: entry.transcriptRaw,
        transcriptEdited: entry.transcriptEdited,
        extractedSignalsJson: Value(entry.extractedSignalsJson),
        entryType: entry.entryType,
        wordCount: Value(entry.wordCount),
        durationSeconds: Value(entry.durationSeconds),
        createdAtUtc: entry.createdAtUtc,
        createdAtTimezone: entry.createdAtTimezone,
        updatedAtUtc: entry.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateDailyEntry(DailyEntry entry) async {
    await (_db.update(_db.dailyEntries)..where((e) => e.id.equals(entry.id))).write(
      DailyEntriesCompanion(
        transcriptRaw: Value(entry.transcriptRaw),
        transcriptEdited: Value(entry.transcriptEdited),
        extractedSignalsJson: Value(entry.extractedSignalsJson),
        entryType: Value(entry.entryType),
        wordCount: Value(entry.wordCount),
        durationSeconds: Value(entry.durationSeconds),
        updatedAtUtc: Value(entry.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importWeeklyBriefs(
    List<WeeklyBrief> briefs,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'weeklyBriefs';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final brief in briefs) {
      try {
        final existing = await _weeklyBriefRepo.getById(brief.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(brief.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateWeeklyBrief(brief);
        } else {
          await _insertWeeklyBrief(brief);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import weekly brief ${brief.id}: $e');
      }
    }
  }

  Future<void> _insertWeeklyBrief(WeeklyBrief brief) async {
    await _db.into(_db.weeklyBriefs).insert(
      WeeklyBriefsCompanion.insert(
        id: brief.id,
        weekStartUtc: brief.weekStartUtc,
        weekEndUtc: brief.weekEndUtc,
        weekTimezone: brief.weekTimezone,
        briefMarkdown: brief.briefMarkdown,
        boardMicroReviewMarkdown: Value(brief.boardMicroReviewMarkdown),
        entryCount: Value(brief.entryCount),
        regenCount: Value(brief.regenCount),
        regenOptionsJson: Value(brief.regenOptionsJson),
        microReviewCollapsed: Value(brief.microReviewCollapsed),
        generatedAtUtc: brief.generatedAtUtc,
        updatedAtUtc: brief.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateWeeklyBrief(WeeklyBrief brief) async {
    await (_db.update(_db.weeklyBriefs)..where((b) => b.id.equals(brief.id))).write(
      WeeklyBriefsCompanion(
        weekStartUtc: Value(brief.weekStartUtc),
        weekEndUtc: Value(brief.weekEndUtc),
        weekTimezone: Value(brief.weekTimezone),
        briefMarkdown: Value(brief.briefMarkdown),
        boardMicroReviewMarkdown: Value(brief.boardMicroReviewMarkdown),
        entryCount: Value(brief.entryCount),
        regenCount: Value(brief.regenCount),
        regenOptionsJson: Value(brief.regenOptionsJson),
        microReviewCollapsed: Value(brief.microReviewCollapsed),
        updatedAtUtc: Value(brief.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importProblems(
    List<Problem> problems,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'problems';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final problem in problems) {
      try {
        final existing = await _problemRepo.getById(problem.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(problem.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateProblem(problem);
        } else {
          await _insertProblem(problem);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import problem ${problem.id}: $e');
      }
    }
  }

  Future<void> _insertProblem(Problem problem) async {
    await _db.into(_db.problems).insert(
      ProblemsCompanion.insert(
        id: problem.id,
        name: problem.name,
        whatBreaks: problem.whatBreaks,
        scarcitySignalsJson: problem.scarcitySignalsJson,
        direction: problem.direction,
        directionRationale: problem.directionRationale,
        evidenceAiCheaper: problem.evidenceAiCheaper,
        evidenceErrorCost: problem.evidenceErrorCost,
        evidenceTrustRequired: problem.evidenceTrustRequired,
        timeAllocationPercent: problem.timeAllocationPercent,
        displayOrder: Value(problem.displayOrder),
        createdAtUtc: problem.createdAtUtc,
        updatedAtUtc: problem.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateProblem(Problem problem) async {
    await (_db.update(_db.problems)..where((p) => p.id.equals(problem.id))).write(
      ProblemsCompanion(
        name: Value(problem.name),
        whatBreaks: Value(problem.whatBreaks),
        scarcitySignalsJson: Value(problem.scarcitySignalsJson),
        direction: Value(problem.direction),
        directionRationale: Value(problem.directionRationale),
        evidenceAiCheaper: Value(problem.evidenceAiCheaper),
        evidenceErrorCost: Value(problem.evidenceErrorCost),
        evidenceTrustRequired: Value(problem.evidenceTrustRequired),
        timeAllocationPercent: Value(problem.timeAllocationPercent),
        displayOrder: Value(problem.displayOrder),
        updatedAtUtc: Value(problem.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importPortfolioVersions(
    List<PortfolioVersion> versions,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'portfolioVersions';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final version in versions) {
      try {
        final existing = await _portfolioVersionRepo.getById(version.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip || strategy == ConflictStrategy.merge) {
            // Portfolio versions are immutable, always skip if exists
            skipped[type] = skipped[type]! + 1;
            continue;
          }
          // Overwrite (delete and reinsert)
          await _db.delete(_db.portfolioVersions).go();
          await _insertPortfolioVersion(version);
        } else {
          await _insertPortfolioVersion(version);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import portfolio version ${version.id}: $e');
      }
    }
  }

  Future<void> _insertPortfolioVersion(PortfolioVersion version) async {
    await _db.into(_db.portfolioVersions).insert(
      PortfolioVersionsCompanion.insert(
        id: version.id,
        versionNumber: version.versionNumber,
        problemsSnapshotJson: version.problemsSnapshotJson,
        healthSnapshotJson: version.healthSnapshotJson,
        boardAnchoringSnapshotJson: version.boardAnchoringSnapshotJson,
        triggersSnapshotJson: version.triggersSnapshotJson,
        triggerReason: version.triggerReason,
        createdAtUtc: version.createdAtUtc,
      ),
    );
  }

  Future<void> _importBoardMembers(
    List<BoardMember> members,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'boardMembers';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final member in members) {
      try {
        final existing = await _boardMemberRepo.getById(member.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(member.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateBoardMember(member);
        } else {
          await _insertBoardMember(member);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import board member ${member.id}: $e');
      }
    }
  }

  Future<void> _insertBoardMember(BoardMember member) async {
    await _db.into(_db.boardMembers).insert(
      BoardMembersCompanion.insert(
        id: member.id,
        roleType: member.roleType,
        isGrowthRole: Value(member.isGrowthRole),
        isActive: Value(member.isActive),
        anchoredProblemId: Value(member.anchoredProblemId),
        anchoredDemand: Value(member.anchoredDemand),
        personaName: member.personaName,
        personaBackground: member.personaBackground,
        personaCommunicationStyle: member.personaCommunicationStyle,
        personaSignaturePhrase: Value(member.personaSignaturePhrase),
        originalPersonaName: member.originalPersonaName,
        originalPersonaBackground: member.originalPersonaBackground,
        originalPersonaCommunicationStyle: member.originalPersonaCommunicationStyle,
        originalPersonaSignaturePhrase: Value(member.originalPersonaSignaturePhrase),
        createdAtUtc: member.createdAtUtc,
        updatedAtUtc: member.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateBoardMember(BoardMember member) async {
    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(member.id))).write(
      BoardMembersCompanion(
        roleType: Value(member.roleType),
        isGrowthRole: Value(member.isGrowthRole),
        isActive: Value(member.isActive),
        anchoredProblemId: Value(member.anchoredProblemId),
        anchoredDemand: Value(member.anchoredDemand),
        personaName: Value(member.personaName),
        personaBackground: Value(member.personaBackground),
        personaCommunicationStyle: Value(member.personaCommunicationStyle),
        personaSignaturePhrase: Value(member.personaSignaturePhrase),
        originalPersonaName: Value(member.originalPersonaName),
        originalPersonaBackground: Value(member.originalPersonaBackground),
        originalPersonaCommunicationStyle: Value(member.originalPersonaCommunicationStyle),
        originalPersonaSignaturePhrase: Value(member.originalPersonaSignaturePhrase),
        updatedAtUtc: Value(member.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importGovernanceSessions(
    List<GovernanceSession> sessions,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'governanceSessions';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final session in sessions) {
      try {
        final existing = await _governanceSessionRepo.getById(session.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(session.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateGovernanceSession(session);
        } else {
          await _insertGovernanceSession(session);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import governance session ${session.id}: $e');
      }
    }
  }

  Future<void> _insertGovernanceSession(GovernanceSession session) async {
    await _db.into(_db.governanceSessions).insert(
      GovernanceSessionsCompanion.insert(
        id: session.id,
        sessionType: session.sessionType,
        currentState: session.currentState,
        abstractionMode: Value(session.abstractionMode),
        vaguenessSkipCount: Value(session.vaguenessSkipCount),
        transcriptJson: Value(session.transcriptJson),
        isCompleted: Value(session.isCompleted),
        outputMarkdown: Value(session.outputMarkdown),
        createdPortfolioVersionId: Value(session.createdPortfolioVersionId),
        evaluatedBetId: Value(session.evaluatedBetId),
        createdBetId: Value(session.createdBetId),
        durationSeconds: Value(session.durationSeconds),
        startedAtUtc: session.startedAtUtc,
        completedAtUtc: Value(session.completedAtUtc),
        updatedAtUtc: session.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateGovernanceSession(GovernanceSession session) async {
    await (_db.update(_db.governanceSessions)..where((s) => s.id.equals(session.id))).write(
      GovernanceSessionsCompanion(
        sessionType: Value(session.sessionType),
        currentState: Value(session.currentState),
        abstractionMode: Value(session.abstractionMode),
        vaguenessSkipCount: Value(session.vaguenessSkipCount),
        transcriptJson: Value(session.transcriptJson),
        isCompleted: Value(session.isCompleted),
        outputMarkdown: Value(session.outputMarkdown),
        createdPortfolioVersionId: Value(session.createdPortfolioVersionId),
        evaluatedBetId: Value(session.evaluatedBetId),
        createdBetId: Value(session.createdBetId),
        durationSeconds: Value(session.durationSeconds),
        completedAtUtc: Value(session.completedAtUtc),
        updatedAtUtc: Value(session.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importBets(
    List<Bet> bets,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'bets';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final bet in bets) {
      try {
        final existing = await _betRepo.getById(bet.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(bet.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateBet(bet);
        } else {
          await _insertBet(bet);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import bet ${bet.id}: $e');
      }
    }
  }

  Future<void> _insertBet(Bet bet) async {
    await _db.into(_db.bets).insert(
      BetsCompanion.insert(
        id: bet.id,
        prediction: bet.prediction,
        wrongIf: bet.wrongIf,
        status: Value(bet.status),
        sourceSessionId: Value(bet.sourceSessionId),
        evaluationNotes: Value(bet.evaluationNotes),
        evaluationSessionId: Value(bet.evaluationSessionId),
        createdAtUtc: bet.createdAtUtc,
        dueAtUtc: bet.dueAtUtc,
        evaluatedAtUtc: Value(bet.evaluatedAtUtc),
        updatedAtUtc: bet.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateBet(Bet bet) async {
    await (_db.update(_db.bets)..where((b) => b.id.equals(bet.id))).write(
      BetsCompanion(
        prediction: Value(bet.prediction),
        wrongIf: Value(bet.wrongIf),
        status: Value(bet.status),
        sourceSessionId: Value(bet.sourceSessionId),
        evaluationNotes: Value(bet.evaluationNotes),
        evaluationSessionId: Value(bet.evaluationSessionId),
        dueAtUtc: Value(bet.dueAtUtc),
        evaluatedAtUtc: Value(bet.evaluatedAtUtc),
        updatedAtUtc: Value(bet.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importEvidenceItems(
    List<EvidenceItem> items,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'evidenceItems';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final item in items) {
      try {
        final existing = await _evidenceItemRepo.getById(item.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip || strategy == ConflictStrategy.merge) {
            // Evidence items are immutable
            skipped[type] = skipped[type]! + 1;
            continue;
          }
          // Overwrite - delete and reinsert
          await (_db.delete(_db.evidenceItems)..where((e) => e.id.equals(item.id))).go();
          await _insertEvidenceItem(item);
        } else {
          await _insertEvidenceItem(item);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import evidence item ${item.id}: $e');
      }
    }
  }

  Future<void> _insertEvidenceItem(EvidenceItem item) async {
    await _db.into(_db.evidenceItems).insert(
      EvidenceItemsCompanion.insert(
        id: item.id,
        sessionId: item.sessionId,
        problemId: Value(item.problemId),
        evidenceType: item.evidenceType,
        statementText: item.statementText,
        strengthFlag: item.strengthFlag,
        context: Value(item.context),
        createdAtUtc: item.createdAtUtc,
      ),
    );
  }

  Future<void> _importReSetupTriggers(
    List<ReSetupTrigger> triggers,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'reSetupTriggers';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    for (final trigger in triggers) {
      try {
        final existing = await _reSetupTriggerRepo.getById(trigger.id);

        if (existing != null) {
          if (strategy == ConflictStrategy.skip) {
            skipped[type] = skipped[type]! + 1;
            continue;
          }

          if (strategy == ConflictStrategy.merge) {
            if (existing.updatedAtUtc.isAfter(trigger.updatedAtUtc)) {
              skipped[type] = skipped[type]! + 1;
              continue;
            }
          }

          await _updateReSetupTrigger(trigger);
        } else {
          await _insertReSetupTrigger(trigger);
        }
        imported[type] = imported[type]! + 1;
      } catch (e) {
        errorCounts[type] = errorCounts[type]! + 1;
        errors.add('Failed to import re-setup trigger ${trigger.id}: $e');
      }
    }
  }

  Future<void> _insertReSetupTrigger(ReSetupTrigger trigger) async {
    await _db.into(_db.reSetupTriggers).insert(
      ReSetupTriggersCompanion.insert(
        id: trigger.id,
        triggerType: trigger.triggerType,
        description: trigger.description,
        condition: trigger.condition,
        recommendedAction: trigger.recommendedAction,
        isMet: Value(trigger.isMet),
        metAtUtc: Value(trigger.metAtUtc),
        dueAtUtc: Value(trigger.dueAtUtc),
        createdAtUtc: trigger.createdAtUtc,
        updatedAtUtc: trigger.updatedAtUtc,
      ),
    );
  }

  Future<void> _updateReSetupTrigger(ReSetupTrigger trigger) async {
    await (_db.update(_db.reSetupTriggers)..where((t) => t.id.equals(trigger.id))).write(
      ReSetupTriggersCompanion(
        triggerType: Value(trigger.triggerType),
        description: Value(trigger.description),
        condition: Value(trigger.condition),
        recommendedAction: Value(trigger.recommendedAction),
        isMet: Value(trigger.isMet),
        metAtUtc: Value(trigger.metAtUtc),
        dueAtUtc: Value(trigger.dueAtUtc),
        updatedAtUtc: Value(trigger.updatedAtUtc),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> _importUserPreferences(
    UserPreference prefs,
    ConflictStrategy strategy,
    Map<String, int> imported,
    Map<String, int> skipped,
    Map<String, int> errorCounts,
    List<String> errors,
  ) async {
    const type = 'userPreferences';
    imported[type] = 0;
    skipped[type] = 0;
    errorCounts[type] = 0;

    try {
      // User preferences is a singleton, always merge/update
      final currentPrefs = await _userPreferencesRepo.get();

      if (strategy == ConflictStrategy.skip) {
        // Skip if preferences already exist
        if (currentPrefs.onboardingCompleted) {
          skipped[type] = skipped[type]! + 1;
          return;
        }
      }

      if (strategy == ConflictStrategy.merge) {
        // Keep newer preferences
        if (currentPrefs.updatedAtUtc.isAfter(prefs.updatedAtUtc)) {
          skipped[type] = skipped[type]! + 1;
          return;
        }
      }

      // Update preferences
      await (_db.update(_db.userPreferences)..where((p) => p.id.equals(currentPrefs.id))).write(
        UserPreferencesCompanion(
          abstractionModeQuick: Value(prefs.abstractionModeQuick),
          abstractionModeSetup: Value(prefs.abstractionModeSetup),
          abstractionModeQuarterly: Value(prefs.abstractionModeQuarterly),
          rememberAbstractionChoice: Value(prefs.rememberAbstractionChoice),
          analyticsEnabled: Value(prefs.analyticsEnabled),
          microReviewCollapsed: Value(prefs.microReviewCollapsed),
          onboardingCompleted: Value(prefs.onboardingCompleted),
          setupPromptDismissed: Value(prefs.setupPromptDismissed),
          setupPromptLastShownUtc: Value(prefs.setupPromptLastShownUtc),
          totalEntryCount: Value(prefs.totalEntryCount),
          updatedAtUtc: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending'),
        ),
      );

      imported[type] = imported[type]! + 1;
    } catch (e) {
      errorCounts[type] = errorCounts[type]! + 1;
      errors.add('Failed to import user preferences: $e');
    }
  }
}
