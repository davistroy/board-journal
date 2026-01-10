import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'base_repository.dart';

/// Repository for managing portfolio health metrics.
///
/// Per PRD Section 3.1 and 3.3.6:
/// - appreciatingPct: Sum of time allocation for appreciating problems
/// - depreciatingPct: Sum of time allocation for depreciating problems
/// - stablePct: Sum of time allocation for stable/uncertain problems
/// - riskStatement: One sentence - where most exposed
/// - opportunityStatement: One sentence - where under-investing in appreciation
///
/// This is a singleton table (one active record at a time).
class PortfolioHealthRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PortfolioHealthRepository(this._db);

  /// Creates or updates the portfolio health record.
  ///
  /// Since this is effectively a singleton, this will update if exists
  /// or create if not.
  Future<String> upsert({
    required int appreciatingPercent,
    required int depreciatingPercent,
    required int stablePercent,
    String? riskStatement,
    String? opportunityStatement,
    required int portfolioVersion,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await getCurrent();

    if (existing != null) {
      await (_db.update(_db.portfolioHealths)..where((h) => h.id.equals(existing.id))).write(
        PortfolioHealthsCompanion(
          appreciatingPercent: Value(appreciatingPercent),
          depreciatingPercent: Value(depreciatingPercent),
          stablePercent: Value(stablePercent),
          riskStatement: riskStatement != null ? Value(riskStatement) : const Value.absent(),
          opportunityStatement: opportunityStatement != null ? Value(opportunityStatement) : const Value.absent(),
          portfolioVersion: Value(portfolioVersion),
          calculatedAtUtc: Value(now),
          updatedAtUtc: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      return existing.id;
    }

    final id = _uuid.v4();
    await _db.into(_db.portfolioHealths).insert(
          PortfolioHealthsCompanion.insert(
            id: id,
            appreciatingPercent: Value(appreciatingPercent),
            depreciatingPercent: Value(depreciatingPercent),
            stablePercent: Value(stablePercent),
            riskStatement: Value(riskStatement),
            opportunityStatement: Value(opportunityStatement),
            portfolioVersion: Value(portfolioVersion),
            calculatedAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Gets the current portfolio health.
  Future<PortfolioHealth?> getCurrent() async {
    final query = _db.select(_db.portfolioHealths)
      ..orderBy([(h) => OrderingTerm.desc(h.calculatedAtUtc)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Gets a health record by ID.
  Future<PortfolioHealth?> getById(String id) async {
    final query = _db.select(_db.portfolioHealths)
      ..where((h) => h.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Checks if portfolio health indicates growth role activation needed.
  ///
  /// Per PRD: Growth roles activate when appreciating problems exist.
  Future<bool> hasAppreciating() async {
    final health = await getCurrent();
    return health != null && health.appreciatingPercent > 0;
  }

  /// Gets the portfolio health trend compared to previous version.
  ///
  /// Returns: 'improving', 'declining', 'stable', or null if no history.
  Future<String?> getTrend() async {
    final all = await (_db.select(_db.portfolioHealths)
          ..orderBy([(h) => OrderingTerm.desc(h.portfolioVersion)])
          ..limit(2))
        .get();

    if (all.length < 2) return null;

    final current = all[0];
    final previous = all[1];

    final currentHealthy = current.appreciatingPercent;
    final previousHealthy = previous.appreciatingPercent;

    if (currentHealthy > previousHealthy + 5) return 'improving';
    if (currentHealthy < previousHealthy - 5) return 'declining';
    return 'stable';
  }

  /// Checks if depreciating percentage has increased significantly.
  ///
  /// Per PRD Section 4.5: Flag if depreciating percentage increased by >10%.
  Future<bool> hasSignificantDepreciatingIncrease() async {
    final all = await (_db.select(_db.portfolioHealths)
          ..orderBy([(h) => OrderingTerm.desc(h.portfolioVersion)])
          ..limit(2))
        .get();

    if (all.length < 2) return false;

    final current = all[0];
    final previous = all[1];

    return current.depreciatingPercent > previous.depreciatingPercent + 10;
  }

  /// Gets portfolio health with pending sync status.
  Future<List<PortfolioHealth>> getPendingSync() async {
    final query = _db.select(_db.portfolioHealths)
      ..where((h) => h.syncStatus.equals('pending'));

    return query.get();
  }

  /// Updates sync status for portfolio health.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.portfolioHealths)..where((h) => h.id.equals(id))).write(
      PortfolioHealthsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches the current portfolio health.
  Stream<PortfolioHealth?> watchCurrent() {
    final query = _db.select(_db.portfolioHealths)
      ..orderBy([(h) => OrderingTerm.desc(h.calculatedAtUtc)])
      ..limit(1);

    return query.watchSingleOrNull();
  }
}
