import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/providers.dart';
import '../../../router/router.dart';

/// Screen for viewing history of entries and reports.
///
/// Per PRD Section 5.10:
/// - Single reverse-chronological list
/// - Type indicators (journal entry vs governance report)
/// - Preview text
/// - Pull-to-refresh
/// - Pagination for performance
///
/// This is a scaffold - full implementation pending.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(dailyEntriesStreamProvider);
    final briefsAsync = ref.watch(weeklyBriefsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement refresh/sync
          ref.invalidate(dailyEntriesStreamProvider);
          ref.invalidate(weeklyBriefsStreamProvider);
        },
        child: entriesAsync.when(
          data: (entries) => briefsAsync.when(
            data: (briefs) {
              if (entries.isEmpty && briefs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No entries yet',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record your first entry to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.recordEntry),
                        icon: const Icon(Icons.mic),
                        label: const Text('Record Entry'),
                      ),
                    ],
                  ),
                );
              }

              // TODO: Combine and sort entries + briefs chronologically
              // For now, just show entries
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.article),
                    ),
                    title: Text(
                      entry.transcriptEdited?.substring(
                            0,
                            entry.transcriptEdited!.length > 50
                                ? 50
                                : entry.transcriptEdited!.length,
                          ) ??
                          'Entry ${entry.id.substring(0, 8)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _formatDate(entry.createdAtUtc),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/entry/${entry.id}'),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error loading briefs: $error'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Error loading entries: $error'),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
