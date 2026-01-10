import 'package:equatable/equatable.dart';

import '../data/data.dart';

/// Version of the export format.
const String exportFormatVersion = '1.0';

/// Export data container holding all exportable user data.
///
/// This is the main structure for JSON export/import operations.
/// Per PRD requirements, this includes all user-generated data
/// for data portability and backup purposes.
class ExportData extends Equatable {
  /// Format version for compatibility checking.
  final String version;

  /// When the export was created.
  final DateTime exportedAt;

  /// Daily journal entries.
  final List<DailyEntry> dailyEntries;

  /// Weekly briefs.
  final List<WeeklyBrief> weeklyBriefs;

  /// Career problems in portfolio.
  final List<Problem> problems;

  /// Portfolio version snapshots.
  final List<PortfolioVersion> portfolioVersions;

  /// Board member personas.
  final List<BoardMember> boardMembers;

  /// Governance session records.
  final List<GovernanceSession> governanceSessions;

  /// Bets (predictions).
  final List<Bet> bets;

  /// Evidence items (receipts).
  final List<EvidenceItem> evidenceItems;

  /// Re-setup triggers.
  final List<ReSetupTrigger> reSetupTriggers;

  /// User preferences (if present).
  final UserPreference? userPreferences;

  const ExportData({
    required this.version,
    required this.exportedAt,
    this.dailyEntries = const [],
    this.weeklyBriefs = const [],
    this.problems = const [],
    this.portfolioVersions = const [],
    this.boardMembers = const [],
    this.governanceSessions = const [],
    this.bets = const [],
    this.evidenceItems = const [],
    this.reSetupTriggers = const [],
    this.userPreferences,
  });

  /// Creates an empty export data structure.
  factory ExportData.empty() {
    return ExportData(
      version: exportFormatVersion,
      exportedAt: DateTime.now().toUtc(),
    );
  }

  /// Returns total item count across all data types.
  int get totalItemCount =>
      dailyEntries.length +
      weeklyBriefs.length +
      problems.length +
      portfolioVersions.length +
      boardMembers.length +
      governanceSessions.length +
      bets.length +
      evidenceItems.length +
      reSetupTriggers.length +
      (userPreferences != null ? 1 : 0);

  /// Returns a summary of the export data.
  ExportSummary get summary => ExportSummary(
        dailyEntriesCount: dailyEntries.length,
        weeklyBriefsCount: weeklyBriefs.length,
        problemsCount: problems.length,
        portfolioVersionsCount: portfolioVersions.length,
        boardMembersCount: boardMembers.length,
        governanceSessionsCount: governanceSessions.length,
        betsCount: bets.length,
        evidenceItemsCount: evidenceItems.length,
        reSetupTriggersCount: reSetupTriggers.length,
        hasUserPreferences: userPreferences != null,
      );

  @override
  List<Object?> get props => [
        version,
        exportedAt,
        dailyEntries,
        weeklyBriefs,
        problems,
        portfolioVersions,
        boardMembers,
        governanceSessions,
        bets,
        evidenceItems,
        reSetupTriggers,
        userPreferences,
      ];
}

/// Summary of export data counts for preview purposes.
class ExportSummary extends Equatable {
  final int dailyEntriesCount;
  final int weeklyBriefsCount;
  final int problemsCount;
  final int portfolioVersionsCount;
  final int boardMembersCount;
  final int governanceSessionsCount;
  final int betsCount;
  final int evidenceItemsCount;
  final int reSetupTriggersCount;
  final bool hasUserPreferences;

  const ExportSummary({
    this.dailyEntriesCount = 0,
    this.weeklyBriefsCount = 0,
    this.problemsCount = 0,
    this.portfolioVersionsCount = 0,
    this.boardMembersCount = 0,
    this.governanceSessionsCount = 0,
    this.betsCount = 0,
    this.evidenceItemsCount = 0,
    this.reSetupTriggersCount = 0,
    this.hasUserPreferences = false,
  });

