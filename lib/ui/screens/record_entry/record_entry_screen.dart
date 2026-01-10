import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for recording or typing a new journal entry.
///
/// Provides two entry modes per PRD Section 5.2:
/// - Voice recording with transcription
/// - Text entry as first-class alternative
///
/// This is a scaffold - full implementation pending.
class RecordEntryScreen extends StatelessWidget {
  const RecordEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Voice recording button (placeholder)
              FilledButton.icon(
                onPressed: () {
                  // TODO: Implement voice recording
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice recording coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.mic),
                label: const Text('Record Voice'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                ),
              ),
              const SizedBox(height: 16),
              // Text entry button (placeholder)
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement text entry flow
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Text entry coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Type Instead'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 56),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Just talk about your day.\nWe\'ll extract the important signals.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
