import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

/// Opens a connection to the SQLite database.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'boardroom_journal.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
