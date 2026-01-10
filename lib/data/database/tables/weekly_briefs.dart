import 'package:drift/drift.dart';

/// Weekly brief table.
///
/// Per PRD Section 3.1:
/// - weekRange: Mon 00:00 → Sun 23:59 based on entry's original local time
/// - briefMarkdown: Executive summary (600-800 words)
/// - boardMicroReviewMarkdown: One sentence from each active board role
/// - generatedAt: When the brief was generated
/// - regenCount: Number of regenerations (max 5 per brief)
///
/// Per PRD Section 4.2:
/// - Auto-generates Sunday 8pm local time
/// - Zero-entry weeks get reflection brief (~100 words)
/// - Regeneration options: shorter, more actionable, more strategic
@DataClassName('WeeklyBrief')
class WeeklyBriefs extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Start of week (Monday 00:00:00 UTC).
  DateTimeColumn get weekStartUtc => dateTime()();

  /// End of week (Sunday 23:59:59 UTC).
  DateTimeColumn get weekEndUtc => dateTime()();

  /// Timezone used for week boundary calculation.
  TextColumn get weekTimezone => text()();

  /// Executive brief markdown content.
  /// Target ~600 words, max 800 words.
  TextColumn get briefMarkdown => text()();

  /// Board micro-review markdown.
  /// One sentence from each active board role (5-7 sentences).
  /// ~100 words total.
  TextColumn get boardMicroReviewMarkdown => text().nullable()();

  /// Number of entries included in this brief.
  IntColumn get entryCount => integer().withDefault(const Constant(0))();

  /// Number of times this brief has been regenerated.
  /// Per PRD: Max 5 regenerations per brief.
  IntColumn get regenCount => integer().withDefault(const Constant(0))();

  /// Regeneration options used (JSON array).
  /// Options: 'shorter', 'actionable', 'strategic'.
  TextColumn get regenOptionsJson => text().withDefault(const Constant('[]'))();

  /// Whether user has collapsed the board micro-review.
  /// Remembered preference per PRD Section 4.2.
  BoolColumn get microReviewCollapsed => boolean().withDefault(const Constant(false))();

  /// UTC timestamp when brief was generated.
  DateTimeColumn get generatedAtUtc => dateTime()();

  /// UTC timestamp when brief was last modified (user edits).
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Soft delete timestamp.
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
