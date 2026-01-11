import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late BoardMemberRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BoardMemberRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> createMember({
    BoardRoleType roleType = BoardRoleType.accountability,
    String name = 'Test Member',
    bool isGrowthRole = false,
    bool isActive = true,
    String? anchoredProblemId,
    String? anchoredDemand,
  }) async {
    return repository.create(
      roleType: roleType,
      personaName: name,
      personaBackground: 'Test background',
      personaCommunicationStyle: 'Test style',
      personaSignaturePhrase: 'Test phrase',
      anchoredProblemId: anchoredProblemId,
      anchoredDemand: anchoredDemand,
      isGrowthRole: isGrowthRole,
      isActive: isActive,
    );
  }

  group('BoardMemberRepository', () {
    group('create', () {
      test('creates a board member with persona', () async {
        final id = await repository.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Maya Chen',
          personaBackground: 'Former operations executive',
          personaCommunicationStyle: 'Warm but relentless',
          personaSignaturePhrase: 'Show me the artifact',
          anchoredProblemId: 'problem-123',
          anchoredDemand: 'Show me the calendar',
        );

        final member = await repository.getById(id);
        expect(member, isNotNull);
        expect(member!.roleType, 'accountability');
        expect(member.personaName, 'Maya Chen');
        expect(member.personaBackground, 'Former operations executive');
        expect(member.anchoredProblemId, 'problem-123');
        expect(member.anchoredDemand, 'Show me the calendar');
        expect(member.isGrowthRole, isFalse);
        expect(member.isActive, isTrue);
      });

      test('stores original persona for reset capability', () async {
        final id = await repository.create(
          roleType: BoardRoleType.marketReality,
          personaName: 'Original Name',
          personaBackground: 'Original Background',
          personaCommunicationStyle: 'Original Style',
        );

        final member = await repository.getById(id);
        expect(member!.originalPersonaName, 'Original Name');
        expect(member.originalPersonaBackground, 'Original Background');
        expect(member.originalPersonaCommunicationStyle, 'Original Style');
      });

      test('creates growth role correctly', () async {
        final id = await createMember(
          roleType: BoardRoleType.portfolioDefender,
          isGrowthRole: true,
        );

        final member = await repository.getById(id);
        expect(member!.isGrowthRole, isTrue);
      });
    });

    group('getByRoleType', () {
      test('returns member by role type', () async {
        await createMember(roleType: BoardRoleType.accountability, name: 'Maya');
        await createMember(roleType: BoardRoleType.marketReality, name: 'Alex');

        final member = await repository.getByRoleType(BoardRoleType.accountability);
        expect(member, isNotNull);
        expect(member!.personaName, 'Maya');
      });

      test('returns null for non-existent role', () async {
        final member = await repository.getByRoleType(BoardRoleType.accountability);
        expect(member, isNull);
      });
    });

    group('getActive', () {
      test('returns only active members', () async {
        await createMember(roleType: BoardRoleType.accountability, isActive: true);
        await createMember(roleType: BoardRoleType.marketReality, isActive: true);
        await createMember(roleType: BoardRoleType.portfolioDefender, isActive: false, isGrowthRole: true);

        final active = await repository.getActive();
        expect(active.length, 2);
        expect(active.every((m) => m.isActive), isTrue);
      });
    });

    group('getCoreRoles', () {
      test('returns only non-growth roles', () async {
        await createMember(roleType: BoardRoleType.accountability);
        await createMember(roleType: BoardRoleType.marketReality);
        await createMember(roleType: BoardRoleType.portfolioDefender, isGrowthRole: true);
        await createMember(roleType: BoardRoleType.opportunityScout, isGrowthRole: true);

        final core = await repository.getCoreRoles();
        expect(core.length, 2);
        expect(core.every((m) => !m.isGrowthRole), isTrue);
      });
    });

    group('getGrowthRoles', () {
      test('returns only growth roles', () async {
        await createMember(roleType: BoardRoleType.accountability);
        await createMember(roleType: BoardRoleType.portfolioDefender, isGrowthRole: true);
        await createMember(roleType: BoardRoleType.opportunityScout, isGrowthRole: true);

        final growth = await repository.getGrowthRoles();
        expect(growth.length, 2);
        expect(growth.every((m) => m.isGrowthRole), isTrue);
      });
    });

    group('getByAnchoredProblem', () {
      test('returns members anchored to a specific problem', () async {
        await createMember(
          roleType: BoardRoleType.accountability,
          anchoredProblemId: 'problem-1',
        );
        await createMember(
          roleType: BoardRoleType.avoidance,
          anchoredProblemId: 'problem-1',
        );
        await createMember(
          roleType: BoardRoleType.marketReality,
          anchoredProblemId: 'problem-2',
        );

        final members = await repository.getByAnchoredProblem('problem-1');
        expect(members.length, 2);
      });
    });

    group('setGrowthRolesActive', () {
      test('activates growth roles', () async {
        await createMember(roleType: BoardRoleType.portfolioDefender, isGrowthRole: true, isActive: false);
        await createMember(roleType: BoardRoleType.opportunityScout, isGrowthRole: true, isActive: false);
        await createMember(roleType: BoardRoleType.accountability, isActive: true);

        await repository.setGrowthRolesActive(true);

        final growth = await repository.getGrowthRoles();
        expect(growth.every((m) => m.isActive), isTrue);
      });

      test('deactivates growth roles', () async {
        await createMember(roleType: BoardRoleType.portfolioDefender, isGrowthRole: true, isActive: true);
        await createMember(roleType: BoardRoleType.opportunityScout, isGrowthRole: true, isActive: true);

        await repository.setGrowthRolesActive(false);

        final growth = await repository.getGrowthRoles();
        expect(growth.every((m) => !m.isActive), isTrue);
      });
    });

    group('updateAnchoring', () {
      test('updates problem and demand anchoring', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);

        await repository.updateAnchoring(
          id,
          problemId: 'new-problem',
          demand: 'New demand question',
        );

        final member = await repository.getById(id);
        expect(member!.anchoredProblemId, 'new-problem');
        expect(member.anchoredDemand, 'New demand question');
      });
    });

    group('updatePersona', () {
      test('updates persona fields', () async {
        final id = await createMember(name: 'Original');

        await repository.updatePersona(
          id,
          name: 'Updated Name',
          background: 'Updated background',
          communicationStyle: 'Updated style',
          signaturePhrase: 'Updated phrase',
        );

        final member = await repository.getById(id);
        expect(member!.personaName, 'Updated Name');
        expect(member.personaBackground, 'Updated background');
        expect(member.personaCommunicationStyle, 'Updated style');
        expect(member.personaSignaturePhrase, 'Updated phrase');

        // Original should be unchanged
        expect(member.originalPersonaName, 'Original');
      });
    });

    group('resetPersona', () {
      test('resets persona to original values', () async {
        final id = await repository.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Original Name',
          personaBackground: 'Original Background',
          personaCommunicationStyle: 'Original Style',
          personaSignaturePhrase: 'Original Phrase',
        );

        // Update persona
        await repository.updatePersona(
          id,
          name: 'Custom Name',
          background: 'Custom Background',
        );

        // Verify update
        var member = await repository.getById(id);
        expect(member!.personaName, 'Custom Name');

        // Reset persona
        await repository.resetPersona(id);

        // Verify reset
        member = await repository.getById(id);
        expect(member!.personaName, 'Original Name');
        expect(member.personaBackground, 'Original Background');
        expect(member.personaCommunicationStyle, 'Original Style');
        expect(member.personaSignaturePhrase, 'Original Phrase');
      });
    });

    group('resetAllPersonas', () {
      test('resets all members to original personas', () async {
        final id1 = await repository.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Original 1',
          personaBackground: 'Background 1',
          personaCommunicationStyle: 'Style 1',
        );

        final id2 = await repository.create(
          roleType: BoardRoleType.marketReality,
          personaName: 'Original 2',
          personaBackground: 'Background 2',
          personaCommunicationStyle: 'Style 2',
        );

        // Update both
        await repository.updatePersona(id1, name: 'Custom 1');
        await repository.updatePersona(id2, name: 'Custom 2');

        // Reset all
        await repository.resetAllPersonas();

        // Verify both reset
        final member1 = await repository.getById(id1);
        final member2 = await repository.getById(id2);

        expect(member1!.personaName, 'Original 1');
        expect(member2!.personaName, 'Original 2');
      });
    });

    group('softDelete', () {
      test('soft deletes a member', () async {
        final id = await createMember();

        await repository.softDelete(id);

        final member = await repository.getById(id);
        expect(member, isNull);
      });
    });

    group('deleteAll', () {
      test('soft deletes all members', () async {
        await createMember(roleType: BoardRoleType.accountability);
        await createMember(roleType: BoardRoleType.marketReality);
        await createMember(roleType: BoardRoleType.avoidance);

        await repository.deleteAll();

        final members = await repository.getAll();
        expect(members, isEmpty);
      });
    });

    group('watchActive', () {
      test('emits updates when active members change', () async {
        final stream = repository.watchActive();

        expect(await stream.first, isEmpty);

        await createMember(isActive: true);

        final members = await stream.first;
        expect(members.length, 1);
      });
    });

    group('getAll', () {
      test('returns all non-deleted members', () async {
        await createMember(roleType: BoardRoleType.accountability);
        await createMember(roleType: BoardRoleType.marketReality);
        await createMember(roleType: BoardRoleType.avoidance);

        final members = await repository.getAll();
        expect(members.length, 3);
      });

      test('excludes soft-deleted members', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);
        await createMember(roleType: BoardRoleType.marketReality);

        await repository.softDelete(id);

        final members = await repository.getAll();
        expect(members.length, 1);
      });
    });

    group('getPendingSync', () {
      test('returns members with pending sync status', () async {
        await createMember(roleType: BoardRoleType.accountability);

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });

      test('excludes synced members', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final pending = await repository.getPendingSync();
        expect(pending, isEmpty);
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 5);

        final member = await (database.select(database.boardMembers)
              ..where((m) => m.id.equals(id)))
            .getSingle();

        expect(member.syncStatus, 'synced');
        expect(member.serverVersion, 5);
      });

      test('can set conflict status', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);

        await repository.updateSyncStatus(id, SyncStatus.conflict);

        final member = await (database.select(database.boardMembers)
              ..where((m) => m.id.equals(id)))
            .getSingle();

        expect(member.syncStatus, 'conflict');
      });
    });

    group('watchAll', () {
      test('emits updates when members change', () async {
        final stream = repository.watchAll();

        expect(await stream.first, isEmpty);

        await createMember(roleType: BoardRoleType.accountability);

        final members = await stream.first;
        expect(members.length, 1);
      });

      test('excludes soft-deleted members', () async {
        final id = await createMember(roleType: BoardRoleType.accountability);

        final stream = repository.watchAll();

        var members = await stream.first;
        expect(members.length, 1);

        await repository.softDelete(id);

        members = await stream.first;
        expect(members, isEmpty);
      });
    });

    group('watchById', () {
      test('emits updates for specific member', () async {
        final id = await createMember(name: 'Watched Member');

        final stream = repository.watchById(id);

        var member = await stream.first;
        expect(member, isNotNull);
        expect(member!.personaName, 'Watched Member');

        await repository.updatePersona(id, name: 'Updated Name');

        member = await stream.first;
        expect(member!.personaName, 'Updated Name');
      });

      test('emits null for deleted member', () async {
        final id = await createMember(name: 'To Delete');

        final stream = repository.watchById(id);

        var member = await stream.first;
        expect(member, isNotNull);

        await repository.softDelete(id);

        member = await stream.first;
        expect(member, isNull);
      });

      test('emits null for non-existent id', () async {
        final stream = repository.watchById('non-existent-id');

        final member = await stream.first;
        expect(member, isNull);
      });
    });
  });
}
