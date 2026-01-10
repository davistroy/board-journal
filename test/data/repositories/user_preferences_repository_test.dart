import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late UserPreferencesRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = UserPreferencesRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('UserPreferencesRepository', () {
    group('get', () {
      test('creates default preferences if none exist', () async {
        final prefs = await repository.get();

        expect(prefs, isNotNull);
        expect(prefs.abstractionModeQuick, isFalse);
        expect(prefs.abstractionModeSetup, isFalse);
        expect(prefs.abstractionModeQuarterly, isFalse);
        expect(prefs.analyticsEnabled, isTrue); // ON by default per PRD
        expect(prefs.onboardingCompleted, isFalse);
        expect(prefs.totalEntryCount, 0);
      });

      test('returns existing preferences', () async {
        // Create preferences
        await repository.get();

        // Update a value
        await repository.setAnalyticsEnabled(false);

        // Get again - should return same record
        final prefs = await repository.get();
        expect(prefs.analyticsEnabled, isFalse);

        // Should only be one record
        final allPrefs = await database.select(database.userPreferences).get();
        expect(allPrefs.length, 1);
      });
    });

    group('updateAbstractionDefaults', () {
      test('updates abstraction mode settings', () async {
        await repository.updateAbstractionDefaults(
          quick: true,
          setup: true,
          quarterly: false,
          rememberChoice: true,
        );

        final prefs = await repository.get();
        expect(prefs.abstractionModeQuick, isTrue);
        expect(prefs.abstractionModeSetup, isTrue);
        expect(prefs.abstractionModeQuarterly, isFalse);
        expect(prefs.rememberAbstractionChoice, isTrue);
      });

      test('only updates specified fields', () async {
        await repository.updateAbstractionDefaults(quick: true);

        final prefs = await repository.get();
        expect(prefs.abstractionModeQuick, isTrue);
        expect(prefs.abstractionModeSetup, isFalse); // Unchanged
      });
    });

    group('setAnalyticsEnabled', () {
      test('updates analytics setting', () async {
        await repository.setAnalyticsEnabled(false);

        final prefs = await repository.get();
        expect(prefs.analyticsEnabled, isFalse);
      });
    });

    group('setMicroReviewCollapsed', () {
      test('updates micro review collapsed setting', () async {
        await repository.setMicroReviewCollapsed(true);

        final prefs = await repository.get();
        expect(prefs.microReviewCollapsed, isTrue);
      });
    });

    group('onboarding', () {
      test('completeOnboarding marks onboarding as completed', () async {
        expect(await repository.isOnboardingCompleted(), isFalse);

        await repository.completeOnboarding();

        expect(await repository.isOnboardingCompleted(), isTrue);
      });
    });

    group('setup prompt', () {
      test('shouldShowSetupPrompt returns false when dismissed recently', () async {
        // First ensure prefs exist
        await repository.get();

        // Dismiss the prompt
        await repository.dismissSetupPrompt();

        final shouldShow = await repository.shouldShowSetupPrompt();
        expect(shouldShow, isFalse);
      });

      test('shouldShowSetupPrompt returns true after enough entries', () async {
        // Create prefs with enough entries
        await repository.get();

        // Increment entry count to trigger
        await repository.incrementEntryCount();
        await repository.incrementEntryCount();
        await repository.incrementEntryCount();

        final shouldShow = await repository.shouldShowSetupPrompt();
        expect(shouldShow, isTrue);
      });

      test('shouldShowSetupPrompt returns false with few entries', () async {
        await repository.get();
        await repository.incrementEntryCount();
        await repository.incrementEntryCount();

        final shouldShow = await repository.shouldShowSetupPrompt();
        expect(shouldShow, isFalse);
      });

      test('recordSetupPromptShown updates timestamp', () async {
        await repository.get();
        await repository.recordSetupPromptShown();

        final prefs = await repository.get();
        expect(prefs.setupPromptLastShownUtc, isNotNull);
      });
    });

    group('incrementEntryCount', () {
      test('increments total entry count', () async {
        expect(await repository.getTotalEntryCount(), 0);

        await repository.incrementEntryCount();
        expect(await repository.getTotalEntryCount(), 1);

        await repository.incrementEntryCount();
        expect(await repository.getTotalEntryCount(), 2);
      });
    });

    group('sync', () {
      test('getPendingSync returns preferences with pending status', () async {
        await repository.get(); // Creates with pending status

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });

      test('updateSyncStatus changes sync status', () async {
        final prefs = await repository.get();

        await repository.updateSyncStatus(prefs.id, SyncStatus.synced, serverVersion: 1);

        final updated =
            await (database.select(database.userPreferences)..where((p) => p.id.equals(prefs.id))).getSingle();

        expect(updated.syncStatus, 'synced');
        expect(updated.serverVersion, 1);
      });
    });

    group('watch', () {
      test('emits updates when preferences change', () async {
        final stream = repository.watch();

        // Create preferences
        await repository.get();

        final prefs = await stream.first;
        expect(prefs, isNotNull);
        expect(prefs!.analyticsEnabled, isTrue);

        // Update preferences
        await repository.setAnalyticsEnabled(false);

        final updatedPrefs = await stream.first;
        expect(updatedPrefs!.analyticsEnabled, isFalse);
      });
    });
  });
}
