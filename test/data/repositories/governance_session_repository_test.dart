import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boardroom_journal/data/data.dart';

void main() {
  late AppDatabase database;
  late GovernanceSessionRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GovernanceSessionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('GovernanceSessionRepository', () {
    group('create', () {
      test('creates a new session with correct fields', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'sensitivity_gate',
          abstractionMode: true,
        );

        final session = await repository.getById(id);
        expect(session, isNotNull);
        expect(session!.sessionType, 'quick');
        expect(session.currentState, 'sensitivity_gate');
        expect(session.abstractionMode, isTrue);
        expect(session.isCompleted, isFalse);
        expect(session.vaguenessSkipCount, 0);
      });
    });

    group('getByType', () {
      test('returns sessions filtered by type', () async {
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );
        await repository.create(
          sessionType: GovernanceSessionType.setup,
          initialState: 's1',
        );
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q2',
        );

        final quickSessions = await repository.getByType(GovernanceSessionType.quick);
        expect(quickSessions.length, 2);
        expect(quickSessions.every((s) => s.sessionType == 'quick'), isTrue);
      });
    });

    group('getInProgress', () {
      test('returns in-progress session', () async {
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'in_progress_state',
        );

        final inProgress = await repository.getInProgress();
        expect(inProgress, isNotNull);
        expect(inProgress!.isCompleted, isFalse);
      });

      test('returns null when no in-progress sessions', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.complete(id, outputMarkdown: 'Output');

        final inProgress = await repository.getInProgress();
        expect(inProgress, isNull);
      });
    });

    group('getMostRecentCompleted', () {
      test('returns most recent completed session of type', () async {
        final id1 = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );
        await repository.complete(id1, outputMarkdown: 'Output 1');

        await Future.delayed(const Duration(seconds: 1));

        final id2 = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q2',
        );
        await repository.complete(id2, outputMarkdown: 'Output 2');

        final recent = await repository.getMostRecentCompleted(GovernanceSessionType.quick);
        expect(recent, isNotNull);
        expect(recent!.id, id2);
      });
    });

    group('hasRecentQuarterlyReport', () {
      test('returns true when quarterly completed within 30 days', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quarterly,
          initialState: 'start',
        );
        await repository.complete(id, outputMarkdown: 'Quarterly report');

        final hasRecent = await repository.hasRecentQuarterlyReport();
        expect(hasRecent, isTrue);
      });

      test('returns false when no quarterly completed', () async {
        // Only create a quick session
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );
        await repository.complete(id, outputMarkdown: 'Quick output');

        final hasRecent = await repository.hasRecentQuarterlyReport();
        expect(hasRecent, isFalse);
      });
    });

    group('updateState', () {
      test('updates current state', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'sensitivity_gate',
        );

        await repository.updateState(id, 'q1_role_context');

        final session = await repository.getById(id);
        expect(session!.currentState, 'q1_role_context');
      });
    });

    group('incrementVaguenessSkip', () {
      test('increments skip count', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final result = await repository.incrementVaguenessSkip(id);
        expect(result, isTrue);

        final session = await repository.getById(id);
        expect(session!.vaguenessSkipCount, 1);
      });

      test('returns false when max skips reached', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        // Skip twice (max is 2)
        await repository.incrementVaguenessSkip(id);
        await repository.incrementVaguenessSkip(id);

        // Third skip should fail
        final result = await repository.incrementVaguenessSkip(id);
        expect(result, isFalse);

        final session = await repository.getById(id);
        expect(session!.vaguenessSkipCount, 2); // Still 2
      });
    });

    group('getRemainingSkips', () {
      test('returns correct remaining skips', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        expect(await repository.getRemainingSkips(id), 2);

        await repository.incrementVaguenessSkip(id);
        expect(await repository.getRemainingSkips(id), 1);

        await repository.incrementVaguenessSkip(id);
        expect(await repository.getRemainingSkips(id), 0);
      });
    });

    group('complete', () {
      test('marks session as completed with output', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.complete(
          id,
          outputMarkdown: '# Audit Summary\n\nOutput here',
        );

        final session = await repository.getById(id);
        expect(session!.isCompleted, isTrue);
        expect(session.outputMarkdown, '# Audit Summary\n\nOutput here');
        expect(session.completedAtUtc, isNotNull);
        expect(session.durationSeconds, isNotNull);
      });

      test('stores related IDs for setup session', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.setup,
          initialState: 'start',
        );

        await repository.complete(
          id,
          outputMarkdown: 'Setup complete',
          createdPortfolioVersionId: 'portfolio-v1',
        );

        final session = await repository.getById(id);
        expect(session!.createdPortfolioVersionId, 'portfolio-v1');
      });

      test('stores bet IDs for quarterly session', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quarterly,
          initialState: 'start',
        );

        await repository.complete(
          id,
          outputMarkdown: 'Quarterly report',
          evaluatedBetId: 'old-bet-123',
          createdBetId: 'new-bet-456',
        );

        final session = await repository.getById(id);
        expect(session!.evaluatedBetId, 'old-bet-123');
        expect(session.createdBetId, 'new-bet-456');
      });
    });

    group('abandon', () {
      test('soft deletes in-progress session', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.abandon(id);

        final session = await repository.getById(id);
        expect(session, isNull);
      });
    });

    group('getSessionCountForPeriod', () {
      test('counts sessions in date range', () async {
        // Create sessions
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q2',
        );
        await repository.create(
          sessionType: GovernanceSessionType.setup,
          initialState: 's1',
        );

        final now = DateTime.now().toUtc();
        final range = DateRange(
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 1)),
        );

        final count = await repository.getSessionCountForPeriod(
          GovernanceSessionType.quick,
          range,
        );
        expect(count, 2);
      });
    });

    group('watchCompleted', () {
      test('emits updates when sessions complete', () async {
        final stream = repository.watchCompleted();

        expect(await stream.first, isEmpty);

        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );
        await repository.complete(id, outputMarkdown: 'Done');

        final sessions = await stream.first;
        expect(sessions.length, 1);
        expect(sessions[0].isCompleted, isTrue);
      });
    });

    group('getAll', () {
      test('returns all non-deleted sessions ordered by start date', () async {
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );

        await Future.delayed(const Duration(seconds: 1));

        await repository.create(
          sessionType: GovernanceSessionType.setup,
          initialState: 's1',
        );

        final sessions = await repository.getAll();
        expect(sessions.length, 2);
        // Ordered by start date descending, so most recent first
        expect(sessions[0].sessionType, 'setup');
        expect(sessions[1].sessionType, 'quick');
      });

      test('supports pagination', () async {
        for (var i = 0; i < 5; i++) {
          await repository.create(
            sessionType: GovernanceSessionType.quick,
            initialState: 'q$i',
          );
          await Future.delayed(const Duration(milliseconds: 50));
        }

        final page1 = await repository.getAll(limit: 2, offset: 0);
        expect(page1.length, 2);

        final page2 = await repository.getAll(limit: 2, offset: 2);
        expect(page2.length, 2);

        final page3 = await repository.getAll(limit: 2, offset: 4);
        expect(page3.length, 1);
      });

      test('excludes abandoned sessions', () async {
        final id1 = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q2',
        );

        await repository.abandon(id1);

        final sessions = await repository.getAll();
        expect(sessions.length, 1);
      });
    });

    group('getCompleted', () {
      test('returns only completed sessions', () async {
        final id1 = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q1',
        );
        await repository.complete(id1, outputMarkdown: 'Output 1');

        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'q2',
        ); // Not completed

        final id3 = await repository.create(
          sessionType: GovernanceSessionType.setup,
          initialState: 's1',
        );
        await repository.complete(id3, outputMarkdown: 'Output 3');

        final completed = await repository.getCompleted();
        expect(completed.length, 2);
        expect(completed.every((s) => s.isCompleted), isTrue);
      });
    });

    group('appendToTranscript', () {
      test('updates transcript JSON', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final transcriptJson = '{"q1": {"question": "Test?", "answer": "Yes"}}';
        await repository.appendToTranscript(id, transcriptJson);

        final session = await repository.getById(id);
        expect(session!.transcriptJson, transcriptJson);
      });

      test('updates sync status to pending', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.appendToTranscript(id, '{"test": "data"}');

        final session = await (database.select(database.governanceSessions)
              ..where((s) => s.id.equals(id)))
            .getSingle();

        expect(session.syncStatus, 'pending');
      });
    });

    group('getPendingSync', () {
      test('returns sessions with pending sync status', () async {
        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final pending = await repository.getPendingSync();
        expect(pending.length, 1);
        expect(pending[0].syncStatus, 'pending');
      });

      test('excludes synced sessions', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 1);

        final pending = await repository.getPendingSync();
        expect(pending, isEmpty);
      });
    });

    group('updateSyncStatus', () {
      test('updates sync status and server version', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.updateSyncStatus(id, SyncStatus.synced, serverVersion: 5);

        final session = await (database.select(database.governanceSessions)
              ..where((s) => s.id.equals(id)))
            .getSingle();

        expect(session.syncStatus, 'synced');
        expect(session.serverVersion, 5);
      });

      test('can set conflict status', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        await repository.updateSyncStatus(id, SyncStatus.conflict);

        final session = await (database.select(database.governanceSessions)
              ..where((s) => s.id.equals(id)))
            .getSingle();

        expect(session.syncStatus, 'conflict');
      });
    });

    group('watchAll', () {
      test('emits updates when sessions change', () async {
        final stream = repository.watchAll();

        expect(await stream.first, isEmpty);

        await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final sessions = await stream.first;
        expect(sessions.length, 1);
      });

      test('excludes abandoned sessions', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final stream = repository.watchAll();

        var sessions = await stream.first;
        expect(sessions.length, 1);

        await repository.abandon(id);

        sessions = await stream.first;
        expect(sessions, isEmpty);
      });
    });

    group('watchById', () {
      test('emits updates for specific session', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final stream = repository.watchById(id);

        var session = await stream.first;
        expect(session, isNotNull);
        expect(session!.currentState, 'start');

        await repository.updateState(id, 'q1');

        session = await stream.first;
        expect(session!.currentState, 'q1');
      });

      test('emits null for abandoned session', () async {
        final id = await repository.create(
          sessionType: GovernanceSessionType.quick,
          initialState: 'start',
        );

        final stream = repository.watchById(id);

        var session = await stream.first;
        expect(session, isNotNull);

        await repository.abandon(id);

        session = await stream.first;
        expect(session, isNull);
      });

      test('emits null for non-existent id', () async {
        final stream = repository.watchById('non-existent-id');

        final session = await stream.first;
        expect(session, isNull);
      });
    });
  });
}
