import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../enums/board_role_type.dart';
import 'base_repository.dart';

/// Repository for managing board members.
///
/// Per PRD Section 3.3:
/// - 5 core roles (always active) + 2 growth roles (if appreciating problems exist)
/// - Each role has a persona profile and is anchored to a specific problem
/// - Users can edit persona names and profiles in Settings
/// - Original generated personas stored for reset capability
class BoardMemberRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  BoardMemberRepository(this._db);

  /// Creates a new board member with full persona.
  Future<String> create({
    required BoardRoleType roleType,
    required String personaName,
    required String personaBackground,
    required String personaCommunicationStyle,
    String? personaSignaturePhrase,
    String? anchoredProblemId,
    String? anchoredDemand,
    bool isGrowthRole = false,
    bool isActive = true,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.into(_db.boardMembers).insert(
          BoardMembersCompanion.insert(
            id: id,
            roleType: roleType.name,
            isGrowthRole: Value(isGrowthRole),
            isActive: Value(isActive),
            anchoredProblemId: Value(anchoredProblemId),
            anchoredDemand: Value(anchoredDemand),
            personaName: personaName,
            personaBackground: personaBackground,
            personaCommunicationStyle: personaCommunicationStyle,
            personaSignaturePhrase: Value(personaSignaturePhrase),
            // Store original persona for reset capability
            originalPersonaName: personaName,
            originalPersonaBackground: personaBackground,
            originalPersonaCommunicationStyle: personaCommunicationStyle,
            originalPersonaSignaturePhrase: Value(personaSignaturePhrase),
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );

    return id;
  }

  /// Retrieves a board member by ID.
  Future<BoardMember?> getById(String id) async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.id.equals(id) & m.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves a board member by role type.
  Future<BoardMember?> getByRoleType(BoardRoleType roleType) async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.roleType.equals(roleType.name) & m.deletedAtUtc.isNull());
    return query.getSingleOrNull();
  }

  /// Retrieves all board members.
  Future<List<BoardMember>> getAll() async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull());

    return query.get();
  }

  /// Gets all active board members.
  ///
  /// Per PRD: Returns 5-7 members depending on growth role activation.
  Future<List<BoardMember>> getActive() async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull() & m.isActive.equals(true));

    return query.get();
  }

  /// Gets core roles only (the 5 always-active roles).
  Future<List<BoardMember>> getCoreRoles() async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull() & m.isGrowthRole.equals(false));

    return query.get();
  }

  /// Gets growth roles only (Portfolio Defender and Opportunity Scout).
  Future<List<BoardMember>> getGrowthRoles() async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull() & m.isGrowthRole.equals(true));

    return query.get();
  }

  /// Gets board members anchored to a specific problem.
  Future<List<BoardMember>> getByAnchoredProblem(String problemId) async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull() & m.anchoredProblemId.equals(problemId));

    return query.get();
  }

  /// Activates or deactivates growth roles based on portfolio state.
  ///
  /// Per PRD Section 3.3.3: Growth roles activate when portfolio
  /// contains at least one appreciating problem.
  Future<void> setGrowthRolesActive(bool active) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.boardMembers)..where((m) => m.isGrowthRole.equals(true))).write(
      BoardMembersCompanion(
        isActive: Value(active),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates the anchoring for a board member.
  Future<void> updateAnchoring(
    String id, {
    required String problemId,
    required String demand,
  }) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(id))).write(
      BoardMembersCompanion(
        anchoredProblemId: Value(problemId),
        anchoredDemand: Value(demand),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Updates persona profile (user editable fields).
  ///
  /// Per PRD Section 4.4: Users can edit persona names and profiles.
  Future<void> updatePersona(
    String id, {
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(id))).write(
      BoardMembersCompanion(
        personaName: name != null ? Value(name) : const Value.absent(),
        personaBackground: background != null ? Value(background) : const Value.absent(),
        personaCommunicationStyle: communicationStyle != null ? Value(communicationStyle) : const Value.absent(),
        personaSignaturePhrase: signaturePhrase != null ? Value(signaturePhrase) : const Value.absent(),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Resets a single persona to its original AI-generated values.
  Future<void> resetPersona(String id) async {
    final member = await getById(id);
    if (member == null) return;

    final now = DateTime.now().toUtc();

    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(id))).write(
      BoardMembersCompanion(
        personaName: Value(member.originalPersonaName),
        personaBackground: Value(member.originalPersonaBackground),
        personaCommunicationStyle: Value(member.originalPersonaCommunicationStyle),
        personaSignaturePhrase: Value(member.originalPersonaSignaturePhrase),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Resets all personas to their original AI-generated values.
  Future<void> resetAllPersonas() async {
    final members = await getAll();
    for (final member in members) {
      await resetPersona(member.id);
    }
  }

  /// Soft deletes a board member.
  Future<void> softDelete(String id) async {
    final now = DateTime.now().toUtc();

    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(id))).write(
      BoardMembersCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Deletes all board members (for re-setup).
  Future<void> deleteAll() async {
    final now = DateTime.now().toUtc();

    await _db.update(_db.boardMembers).write(
      BoardMembersCompanion(
        deletedAtUtc: Value(now),
        updatedAtUtc: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Gets board members with pending sync status.
  Future<List<BoardMember>> getPendingSync() async {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.syncStatus.equals('pending'))
      ..orderBy([(m) => OrderingTerm.asc(m.updatedAtUtc)]);

    return query.get();
  }

  /// Updates sync status for a board member.
  Future<void> updateSyncStatus(
    String id,
    SyncStatus status, {
    int? serverVersion,
  }) async {
    await (_db.update(_db.boardMembers)..where((m) => m.id.equals(id))).write(
      BoardMembersCompanion(
        syncStatus: Value(status.value),
        serverVersion: serverVersion != null ? Value(serverVersion) : const Value.absent(),
      ),
    );
  }

  /// Watches all board members (for reactive UI updates).
  Stream<List<BoardMember>> watchAll() {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull());

    return query.watch();
  }

  /// Watches active board members.
  Stream<List<BoardMember>> watchActive() {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.deletedAtUtc.isNull() & m.isActive.equals(true));

    return query.watch();
  }

  /// Watches a specific board member by ID.
  Stream<BoardMember?> watchById(String id) {
    final query = _db.select(_db.boardMembers)
      ..where((m) => m.id.equals(id) & m.deletedAtUtc.isNull());

    return query.watchSingleOrNull();
  }
}
