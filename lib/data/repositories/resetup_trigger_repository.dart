import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'base_repository.dart';

/// Repository for managing re-setup triggers.
///
/// Per PRD Section 3.3.7:
/// The system tracks conditions that should trigger a portfolio refresh:
/// - Role change (promotion, new job, new team) → Full re-setup
/// - Scope change (major project ends, new responsibility) → Full re-setup
/// - Direction shift (problem reclassified in 2+ quarterly reviews) → Update problem
/// - Time drift (20%+ shift in allocation vs setup) → Review portfolio health
/// - Annual (12 months since last setup) → Full re-setup (mandatory)
class ReSetupTriggerRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ReSetupTriggerRepository(this._db);

  /// Creates a new re-setup trigger.
  Future<String> create({
    required String triggerType,
    required String description,
    required String condition,
    required String recommendedAction,
    DateTime? dueAtUtc,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.reSetupTriggers).insert(
          ReSetupTriggersCompanion.insert(
            id: id,
            triggerType: triggerType,
            description: description,
            condition: condition,
            recommendedAction: recommendedAction,
            dueAtUtc: Value(dueAtUtc),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Creates the standard annual trigger.
  ///
  /// Per PRD: Annual re-setup is mandatory, 12 months from setup.
  Future<String> createAnnualTrigger(DateTime setupDate) async {
    final dueDate = setupDate.add(const Duration(days: 365));

    return create(
      triggerType: 'annual',
      description: 'Annual portfolio review',
      condition: '12 months since last setup',
      recommendedAction: 'full_resetup',
      dueAtUtc: dueDate,
    );
  }

  /// Gets a trigger by ID.
  Future<ReSetupTrigger?> getById(String id) async {
    final query = _db.select(_db.reSetupTriggers)
      ..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Gets all triggers.
  Future<List<ReSetupTrigger>> getAll() async {
    final query = _db.select(_db.reSetupTriggers)
      ..orderBy([(t) => OrderingTerm.asc(t.dueAtUtc)]);

    return query.get();
  }

  /// Gets all met triggers.
  Future<List<ReSetupTrigger>> getMet() async {
    final query = _db.select(_db.reSetupTriggers)
      ..where((t) => t.isMet.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.metAtUtc)]);

    return query.get();
  }

  /// Gets unmet triggers.
  Future<List<ReSetupTrigger>> getUnmet() async {
    final query = _db.select(_db.reSetupTriggers)
      ..where((t) => t.isMet.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.dueAtUtc)]);

    return query.get();
  }

  /// Gets triggers approaching their due date.
  ///
  /// Per PRD Section 4.5: Flag if annual trigger approaching (within 30 days).
  Future<List<ReSetupTrigger>> getApproaching({int withinDays = 30}) async {
    final now = DateTime.now().toUtc();
    final cutoff = now.add(Duration(days: withinDays));

    final query = _db.select(_db.reSetupTriggers)
      ..where(
        (t) =>
            t.isMet.equals(false) &
            t.dueAtUtc.isNotNull() &
            t.dueAtUtc.isSmallerOrEqualValue(cutoff) &
            t.dueAtUtc.isBiggerOrEqualValue(now),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.dueAtUtc)]);

    return query.get();
  }

  /// Gets triggers that are past due.
  Future<List<ReSetupTrigger>> getPastDue() async {
    final now = DateTime.now().toUtc();

    final query = _db.select(_db.reSetupTriggers)
      ..where(
        (t) => t.isMet.equals(false) & t.dueAtUtc.isNotNull() & t.dueAtUtc.isSmallerThanValue(now),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.dueAtUtc)]);

    return query.get();
  }

  /// Marks a trigger as met.
  Future<void> markMet(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.reSetupTriggers)..where((t) => t.id.equals(id))).write(
      ReSetupTriggersCompanion(
        isMet: const Value(true),
        metAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Resets a trigger (marks as unmet).
  Future<void> reset(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.reSetupTriggers)..where((t) => t.id.equals(id))).write(
      ReSetupTriggersCompanion(
        isMet: const Value(false),
        metAtUtc: const Value(null),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Deletes all triggers (for re-setup).
  Future<int> deleteAll() async {
    return _db.delete(_db.reSetupTriggers).go();
  }

  /// Gets triggers with pending sync status.
  Future<List<ReSetupTrigger>> getPendingSync() async {
    final query = _db.select(_db.reSetupTriggers)
      ..where((t) => t.syncStatus.equals('pending'));

    return query.get();
  }

  /// Updates sync status for a trigger.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.reSetupTriggers)..where((t) => t.id.equals(id))).write(
      ReSetupTriggersCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all triggers.
  Stream<List<ReSetupTrigger>> watchAll() {
    final query = _db.select(_db.reSetupTriggers)
      ..orderBy([(t) => OrderingTerm.asc(t.dueAtUtc)]);

    return query.watch();
  }

  /// Watches met triggers.
  Stream<List<ReSetupTrigger>> watchMet() {
    final query = _db.select(_db.reSetupTriggers)
      ..where((t) => t.isMet.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.metAtUtc)]);

    return query.watch();
  }
}