  int get totalCount =>
      dailyEntriesCount +
      weeklyBriefsCount +
      problemsCount +
      portfolioVersionsCount +
      boardMembersCount +
      governanceSessionsCount +
      betsCount +
      evidenceItemsCount +
      reSetupTriggersCount +
      (hasUserPreferences ? 1 : 0);

  @override
  List<Object?> get props => [
        dailyEntriesCount,
        weeklyBriefsCount,
        problemsCount,
        portfolioVersionsCount,
        boardMembersCount,
        governanceSessionsCount,
        betsCount,
        evidenceItemsCount,
        reSetupTriggersCount,
        hasUserPreferences,
      ];
}

/// Validation result for import files.
class ImportValidationResult extends Equatable {
  /// Whether the import file is valid.
  final bool isValid;

  /// List of validation errors.
  final List<String> errors;

  /// List of validation warnings.
  final List<String> warnings;

  /// The parsed export data (if valid).
  final ExportData? data;

  const ImportValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.data,
  });

  /// Creates a successful validation result.
  factory ImportValidationResult.success(ExportData data, {List<String> warnings = const []}) {
    return ImportValidationResult(
      isValid: true,
      data: data,
      warnings: warnings,
    );
  }

  /// Creates a failed validation result.
  factory ImportValidationResult.failure(List<String> errors) {
    return ImportValidationResult(
      isValid: false,
      errors: errors,
    );
  }

  @override
  List<Object?> get props => [isValid, errors, warnings, data];
}

/// Strategy for handling conflicts during import.
enum ConflictStrategy {
  /// Overwrite existing records with imported data.
  overwrite,

  /// Skip records that already exist.
  skip,

  /// Merge records (keep newest version).
  merge,
}

/// Extension on ConflictStrategy for display purposes.
extension ConflictStrategyExtension on ConflictStrategy {
  String get displayName {
    switch (this) {
      case ConflictStrategy.overwrite:
        return 'Overwrite existing';
      case ConflictStrategy.skip:
        return 'Skip duplicates';
      case ConflictStrategy.merge:
        return 'Keep newest';
    }
  }

  String get description {
    switch (this) {
      case ConflictStrategy.overwrite:
        return 'Replace existing records with imported data';
      case ConflictStrategy.skip:
        return 'Keep existing records, ignore duplicates in import';
      case ConflictStrategy.merge:
        return 'Compare timestamps and keep the most recent version';
    }
  }
}

/// Result of an import operation.
class ImportResult extends Equatable {
  /// Whether the import was successful.
  final bool success;

  /// Number of records imported per type.
  final Map<String, int> importedCounts;

  /// Number of records skipped per type.
  final Map<String, int> skippedCounts;

  /// Number of records that caused errors per type.
  final Map<String, int> errorCounts;

  /// Error messages if any.
  final List<String> errors;

  const ImportResult({
    required this.success,
    this.importedCounts = const {},
    this.skippedCounts = const {},
    this.errorCounts = const {},
    this.errors = const [],
  });

  /// Creates a successful import result.
  factory ImportResult.success({
    Map<String, int> importedCounts = const {},
    Map<String, int> skippedCounts = const {},
  }) {
    return ImportResult(
      success: true,
      importedCounts: importedCounts,
      skippedCounts: skippedCounts,
    );
  }

  /// Creates a failed import result.
  factory ImportResult.failure(List<String> errors) {
    return ImportResult(
      success: false,
      errors: errors,
    );
  }

  /// Total number of records imported.
  int get totalImported => importedCounts.values.fold(0, (a, b) => a + b);

  /// Total number of records skipped.
  int get totalSkipped => skippedCounts.values.fold(0, (a, b) => a + b);

  /// Total number of errors.
  int get totalErrors => errorCounts.values.fold(0, (a, b) => a + b);

