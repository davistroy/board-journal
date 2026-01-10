import 'package:drift/drift.dart';

/// Bets table for prediction tracking.
///
/// Per PRD Section 3.1 and 4.6:
/// - prediction: The 90-day prediction statement
/// - wrongIf: Falsifiable criteria for being wrong
/// - dueDate: createdAt + 90 days
/// - status: OPEN, CORRECT, WRONG, EXPIRED
///
/// Per PRD Section 4.6 (Bet Tracking):
/// - No "partially correct" - forces clear accountability
/// - Auto-transition to EXPIRED at midnight on due date
/// - Retroactive evaluation encouraged during quarterly review
@DataClassName('Bet')
class Bets extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// The prediction statement.
  TextColumn get prediction => text()();

  /// Falsifiable criteria - what would prove this prediction wrong.
  TextColumn get wrongIf => text()();

  /// Bet status: 'open', 'correct', 'wrong', 'expired'.
  /// Maps to BetStatus enum.
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// ID of governance session that created this bet.
  TextColumn get sourceSessionId => text().nullable()();

  /// ID of governance session that evaluated this bet (if evaluated).
  TextColumn get evaluationSessionId => text().nullable()();

  /// User's evaluation notes when marking correct/wrong.
  TextColumn get evaluationNotes => text().nullable()();

  /// UTC timestamp when bet was created.
  DateTimeColumn get createdAtUtc => dateTime()();

  /// UTC timestamp when bet is due (90 days after creation).
  DateTimeColumn get dueAtUtc => dateTime()();

  /// UTC timestamp when bet was evaluated (null if not evaluated).
  DateTimeColumn get evaluatedAtUtc => dateTime().nullable()();

  /// UTC timestamp when last modified.
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
