import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for viewing and managing weekly briefs.
///
/// Per PRD Section 5.4:
/// - Executive brief (600-800 words)
/// - Board Micro-Review section (collapsible)
/// - Regeneration options (shorter/actionable/strategic)
/// - Export (Markdown/JSON)
///
/// This is a scaffold - full implementation pending.
class WeeklyBriefViewerScreen extends ConsumerWidget {
  const WeeklyBriefViewerScreen({
    this.briefId,
    super.key,
  });

  /// Optional brief ID. If null, shows the latest brief.
  final String? briefId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Brief'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value coming soon')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Export Markdown',
                child: ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Export Markdown'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'Export JSON',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Export JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.summarize_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Weekly Brief Viewer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (briefId != null)
              Text(
                'Brief ID: $briefId',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              Text(
                'Latest Brief',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            const SizedBox(height: 24),
            const Text('Full implementation pending'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement regeneration
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Regenerate coming soon')),
          );
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Regenerate'),
      ),
    );
  }
}
