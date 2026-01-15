import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/tables.dart';

part 'database.g.dart';

/// The main database for Boardroom Journal.
///
/// Contains all tables for:
/// - Daily entries and weekly briefs
/// - Problem portfolio and health tracking
/// - Board members and personas
/// - Governance sessions
/// - Bets and evidence tracking
/// - User preferences
@DriftDatabase(
  tables: [
    DailyEntries,
    WeeklyBriefs,
    Problems,
    PortfolioHealths,
    PortfolioVersions,
    BoardMembers,
    GovernanceSessions,
    Bets,
    EvidenceItems,
    ReSetupTriggers,
    UserPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Add migrations here as schema evolves.
        // Per PRD Section 3B.3: Sequential versioned migrations.
        // Migrations run sequentially (v1→v2→v3→v4).
      },
      beforeOpen: (details) async {
        // Enable foreign keys for SQLite.
        // Note: This works on both web (via sql.js) and native.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// Opens a connection to the database.
///
/// Uses drift_flutter which automatically handles platform detection:
/// - Web: Uses sql.js (SQLite compiled to WebAssembly) with IndexedDB persistence
/// - Mobile/Desktop: Uses native SQLite via sqlite3_flutter_libs
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'boardroom_journal',
    // Web-specific options for IndexedDB storage
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
