import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/ai/ai_config.dart';

void main() {
  group('AIConfig', () {
    group('constructor', () {
      test('creates with required apiKey', () {
        const config = AIConfig(anthropicApiKey: 'test-api-key');

        expect(config.anthropicApiKey, 'test-api-key');
      });

      test('is const constructible', () {
        const config1 = AIConfig(anthropicApiKey: 'key1');
        const config2 = AIConfig(anthropicApiKey: 'key1');

        expect(identical(config1, config2), isTrue);
      });
    });

    group('isValid', () {
      test('returns true when apiKey is not empty', () {
        const config = AIConfig(anthropicApiKey: 'valid-key');

        expect(config.isValid, isTrue);
      });

      test('returns false when apiKey is empty string', () {
        const config = AIConfig(anthropicApiKey: '');

        expect(config.isValid, isFalse);
      });

      test('returns true for single character key', () {
        const config = AIConfig(anthropicApiKey: 'x');

        expect(config.isValid, isTrue);
      });
    });

    group('withKey factory', () {
      test('creates config with provided key', () {
        final config = AIConfig.withKey('my-custom-key');

        expect(config.anthropicApiKey, 'my-custom-key');
        expect(config.isValid, isTrue);
      });

      test('creates invalid config with empty key', () {
        final config = AIConfig.withKey('');

        expect(config.anthropicApiKey, '');
        expect(config.isValid, isFalse);
      });
    });

    group('mock factory', () {
      test('creates config with mock api key', () {
        final config = AIConfig.mock();

        expect(config.anthropicApiKey, 'mock-api-key');
        expect(config.isValid, isTrue);
      });

      test('returns consistent mock config', () {
        final config1 = AIConfig.mock();
        final config2 = AIConfig.mock();

        expect(config1.anthropicApiKey, config2.anthropicApiKey);
      });
    });

    group('fromEnvironment factory', () {
      // Note: This test may behave differently depending on environment
      // In test environment, ANTHROPIC_API_KEY is typically not set
      test('returns config (may be empty if env var not set)', () {
        final config = AIConfig.fromEnvironment();

        // Config is always returned, but may be invalid if env var not set
        expect(config, isA<AIConfig>());
      });
    });
  });
}
