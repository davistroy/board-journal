import 'package:flutter/material.dart';

void main() {
  runApp(const BoardroomJournalApp());
}

class BoardroomJournalApp extends StatelessWidget {
  const BoardroomJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const Scaffold(
        body: Center(
          child: Text('Boardroom Journal'),
        ),
      ),
    );
  }
}
