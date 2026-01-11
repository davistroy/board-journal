import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';
import 'package:boardroom_journal/services/settings/privacy_service.dart';

void main() {
  late AppDatabase database;
  late UserPreferencesRepository prefsRepository;
  late PrivacyService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    prefsRepository = UserPreferencesRepository(database);
    service = PrivacyService(prefsRepository);
  });

  tearDown(() async {
    await database.close();
  });

  group('PrivacyService', () {
    group('Abstraction Mode', () {
      test('getAbstractionMode returns false by default', () async {
        final enabled = await service.getAbstractionMode();
        expect(enabled, isFalse);
      });

      test('setAbstractionMode enables for all session types', () async {
        await service.setAbstractionMode(true);

        expect(await service.getAbstractionModeQuick(), isTrue);
        expect(await service.getAbstractionModeSetup(), isTrue);
        expect(await service.getAbstractionModeQuarterly(), isTrue);
      });

      test('setAbstractionMode disables for all session types', () async {
        // First enable
        await service.setAbstractionMode(true);
        // Then disable
        await service.setAbstractionMode(false);

        expect(await service.getAbstractionModeQuick(), isFalse);
        expect(await service.getAbstractionModeSetup(), isFalse);
        expect(await service.getAbstractionModeQuarterly(), isFalse);
      });

      test('getAbstractionMode returns true if any session type is enabled', () async {
        await service.setAbstractionModeForSession(quick: true);

        expect(await service.getAbstractionMode(), isTrue);
      });

      test('setAbstractionModeForSession updates individual session types', () async {
        await service.setAbstractionModeForSession(
          quick: true,
          setup: false,
          quarterly: true,
        );

        expect(await service.getAbstractionModeQuick(), isTrue);
        expect(await service.getAbstractionModeSetup(), isFalse);
        expect(await service.getAbstractionModeQuarterly(), isTrue);
      });

      test('getAbstractionModeQuick returns correct value', () async {
        expect(await service.getAbstractionModeQuick(), isFalse);

        await service.setAbstractionModeForSession(quick: true);

        expect(await service.getAbstractionModeQuick(), isTrue);
      });

      test('getAbstractionModeSetup returns correct value', () async {
        expect(await service.getAbstractionModeSetup(), isFalse);

        await service.setAbstractionModeForSession(setup: true);

        expect(await service.getAbstractionModeSetup(), isTrue);
      });

      test('getAbstractionModeQuarterly returns correct value', () async {
        expect(await service.getAbstractionModeQuarterly(), isFalse);

        await service.setAbstractionModeForSession(quarterly: true);

        expect(await service.getAbstractionModeQuarterly(), isTrue);
      });
    });

    group('Remember Choice', () {
      test('getRememberAbstractionChoice returns false by default', () async {
        final remember = await service.getRememberAbstractionChoice();
        expect(remember, isFalse);
      });

      test('setRememberAbstractionChoice persists value', () async {
        await service.setRememberAbstractionChoice(true);

        expect(await service.getRememberAbstractionChoice(), isTrue);

        await service.setRememberAbstractionChoice(false);

        expect(await service.getRememberAbstractionChoice(), isFalse);
      });
    });

    group('Analytics', () {
      test('getAnalyticsEnabled returns true by default (per PRD)', () async {
        final enabled = await service.getAnalyticsEnabled();
        expect(enabled, isTrue);
      });

      test('setAnalyticsEnabled persists value', () async {
        await service.setAnalyticsEnabled(false);

        expect(await service.getAnalyticsEnabled(), isFalse);

        await service.setAnalyticsEnabled(true);

        expect(await service.getAnalyticsEnabled(), isTrue);
      });
    });

    group('Reset to Defaults', () {
      test('resetToDefaults restores all default values', () async {
        // Change all values from defaults
        await service.setAbstractionMode(true);
        await service.setRememberAbstractionChoice(true);
        await service.setAnalyticsEnabled(false);

        // Verify changes
        expect(await service.getAbstractionMode(), isTrue);
        expect(await service.getRememberAbstractionChoice(), isTrue);
        expect(await service.getAnalyticsEnabled(), isFalse);

        // Reset to defaults
        await service.resetToDefaults();

        // Verify defaults restored
        expect(await service.getAbstractionModeQuick(), isFalse);
        expect(await service.getAbstractionModeSetup(), isFalse);
        expect(await service.getAbstractionModeQuarterly(), isFalse);
        expect(await service.getRememberAbstractionChoice(), isFalse);
        expect(await service.getAnalyticsEnabled(), isTrue);
      });
    });
  });
}
