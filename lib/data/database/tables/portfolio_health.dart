import 'package:drift/drift.dart';

/// Portfolio health metrics table.
///
/// Per PRD Section 3.1 and 3.3.6:
/// - appreciatingPct: Sum of time allocation for appreciating problems
/// - depreciatingPct: Sum of time allocation for depreciating problems
/// - stablePct: Sum of time allocation for stable/uncertain problems
/// - riskStatement: One sentence - where most exposed
/// - opportunityStatement: One sentence - where under-investing in appreciation
///
/// This is a singleton table (one row per user in local DB).
@DataClassName('PortfolioHealth')
class PortfolioHealths extends Table {
  /// Unique identifier (UUID).
  TextColumn get id => text()();

  /// Percentage of time in appreciating problems.
  IntColumn get appreciatingPercent => integer().withDefault(const Constant(0))();

  /// Percentage of time in depreciating problems.
  IntColumn get depreciatingPercent => integer().withDefault(const Constant(0))();

  /// Percentage of time in stable/uncertain problems.
  IntColumn get stablePercent => integer().withDefault(const Constant(0))();

  /// One sentence describing where user is most exposed.
  TextColumn get riskStatement => text().nullable()();

  /// One sentence describing where user is under-investing in appreciation.
  TextColumn get opportunityStatement => text().nullable()();

  /// Current portfolio version number.
  IntColumn get portfolioVersion => integer().withDefault(const Constant(1))();

  /// UTC timestamp of last calculation.
  DateTimeColumn get calculatedAtUtc => dateTime()();

  /// UTC timestamp when last modified.
  DateTimeColumn get updatedAtUtc => dateTime()();

  /// Sync status.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Server-side version for conflict detection.
  IntColumn get serverVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
