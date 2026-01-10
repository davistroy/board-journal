import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/providers/database_provider.dart';
import 'package:boardroom_journal/providers/settings_providers.dart';
import 'package:boardroom_journal/providers/repository_providers.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('Settings Providers', () {
    group('PrivacyServiceProvider', () {
      test('provides PrivacyService instance', () {
        final service = container.read(privacyServiceProvider);
        expect(service, isNotNull);
      });
    });

    group('AbstractionModeNotifier', () {
      test('initializes with false (default)', () async {
        // Wait for initialization
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(abstractionModeNotifierProvider);

        // Should be loaded with false
        expect(state.hasValue, isTrue);
        expect(state.valueOrNull, isFalse);
      });

      test('setEnabled updates state', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        await container.read(abstractionModeNotifierProvider.notifier).setEnabled(true);

        final state = container.read(abstractionModeNotifierProvider);
        expect(state.valueOrNull, isTrue);
      });

      test('toggle switches state', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        // Initially false
        expect(container.read(abstractionModeNotifierProvider).valueOrNull, isFalse);

        // Toggle to true
        await container.read(abstractionModeNotifierProvider.notifier).toggle();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(container.read(abstractionModeNotifierProvider).valueOrNull, isTrue);

        // Toggle to false
        await container.read(abstractionModeNotifierProvider.notifier).toggle();
        await Future.delayed(const Duration(milliseconds: 50));
        expect(container.read(abstractionModeNotifierProvider).valueOrNull, isFalse);
      });
    });

    group('AnalyticsNotifier', () {
      test('initializes with true (default per PRD)', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        final state = container.read(analyticsNotifierProvider);

        expect(state.hasValue, isTrue);
        expect(state.valueOrNull, isTrue);
      });

      test('setEnabled updates state', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        await container.read(analyticsNotifierProvider.notifier).setEnabled(false);

        final state = container.read(analyticsNotifierProvider);
        expect(state.valueOrNull, isFalse);
      });
    });

    group('BoardPersonaNotifier', () {
      test('updatePersona updates board member', () async {
        // Create a board member first
        final boardRepo = container.read(boardMemberRepositoryProvider);
        final memberId = await boardRepo.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Original Name',
          personaBackground: 'Original background text here.',
          personaCommunicationStyle: 'Direct and clear communication.',
        );

        // Update persona
        await container.read(boardPersonaNotifierProvider.notifier).updatePersona(
              memberId,
              name: 'New Name',
              background: 'New background.',
            );

        // Verify update
        final member = await boardRepo.getById(memberId);
        expect(member?.personaName, 'New Name');
        expect(member?.personaBackground, 'New background.');
      });

      test('resetPersona restores original values', () async {
        final boardRepo = container.read(boardMemberRepositoryProvider);

        // Create a board member
        final memberId = await boardRepo.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Original Name',
          personaBackground: 'Original background text here.',
          personaCommunicationStyle: 'Direct and clear communication.',
        );

        // Modify the persona
        await boardRepo.updatePersona(
          memberId,
          name: 'Modified Name',
          background: 'Modified background.',
        );

        // Verify modification
        var member = await boardRepo.getById(memberId);
        expect(member?.personaName, 'Modified Name');

        // Reset persona
        await container.read(boardPersonaNotifierProvider.notifier).resetPersona(memberId);

        // Verify reset
        member = await boardRepo.getById(memberId);
        expect(member?.personaName, 'Original Name');
        expect(member?.personaBackground, 'Original background text here.');
      });

      test('resetAllPersonas restores all original values', () async {
        final boardRepo = container.read(boardMemberRepositoryProvider);

        // Create multiple board members
        final member1Id = await boardRepo.create(
          roleType: BoardRoleType.accountability,
          personaName: 'Member 1',
          personaBackground: 'Background 1 original.',
          personaCommunicationStyle: 'Style 1 original.',
        );

        final member2Id = await boardRepo.create(
          roleType: BoardRoleType.marketReality,
          personaName: 'Member 2',
          personaBackground: 'Background 2 original.',
          personaCommunicationStyle: 'Style 2 original.',
        );

        // Modify both
        await boardRepo.updatePersona(member1Id, name: 'Modified 1');
        await boardRepo.updatePersona(member2Id, name: 'Modified 2');

        // Verify modifications
        expect((await boardRepo.getById(member1Id))?.personaName, 'Modified 1');
        expect((await boardRepo.getById(member2Id))?.personaName, 'Modified 2');

        // Reset all
        await container.read(boardPersonaNotifierProvider.notifier).resetAllPersonas();

        // Verify all reset
        expect((await boardRepo.getById(member1Id))?.personaName, 'Member 1');
        expect((await boardRepo.getById(member2Id))?.personaName, 'Member 2');
      });
    });

    group('ProblemEditorNotifier', () {
      test('updateProblem updates problem fields', () async {
        final problemRepo = container.read(problemRepositoryProvider);

        // Create a problem
        final problemId = await problemRepo.create(
          name: 'Original Problem',
          whatBreaks: 'Original what breaks.',
          scarcitySignalsJson: '["signal1", "signal2"]',
          direction: ProblemDirection.stable,
          directionRationale: 'Original rationale.',
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'Low',
          evidenceTrustRequired: 'No',
          timeAllocationPercent: 30,
        );

        // Update problem
        await container.read(problemEditorNotifierProvider.notifier).updateProblem(
              problemId,
              name: 'Updated Problem',
              whatBreaks: 'Updated what breaks.',
            );

        // Verify update
        final problem = await problemRepo.getById(problemId);
        expect(problem?.name, 'Updated Problem');
        expect(problem?.whatBreaks, 'Updated what breaks.');
      });

      test('updateAllocation updates time allocation', () async {
        final problemRepo = container.read(problemRepositoryProvider);

        final problemId = await problemRepo.create(
          name: 'Test Problem',
          whatBreaks: 'Test what breaks.',
          scarcitySignalsJson: '["signal1", "signal2"]',
          direction: ProblemDirection.stable,
          directionRationale: 'Test rationale.',
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'Low',
          evidenceTrustRequired: 'No',
          timeAllocationPercent: 30,
        );

        await container.read(problemEditorNotifierProvider.notifier).updateAllocation(
              problemId,
              50,
            );

        final problem = await problemRepo.getById(problemId);
        expect(problem?.timeAllocationPercent, 50);
      });

      test('deleteProblem deletes when above minimum', () async {
        final problemRepo = container.read(problemRepositoryProvider);

        // Create 4 problems (above minimum of 3)
        for (int i = 0; i < 4; i++) {
          await problemRepo.create(
            name: 'Problem $i',
            whatBreaks: 'What breaks $i.',
            scarcitySignalsJson: '["signal1", "signal2"]',
            direction: ProblemDirection.stable,
            directionRationale: 'Rationale $i.',
            evidenceAiCheaper: 'No',
            evidenceErrorCost: 'Low',
            evidenceTrustRequired: 'No',
            timeAllocationPercent: 25,
          );
        }

        final problems = await problemRepo.getAll();
        expect(problems.length, 4);

        // Delete one
        final success = await container
            .read(problemEditorNotifierProvider.notifier)
            .deleteProblem(problems[0].id);

        expect(success, isTrue);

        final remaining = await problemRepo.getAll();
        expect(remaining.length, 3);
      });

      test('deleteProblem fails at minimum', () async {
        final problemRepo = container.read(problemRepositoryProvider);

        // Create exactly 3 problems (minimum)
        for (int i = 0; i < 3; i++) {
          await problemRepo.create(
            name: 'Problem $i',
            whatBreaks: 'What breaks $i.',
            scarcitySignalsJson: '["signal1", "signal2"]',
            direction: ProblemDirection.stable,
            directionRationale: 'Rationale $i.',
            evidenceAiCheaper: 'No',
            evidenceErrorCost: 'Low',
            evidenceTrustRequired: 'No',
            timeAllocationPercent: 33,
          );
        }

        final problems = await problemRepo.getAll();
        expect(problems.length, 3);

        // Try to delete one
        final success = await container
            .read(problemEditorNotifierProvider.notifier)
            .deleteProblem(problems[0].id);

        expect(success, isFalse);

        final remaining = await problemRepo.getAll();
        expect(remaining.length, 3);
      });
    });

    group('DataManagementNotifier', () {
      test('deleteAllData clears all tables', () async {
        // Add some data
        final dailyRepo = container.read(dailyEntryRepositoryProvider);
        final problemRepo = container.read(problemRepositoryProvider);

        await dailyRepo.create(
          transcriptText: 'Test entry.',
          recordedAtUtc: DateTime.now().toUtc(),
          recordingDurationSeconds: 60,
        );

        await problemRepo.create(
          name: 'Test Problem',
          whatBreaks: 'Test what breaks.',
          scarcitySignalsJson: '["signal1", "signal2"]',
          direction: ProblemDirection.stable,
          directionRationale: 'Test rationale.',
          evidenceAiCheaper: 'No',
          evidenceErrorCost: 'Low',
          evidenceTrustRequired: 'No',
          timeAllocationPercent: 100,
        );

        // Verify data exists
        expect((await dailyRepo.getAll()).length, 1);
        expect((await problemRepo.getAll()).length, 1);

        // Delete all data
        await container.read(dataManagementNotifierProvider.notifier).deleteAllData();

        // Verify all deleted
        expect((await dailyRepo.getAll()).length, 0);
        expect((await problemRepo.getAll()).length, 0);
      });
    });

    group('Version History Providers', () {
      test('allVersionsProvider returns empty list initially', () async {
        final versions = await container.read(allVersionsProvider.future);
        expect(versions, isEmpty);
      });

      test('allVersionsProvider returns versions after creation', () async {
        final versionRepo = container.read(portfolioVersionRepositoryProvider);

        await versionRepo.create(
          versionNumber: 1,
          problemsSnapshotJson: '[]',
          healthSnapshotJson: '{}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '[]',
          triggerReason: 'Initial setup',
        );

        // Invalidate to refresh
        container.invalidate(allVersionsProvider);

        final versions = await container.read(allVersionsProvider.future);
        expect(versions.length, 1);
        expect(versions[0].versionNumber, 1);
      });

      test('versionComparisonProvider returns two versions', () async {
        final versionRepo = container.read(portfolioVersionRepositoryProvider);

        await versionRepo.create(
          versionNumber: 1,
          problemsSnapshotJson: '[]',
          healthSnapshotJson: '{"appreciatingPercent": 30}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '[]',
          triggerReason: 'Initial setup',
        );

        await versionRepo.create(
          versionNumber: 2,
          problemsSnapshotJson: '[]',
          healthSnapshotJson: '{"appreciatingPercent": 50}',
          boardAnchoringSnapshotJson: '{}',
          triggersSnapshotJson: '[]',
          triggerReason: 'Re-setup',
        );

        final comparison =
            await container.read(versionComparisonProvider((v1: 1, v2: 2)).future);

        expect(comparison.length, 2);
      });
    });

    group('Re-setup Triggers Providers', () {
      test('allTriggersProvider returns empty list initially', () async {
        final triggers = await container.read(allTriggersProvider.future);
        expect(triggers, isEmpty);
      });

      test('allTriggersProvider returns triggers after creation', () async {
        final triggerRepo = container.read(reSetupTriggerRepositoryProvider);

        await triggerRepo.create(
          triggerType: 'annual',
          description: 'Annual review',
          condition: '12 months since setup',
          recommendedAction: 'full_resetup',
        );

        container.invalidate(allTriggersProvider);

        final triggers = await container.read(allTriggersProvider.future);
        expect(triggers.length, 1);
      });
    });
  });
}
