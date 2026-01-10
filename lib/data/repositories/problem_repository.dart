import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/problem_direction.dart';
import 'base_repository.dart';

/// Repository for managing career problems in the portfolio.
///
/// Per PRD Section 4.4 (Setup):
/// - Portfolio must have 3-5 problems
/// - Time allocations must sum to 95-105%
/// - Each problem has direction classification and evidence
class ProblemRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Minimum problems in portfolio.
  static const minProblems = 3;

  /// Maximum problems in portfolio.
  static const maxProblems = 5;

  /// Minimum valid time allocation sum.
  static const minAllocationSum = 95;

  /// Maximum valid time allocation sum.
  static const maxAllocationSum = 105;

  ProblemRepository(this._db);

  /// Creates a new problem.
  Future<String> create({
    required String name,
    required String whatBreaks,
    required String scarcitySignalsJson,
    required ProblemDirection direction,
    required String directionRationale,
    required String evidenceAiCheaper,
    required String evidenceErrorCost,
    required String evidenceTrustRequired,
    required int timeAllocationPercent,
    int? displayOrder,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Get next display order if not specified
    final order = displayOrder ?? await _getNextDisplayOrder();

    await _db.into(_db.problems).insert(
          ProblemsCompanion.insert(
            id: id,
            name: name,
            whatBreaks: whatBreaks,
            scarcitySignalsJson: scarcitySignalsJson,
            direction: direction.name,
            directionRationale: directionRationale,
            evidenceAiCheaper: evidenceAiCheaper,
            evidenceErrorCost: evidenceErrorCost,
            evidenceTrustRequired: evidenceTrustRequired,
            timeAllocationPercent: timeAllocationPercent,
            displayOrder: Value(order),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Gets the next display order for a new problem.
  Future<int> _getNextDisplayOrder() async {
    final problems = await getAll();
    if (problems.isEmpty) return 0;
    return problems.map((p) => p.displayOrder).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Retrieves a problem by ID.
  Future<Problem?> getById(String id) async {
    final query = _db.select(_db.problems)
      ..where((p) => p.id.equals(id) & p.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves all active problems, ordered by display order.
  Future<List<Problem>> getAll() async {
    final query = _db.select(_db.problems)
      ..where((p) => p.deletedAtUtc.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.displayOrder)]);

    return query.get();
  }

  /// Gets the count of active problems.
  Future<int> getCount() async {
    final problems = await getAll();
    return problems.length;
  }

  /// Gets problems by direction classification.
  Future<List<Problem>> getByDirection(ProblemDirection direction) async {
    final query = _db.select(_db.problems)
      ..where((p) => p.deletedAtUtc.isNull() & p.direction.equals(direction.name))
      ..orderBy([(p) => OrderingTerm.asc(p.displayOrder)]);

    return query.get();
  }

  /// Gets appreciating problems (for growth role activation).
  ///
  /// Per PRD Section 3.3.3: Growth roles activate when portfolio
  /// contains at least one appreciating problem.
  Future<List<Problem>> getAppreciating() async {
    return getByDirection(ProblemDirection.appreciating);
  }

  /// Checks if there are any appreciating problems.
  Future<bool> hasAppreciatingProblems() async {
    final appreciating = await getAppreciating();
    return appreciating.isNotEmpty;
  }

  /// Gets the highest-appreciating problem (for growth role anchoring).
  ///
  /// Returns the appreciating problem with the highest time allocation.
  Future<Problem?> getHighestAppreciating() async {
    final appreciating = await getAppreciating();
    if (appreciating.isEmpty) return null;

    return appreciating.reduce(
      (a, b) => a.timeAllocationPercent > b.timeAllocationPercent ? a : b,
    );
  }

  /// Calculates the total time allocation percentage.
  Future<int> getTotalAllocation() async {
    final problems = await getAll();
    return problems.fold(0, (sum, p) => sum + p.timeAllocationPercent);
  }

  /// Validates time allocation is within acceptable range.
  ///
  /// Returns null if valid, or an error message if invalid.
  Future<String?> validateAllocation() async {
    final total = await getTotalAllocation();

    if (total < 90) {
      return 'Time allocation is too low ($total%). Must be at least 90%.';
    }
    if (total > 110) {
      return 'Time allocation is too high ($total%). Must be at most 110%.';
    }
    if (total < minAllocationSum || total > maxAllocationSum) {
      return 'Time allocation is $total%. Ideal range is $minAllocationSum-$maxAllocationSum%.';
    }

    return null;
  }

  /// Updates problem fields.
  Future<void> update(
    String id, {
    String? name,
    String? whatBreaks,
    String? directionRationale,
    int? timeAllocationPercent,
    int? displayOrder,
  }) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.problems)..where((p) => p.id.equals(id))).write(
      ProblemsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        whatBreaks: whatBreaks != null ? Value(whatBreaks) : const Value.absent(),
        directionRationale: directionRationale != null ? Value(directionRationale) : const Value.absent(),
        timeAllocationPercent: timeAllocationPercent != null ? Value(timeAllocationPercent) : const Value.absent(),
        displayOrder: displayOrder != null ? Value(displayOrder) : const Value.absent(),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates the direction classification.
  ///
  /// Per PRD: Direction changes require re-setup (affects governance logic).
  Future<void> updateDirection(
    String id, {
    required ProblemDirection direction,
    required String rationale,
    required String evidenceAiCheaper,
    required String evidenceErrorCost,
    required String evidenceTrustRequired,
  }) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.problems)..where((p) => p.id.equals(id))).write(
      ProblemsCompanion(
        direction: Value(direction.name),
        directionRationale: Value(rationale),
        evidenceAiCheaper: Value(evidenceAiCheaper),
        evidenceErrorCost: Value(evidenceErrorCost),
        evidenceTrustRequired: Value(evidenceTrustRequired),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Soft deletes a problem.
  ///
  /// Per PRD: Minimum 3 problems enforced—cannot delete below 3.
  /// Returns false if deletion would go below minimum.
  Future<bool> softDelete(String id) async {
    final count = await getCount();
    if (count <= minProblems) {
      return false;
    }

    final now = DateTime.now().toUtc();

    await (_db.update(_db.problems)..where((p) => p.id.equals(id))).write(
      ProblemsCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    return true;
  }

  /// Reorders problems by updating their display order.
  Future<void> reorder(List<String> orderedIds) async {
    final now = DateTime.now().toUtc();

    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.problems)..where((p) => p.id.equals(orderedIds[i]))).write(
        ProblemsCompanion(
          displayOrder: Value(i),
          updatedAtUtc: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
    }
  }

  /// Gets problems with pending sync status.
  Future<List<Problem>> getPendingSync() async {
    final query = _db.select(_db.problems)
      ..where((p) => p.syncStatus.equals('pending'))
      ..orderBy([(p) => OrderingTerm.asc(p.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a problem.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.problems)..where((p) => p.id.equals(id))).write(
      ProblemsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all problems (for reactive UI updates).
  Stream<List<Problem>> watchAll() {
    final query = _db.select(_db.problems)
      ..where((p) => p.deletedAtUtc.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.displayOrder)]);

    return query.watch();
  }

  /// Watches a specific problem by ID.
  Stream<Problem?> watchById(String id) {
    final query = _db.select(_db.problems)
      ..where((p) => p.id.equals(id) & p.deletedAtUtc.isNull());

    return query.watchSingleOrNull();
  }
}
