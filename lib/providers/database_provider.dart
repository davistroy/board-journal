import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart';

/// Provider for the main database instance.
///
/// This is a singleton that should be initialized once at app startup.
/// All repositories depend on this provider.
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(() {
    database.close();
  });

  return database;
});
