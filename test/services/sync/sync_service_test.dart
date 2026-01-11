import 'dart:async';

import 'package:boardroom_journal/data/database/database.dart';
import 'package:boardroom_journal/models/models.dart';
import 'package:boardroom_journal/services/api/api.dart';
import 'package:boardroom_journal/services/auth/auth.dart';
import 'package:boardroom_journal/services/sync/sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockTokenStorage extends Mock implements TokenStorage {
  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<bool> needsProactiveRefresh() async => false;
}

class MockAuthService extends Mock implements AuthService {
  @override
  Future<AuthResult> refreshToken() async {
    return AuthResult.success(
      user: AppUser(
        id: 'test-user',
        email: 'test@example.com',
        provider: AuthProvider.google,
        createdAt: DateTime.now(),
      ),
    );
  }
}

class MockConnectivity extends Mock implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  List<ConnectivityResult> _currentConnectivity = [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return _currentConnectivity;
  }

  void setConnectivity(List<ConnectivityResult> result) {
    _currentConnectivity = result;
  }

  void simulateConnectivityChange(List<ConnectivityResult> result) {
    _currentConnectivity = result;
    _controller.add(result);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  late AppDatabase database;
  late SyncQueue syncQueue;
  late ConflictResolver conflictResolver;
  late SyncService syncService;
  late MockConnectivity mockConnectivity;
  late MockTokenStorage mockTokenStorage;
  late MockAuthService mockAuthService;

  setUp(() async {
    // Set up shared preferences mock
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Create in-memory database
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

    // Create sync queue
    syncQueue = SyncQueue(prefs);

    // Create conflict resolver
    conflictResolver = ConflictResolver();

    // Create mock connectivity
    mockConnectivity = MockConnectivity();

    // Create mock auth services
    mockTokenStorage = MockTokenStorage();
    mockAuthService = MockAuthService();

    // Create API client
    final config = ApiConfig.development();
    final apiClient = ApiClient(
      config: config,
      tokenStorage: mockTokenStorage,
      authService: mockAuthService,
    );

    // Create sync service
    syncService = SyncService(
      apiClient: apiClient,
      config: config,
      database: database,
      queue: syncQueue,
      conflictResolver: conflictResolver,
      prefs: prefs,
      connectivity: mockConnectivity,
    );
  });

  tearDown(() async {
    syncService.dispose();
    conflictResolver.dispose();
    mockConnectivity.dispose();
    await database.close();
  });

  group('SyncService', () {
    test('initializes with idle state', () async {
      // The service starts in idle state
      expect(syncService.currentStatus.state, equals(SyncState.idle));
    });

    test('updates status to syncing when syncAll is called', () async {
      final statusUpdates = <SyncStatus>[];
      final subscription = syncService.statusStream.listen(statusUpdates.add);

      // Don't await since the actual sync will fail (no real server)
      unawaited(syncService.syncAll().catchError((_) {}));

      // Give time for status to update
      await Future.delayed(const Duration(milliseconds: 100));

      expect(
        statusUpdates.any((s) => s.state == SyncState.syncing),
        isTrue,
      );

      await subscription.cancel();
    });

    test('handles offline state correctly', () async {
      // Set connectivity to offline before creating a new SyncService
      // that will check connectivity during initialize()
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Create a new mock connectivity that reports offline
      final offlineConnectivity = MockConnectivity();
      offlineConnectivity.setConnectivity([ConnectivityResult.none]);

      // Create a new sync service with the offline connectivity
      final offlineSyncService = SyncService(
        apiClient: ApiClient(
          config: ApiConfig.development(),
          tokenStorage: mockTokenStorage,
          authService: mockAuthService,
        ),
        config: ApiConfig.development(),
        database: database,
        queue: SyncQueue(prefs),
        conflictResolver: ConflictResolver(),
        prefs: prefs,
        connectivity: offlineConnectivity,
      );

      // Initialize the service - this will check connectivity and set offline state
      // Use unawaited since initialize() will try to sync and fail without a server
      unawaited(offlineSyncService.initialize().catchError((_) {}));

      // Give time for initialization to process connectivity check
      await Future.delayed(const Duration(milliseconds: 100));

      // Status should be offline because checkConnectivity returns none
      expect(offlineSyncService.currentStatus.state, equals(SyncState.offline));

      // Clean up
      offlineSyncService.dispose();
      offlineConnectivity.dispose();
    });

    test('notifyLocalChange increments pending count', () async {
      // Add an item to the queue
      await syncQueue.enqueue(
        SyncQueue.createEntryItem(
          id: 'queue-item-1',
          entityId: 'entry-1',
          operationType: SyncOperationType.create,
          payload: {'test': 'data'},
        ),
      );

      // Notify of local change
      syncService.notifyLocalChange();

      // Give time for debounce
      await Future.delayed(const Duration(milliseconds: 100));

      // Status should show pending changes
      expect(syncService.currentStatus.pendingCount, greaterThan(0));
    });

    test('getLastSyncTime returns null initially', () {
      expect(syncService.getLastSyncTime(), isNull);
    });
  });

  group('SyncQueue', () {
    test('enqueues and dequeues items correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queue = SyncQueue(prefs);

      final item = SyncQueue.createEntryItem(
        id: 'test-item-1',
        entityId: 'entry-1',
        operationType: SyncOperationType.create,
        payload: {'text': 'test'},
      );

      await queue.enqueue(item);

      expect(queue.pendingCount, equals(1));
      expect(queue.getNext()?.id, equals('test-item-1'));

      await queue.dequeue('test-item-1');

      expect(queue.pendingCount, equals(0));
      expect(queue.isEmpty, isTrue);
    });

    test('prioritizes items correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queue = SyncQueue(prefs);

      // Add items with different priorities
      await queue.enqueue(SyncQueue.createEntryItem(
        id: 'low-priority',
        entityId: 'entry-1',
        operationType: SyncOperationType.update,
      ));

      await queue.enqueue(SyncQueue.createTranscriptionItem(
        id: 'high-priority',
        entityId: 'entry-2',
        payload: {'audio': 'data'},
      ));

      // The transcription item should come first (higher priority)
      final next = queue.getNext();
      expect(next?.id, equals('high-priority'));
    });

    test('marks items as failed with error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queue = SyncQueue(prefs);

      final item = SyncQueue.createEntryItem(
        id: 'failing-item',
        entityId: 'entry-1',
        operationType: SyncOperationType.create,
      );

      await queue.enqueue(item);
      await queue.markFailed('failing-item', 'Network error');

      final failedItem = queue.getAll().first;
      expect(failedItem.attempts, equals(1));
      expect(failedItem.lastError, equals('Network error'));
    });

    test('replaces existing items for same entity', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final queue = SyncQueue(prefs);

      // Add first version
      await queue.enqueue(SyncQueue.createEntryItem(
        id: 'item-v1',
        entityId: 'entry-1',
        operationType: SyncOperationType.create,
        payload: {'version': 1},
      ));

      // Add second version for same entity
      await queue.enqueue(SyncQueue.createEntryItem(
        id: 'item-v2',
        entityId: 'entry-1',
        operationType: SyncOperationType.update,
        payload: {'version': 2},
      ));

      // Should only have one item
      expect(queue.pendingCount, equals(1));

      // Should have the newer version
      final item = queue.getNext();
      expect(item?.payload?['version'], equals(2));
    });

    test('persists queue across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Create first queue and add item
      final queue1 = SyncQueue(prefs);
      await queue1.enqueue(SyncQueue.createEntryItem(
        id: 'persistent-item',
        entityId: 'entry-1',
        operationType: SyncOperationType.create,
      ));

      // Create second queue (simulating app restart)
      final queue2 = SyncQueue(prefs);

      // Item should still be there
      expect(queue2.pendingCount, equals(1));
      expect(queue2.getNext()?.id, equals('persistent-item'));
    });
  });

  group('SyncStatus', () {
    test('creates initial status correctly', () {
      final status = SyncStatus.initial();

      expect(status.state, equals(SyncState.idle));
      expect(status.isSyncing, isFalse);
      expect(status.pendingCount, equals(0));
      expect(status.lastSyncTime, isNull);
      expect(status.errorMessage, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      final original = SyncStatus(
        state: SyncState.idle,
        pendingCount: 5,
        lastSyncTime: DateTime(2024, 1, 15),
      );

      final updated = original.copyWith(state: SyncState.syncing);

      expect(updated.state, equals(SyncState.syncing));
      expect(updated.pendingCount, equals(5));
      expect(updated.lastSyncTime, equals(DateTime(2024, 1, 15)));
    });
  });
}
