import 'package:drift/drift.dart';

/// Daily journal entries table.
///
/// Per PRD Section 3.1:
/// - transcriptRaw: Original transcription from voice or initial text
/// - transcriptEdited: User-edited version of transcript
/// - extractedSignals: JSON containing 7 signal types
/// - createdAtUTC: UTC timestamp of creation
/// - createdAtTimezone: Timezone identifier at creation time
/// - entryType: voice or text
///
/// Per PRD Section 4.1:
/// - Max 15 minutes per recording (~2500 words)
/// - Max 7500 words per entry including follow-ups
/// - Entries editable indefinitely (no time-based locking)
@DataClassName('DailyEntry')
class DailyEntries extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Raw transcript from transcription service or initial text input.
  TextColumn get transcriptRaw => text()();

  /// User-edited version of transcript.
  /// May be identical to raw if no edits made.
  TextColumn get transcriptEdited => text()();

  /// JSON-encoded extracted signals.
  /// Structure: {"wins": [...], "blockers": [...], ...}
  /// Contains arrays for each SignalType.
  TextColumn get extractedSignalsJson => text().withDefault(const Constant('{}'))();

  /// Entry type: 'voice' or 'text'.
  TextColumn get entryType => text()();

  /// Word count of the edited transcript.
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  /// Duration in seconds (for voice entries only, null for text).
  IntColumn get durationSeconds => integer().nullable()();

  /// UTC timestamp when entry was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// IANA timezone identifier at creation (e.g., 'America/New_York').
  TextColumn get createdAtTimezone => text()();

  /// UTC timestamp when entry was last modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Soft delete timestamp (null if not deleted).
  /// Per PRD Section 3C.3: Hard delete within 30 days.
  DateTimeColumn get deletedAtUtc => dateTime().nullable()();

  /// Sync status: 'pending', 'synced', 'conflict'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