  @override
  List<Object?> get props => [success, importedCounts, skippedCounts, errorCounts, errors];
}

/// Represents a history item for display purposes.
///
/// Combines different types of entries (daily entries, weekly briefs,
/// governance sessions) into a unified display format.
class HistoryItem extends Equatable {
  /// Unique identifier.
  final String id;

  /// Type of the history item.
  final HistoryItemType type;

  /// Display title or preview text.
  final String title;

  /// Preview text (first 50 chars for entries).
  final String? preview;

  /// Date for sorting and display.
  final DateTime date;

  /// Original data reference for navigation.
  final dynamic data;

  const HistoryItem({
    required this.id,
    required this.type,
    required this.title,
    this.preview,
    required this.date,
    this.data,
  });

  /// Creates a history item from a daily entry.
  factory HistoryItem.fromDailyEntry(DailyEntry entry) {
    final text = entry.transcriptEdited ?? 'Entry ${entry.id.substring(0, 8)}';
    final preview = text.length > 50 ? text.substring(0, 50) : text;

    return HistoryItem(
      id: entry.id,
      type: HistoryItemType.dailyEntry,
      title: _formatDateTitle(entry.createdAtUtc),
      preview: preview,
      date: entry.createdAtUtc,
      data: entry,
    );
  }

  /// Creates a history item from a weekly brief.
  factory HistoryItem.fromWeeklyBrief(WeeklyBrief brief) {
    final preview = brief.briefMarkdown.length > 50
        ? brief.briefMarkdown.substring(0, 50)
        : brief.briefMarkdown;

    return HistoryItem(
      id: brief.id,
      type: HistoryItemType.weeklyBrief,
      title: 'Weekly Brief - ${_formatWeekRange(brief.weekStartUtc, brief.weekEndUtc)}',
      preview: preview,
      date: brief.generatedAtUtc,
      data: brief,
    );
  }

  /// Creates a history item from a governance session.
  factory HistoryItem.fromGovernanceSession(GovernanceSession session) {
    final typeDisplay = _getSessionTypeDisplay(session.sessionType);
    final preview = session.outputMarkdown != null && session.outputMarkdown!.length > 50
        ? session.outputMarkdown!.substring(0, 50)
        : session.outputMarkdown;

    return HistoryItem(
      id: session.id,
      type: HistoryItemType.governanceSession,
      title: '$typeDisplay - ${_formatDateTitle(session.startedAtUtc)}',
      preview: preview,
      date: session.completedAtUtc ?? session.startedAtUtc,
      data: session,
    );
  }

  static String _formatDateTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  static String _formatWeekRange(DateTime start, DateTime end) {
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  static String _getSessionTypeDisplay(String sessionType) {
    switch (sessionType) {
      case 'quick':
        return 'Quick Audit';
      case 'setup':
        return 'Setup';
      case 'quarterly':
        return 'Quarterly Review';
      default:
        return 'Governance';
    }
  }

  @override
  List<Object?> get props => [id, type, title, preview, date, data];
}

/// Type of history item for icon and routing purposes.
enum HistoryItemType {
  /// Daily journal entry.
  dailyEntry,

  /// Weekly brief document.
  weeklyBrief,

  /// Governance session/report.
  governanceSession,
}

/// Extension on HistoryItemType for icon selection.
extension HistoryItemTypeExtension on HistoryItemType {
  /// Returns the icon name/type for this history item type.
  String get iconName {
    switch (this) {
      case HistoryItemType.dailyEntry:
        return 'calendar_today';
      case HistoryItemType.weeklyBrief:
        return 'description';
      case HistoryItemType.governanceSession:
        return 'gavel';
    }
  }

  /// Returns a human-readable label.
  String get label {
    switch (this) {
      case HistoryItemType.dailyEntry:
        return 'Entry';
      case HistoryItemType.weeklyBrief:
        return 'Brief';
      case HistoryItemType.governanceSession:
        return 'Report';
    }
  }
}
