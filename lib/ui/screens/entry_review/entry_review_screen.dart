import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for reviewing and editing a journal entry.
///
/// Per PRD Section 5.3:
/// - Transcript editable
/// - Detected signals preview (7 types)
/// - Quick fix option for extracted bullets
///
/// This is a scaffold - full implementation pending.
class EntryReviewScreen extends ConsumerWidget {
  const EntryReviewScreen({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // TODO: Implement delete with confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete coming soon')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Entry Review',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Entry ID: $entryId',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            const Text('Full implementation pending'),
          ],
        ),
      ),
    );
  }
}
