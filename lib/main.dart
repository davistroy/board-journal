import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BoardroomJournalApp(),
    ),
  );
}

class BoardroomJournalApp extends StatelessWidget {
  const BoardroomJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();

    return MaterialApp.router(
      title: 'Boardroom Journal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, // Follow system setting per PRD
      routerConfig: router,
    );
  }
}
