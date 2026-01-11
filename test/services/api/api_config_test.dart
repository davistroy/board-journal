import 'package:flutter_test/flutter_test.dart';

import 'package:boardroom_journal/services/api/api_config.dart';

void main() {
  group('ApiConfig', () {
    group('Default values', () {
      test('has correct default baseUrl', () {
        const config = ApiConfig();

        expect(config.baseUrl, 'https://api.boardroomjournal.app');
      });

      test('has correct default timeoutSeconds', () {
        const config = ApiConfig();

        expect(config.timeoutSeconds, 30);
      });

      test('has correct default maxRetries', () {
        const config = ApiConfig();

        expect(config.maxRetries, 3);
      });

      test('has correct default retryDelayMs', () {
        const config = ApiConfig();

        expect(config.retryDelayMs, 1000);
      });

      test('has correct default syncDebounceMs', () {
        const config = ApiConfig();

        expect(config.syncDebounceMs, 2000);
      });

      test('has correct default periodicSyncMinutes', () {
        const config = ApiConfig();

        expect(config.periodicSyncMinutes, 5);
      });
    });

    group('Factory constructors', () {
      group('development', () {
        test('has localhost baseUrl', () {
          final config = ApiConfig.development();

          expect(config.baseUrl, 'http://localhost:8080');
        });

        test('has faster retry delay for development', () {
          final config = ApiConfig.development();

          expect(config.retryDelayMs, 500);
        });

        test('has correct timeout', () {
          final config = ApiConfig.development();

          expect(config.timeoutSeconds, 30);
        });

        test('has correct maxRetries', () {
          final config = ApiConfig.development();

          expect(config.maxRetries, 3);
        });
      });

      group('staging', () {
        test('has staging baseUrl', () {
          final config = ApiConfig.staging();

          expect(config.baseUrl, 'https://staging-api.boardroomjournal.app');
        });

        test('has correct timeout', () {
          final config = ApiConfig.staging();

          expect(config.timeoutSeconds, 30);
        });

        test('has correct retryDelayMs', () {
          final config = ApiConfig.staging();

          expect(config.retryDelayMs, 1000);
        });
      });

      group('production', () {
        test('has production baseUrl', () {
          final config = ApiConfig.production();

          expect(config.baseUrl, 'https://api.boardroomjournal.app');
        });

        test('has correct timeout', () {
          final config = ApiConfig.production();

          expect(config.timeoutSeconds, 30);
        });

        test('has correct retryDelayMs', () {
          final config = ApiConfig.production();

          expect(config.retryDelayMs, 1000);
        });

        test('has correct syncDebounceMs', () {
          final config = ApiConfig.production();

          expect(config.syncDebounceMs, 2000);
        });

        test('has correct periodicSyncMinutes', () {
          final config = ApiConfig.production();

          expect(config.periodicSyncMinutes, 5);
        });
      });
    });

    group('Computed properties', () {
      test('timeout returns Duration from timeoutSeconds', () {
        const config = ApiConfig(timeoutSeconds: 45);

        expect(config.timeout, const Duration(seconds: 45));
      });

      test('syncDebounce returns Duration from syncDebounceMs', () {
        const config = ApiConfig(syncDebounceMs: 3000);

        expect(config.syncDebounce, const Duration(milliseconds: 3000));
      });

      test('periodicSyncInterval returns Duration from periodicSyncMinutes', () {
        const config = ApiConfig(periodicSyncMinutes: 10);

        expect(config.periodicSyncInterval, const Duration(minutes: 10));
      });
    });

    group('retryDelay', () {
      test('returns base delay for attempt 0', () {
        const config = ApiConfig(retryDelayMs: 1000);

        expect(config.retryDelay(0), const Duration(milliseconds: 1000));
      });

      test('returns doubled delay for attempt 1', () {
        const config = ApiConfig(retryDelayMs: 1000);

        expect(config.retryDelay(1), const Duration(milliseconds: 2000));
      });

      test('returns quadrupled delay for attempt 2', () {
        const config = ApiConfig(retryDelayMs: 1000);

        expect(config.retryDelay(2), const Duration(milliseconds: 4000));
      });

      test('returns 8x delay for attempt 3', () {
        const config = ApiConfig(retryDelayMs: 1000);

        expect(config.retryDelay(3), const Duration(milliseconds: 8000));
      });

      test('clamps to max 30 seconds for high attempt numbers', () {
        const config = ApiConfig(retryDelayMs: 1000);

        // 2^10 * 1000 = 1,024,000 ms, should be clamped to 30,000
        expect(config.retryDelay(10), const Duration(milliseconds: 30000));
      });

      test('respects custom retryDelayMs', () {
        const config = ApiConfig(retryDelayMs: 500);

        expect(config.retryDelay(0), const Duration(milliseconds: 500));
        expect(config.retryDelay(1), const Duration(milliseconds: 1000));
        expect(config.retryDelay(2), const Duration(milliseconds: 2000));
      });
    });

    group('Custom configuration', () {
      test('allows custom baseUrl', () {
        const config = ApiConfig(baseUrl: 'https://custom.api.com');

        expect(config.baseUrl, 'https://custom.api.com');
      });

      test('allows custom timeout', () {
        const config = ApiConfig(timeoutSeconds: 60);

        expect(config.timeoutSeconds, 60);
        expect(config.timeout, const Duration(seconds: 60));
      });

      test('allows all custom values', () {
        const config = ApiConfig(
          baseUrl: 'https://test.com',
          timeoutSeconds: 15,
          maxRetries: 5,
          retryDelayMs: 2000,
          syncDebounceMs: 5000,
          periodicSyncMinutes: 10,
        );

        expect(config.baseUrl, 'https://test.com');
        expect(config.timeoutSeconds, 15);
        expect(config.maxRetries, 5);
        expect(config.retryDelayMs, 2000);
        expect(config.syncDebounceMs, 5000);
        expect(config.periodicSyncMinutes, 10);
      });
    });
  });

  group('ApiEndpoints', () {
    group('Authentication endpoints', () {
      test('authRefresh has correct path', () {
        expect(ApiEndpoints.authRefresh, '/auth/refresh');
      });

      test('authRevoke has correct path', () {
        expect(ApiEndpoints.authRevoke, '/auth/revoke');
      });
    });

    group('Sync endpoints', () {
      test('syncPull has correct path', () {
        expect(ApiEndpoints.syncPull, '/sync/pull');
      });

      test('syncPush has correct path', () {
        expect(ApiEndpoints.syncPush, '/sync/push');
      });

      test('syncFull has correct path', () {
        expect(ApiEndpoints.syncFull, '/sync/full');
      });

      test('syncStatus has correct path', () {
        expect(ApiEndpoints.syncStatus, '/sync/status');
      });
    });

    group('Daily entries endpoints', () {
      test('entriesBase has correct path', () {
        expect(ApiEndpoints.entriesBase, '/entries');
      });

      test('entryById returns correct path', () {
        expect(ApiEndpoints.entryById('entry-123'), '/entries/entry-123');
      });

      test('entryById handles uuid', () {
        expect(
          ApiEndpoints.entryById('550e8400-e29b-41d4-a716-446655440000'),
          '/entries/550e8400-e29b-41d4-a716-446655440000',
        );
      });
    });

    group('Weekly briefs endpoints', () {
      test('briefsBase has correct path', () {
        expect(ApiEndpoints.briefsBase, '/briefs');
      });

      test('briefById returns correct path', () {
        expect(ApiEndpoints.briefById('brief-456'), '/briefs/brief-456');
      });
    });

    group('Problems endpoints', () {
      test('problemsBase has correct path', () {
        expect(ApiEndpoints.problemsBase, '/problems');
      });

      test('problemById returns correct path', () {
        expect(ApiEndpoints.problemById('problem-789'), '/problems/problem-789');
      });
    });

    group('Board members endpoints', () {
      test('boardMembersBase has correct path', () {
        expect(ApiEndpoints.boardMembersBase, '/board-members');
      });

      test('boardMemberById returns correct path', () {
        expect(ApiEndpoints.boardMemberById('member-1'), '/board-members/member-1');
      });
    });

    group('Bets endpoints', () {
      test('betsBase has correct path', () {
        expect(ApiEndpoints.betsBase, '/bets');
      });

      test('betById returns correct path', () {
        expect(ApiEndpoints.betById('bet-abc'), '/bets/bet-abc');
      });
    });

    group('Governance sessions endpoints', () {
      test('governanceSessionsBase has correct path', () {
        expect(ApiEndpoints.governanceSessionsBase, '/governance-sessions');
      });

      test('governanceSessionById returns correct path', () {
        expect(
          ApiEndpoints.governanceSessionById('session-xyz'),
          '/governance-sessions/session-xyz',
        );
      });
    });

    group('AI processing endpoints', () {
      test('transcribe has correct path', () {
        expect(ApiEndpoints.transcribe, '/ai/transcribe');
      });

      test('extractSignals has correct path', () {
        expect(ApiEndpoints.extractSignals, '/ai/extract-signals');
      });

      test('generateBrief has correct path', () {
        expect(ApiEndpoints.generateBrief, '/ai/generate-brief');
      });
    });
  });
}
