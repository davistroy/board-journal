import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/evidence_type.dart';
import 'base_repository.dart';

/// Repository for managing evidence items ("receipts").
///
/// Per PRD Section 3.2:
/// "Receipts" in MVP = Evidence statements (not files)
/// - type: Decision, Artifact, Calendar, Proxy, None
/// - strengthFlag: Strong, Medium, Weak, None
///
/// Evidence is collected during governance sessions when
/// users claim progress on commitments.
class EvidenceItemRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  EvidenceItemRepository(this._db);

  /// Creates a new evidence item.
  Future<String> create({
    required String sessionId,
    required EvidenceType evidenceType,
    required String statementText,
    required String strengthFlag,
    String? problemId,
    String? context,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.evidenceItems).insert(
          EvidenceItemsCompanion.insert(
            id: id,
            sessionId: sessionId,
            problemId: Value(problemId),
            evidenceType: evidenceType.name,
            statementText: statementText,
            strengthFlag: strengthFlag,
            context: Value(context),
            createdAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves an evidence item by ID.
  Future<EvidenceItem?> getById(String id) async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Gets all evidence items for a session.
  Future<List<EvidenceItem>> getBySession(String sessionId) async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.sessionId.equals(sessionId))
      ..orderBy([(e) => OrderingTerm.asc(e.createdAtUtc)]);

    return query.get();
  }

  /// Gets all evidence items for a problem.
  Future<List<EvidenceItem>> getByProblem(String problemId) async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.problemId.equals(problemId))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.get();
  }

  /// Gets evidence items by type.
  Future<List<EvidenceItem>> getByType(EvidenceType type) async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.evidenceType.equals(type.name))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.get();
  }

  /// Gets evidence items by strength.
  Future<List<EvidenceItem>> getByStrength(String strength) async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.strengthFlag.equals(strength))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.get();
  }

  /// Gets weak or no-evidence items (for accountability tracking).
  ///
  /// Per PRD: Calendar-only = weak, No receipt = none (explicitly recorded).
  Future<List<EvidenceItem>> getWeakOrNone() async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.strengthFlag.equals('weak') | e.strengthFlag.equals('none'))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.get();
  }

  /// Gets evidence summary for a session.
  Future<Map<String, int>> getSessionSummary(String sessionId) async {
    final items = await getBySession(sessionId);

    final summary = <String, int>{
      'total': items.length,
      'strong': 0,
      'medium': 0,
      'weak': 0,
      'none': 0,
    };

    for (final item in items) {
      final strength = item.strengthFlag;
      if (summary.containsKey(strength)) {
        summary[strength] = summary[strength]! + 1;
      }
    }

    return summary;
  }

  /// Deletes all evidence items for a session.
  Future<int> deleteBySession(String sessionId) async {
    return (_db.delete(_db.evidenceItems)..where((e) => e.sessionId.equals(sessionId))).go();
  }

  /// Gets evidence items with pending sync status.
  Future<List<EvidenceItem>> getPendingSync() async {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.syncStatus.equals('pending'))
      ..orderBy([(e) => OrderingTerm.asc(e.createdAtUtc)]);

    return query.get();
  }

  /// Updates sync status for an evidence item.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.evidenceItems)..where((e) => e.id.equals(id))).write(
      EvidenceItemsCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all evidence items for a session.
  Stream<List<EvidenceItem>> watchBySession(String sessionId) {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.sessionId.equals(sessionId))
      ..orderBy([(e) => OrderingTerm.asc(e.createdAtUtc)]);

    return query.watch();
  }

  /// Watches all evidence items for a problem.
  Stream<List<EvidenceItem>> watchByProblem(String problemId) {
    final query = _db.select(_db.evidenceItems)
      ..where((e) => e.problemId.equals(problemId))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAtUtc)]);

    return query.watch();
  }
}
