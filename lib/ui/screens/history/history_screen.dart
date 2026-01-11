import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/export_format.dart';
import '../../../providers/history_providers.dart';
import '../../../router/router.dart';

/// Screen for viewing history of entries and reports.
///
/// Per PRD Section 5.10:
/// - Single reverse-chronological list
/// - Type indicators (journal entry vs governance report)
/// - Preview text
/// - Pull-to-refresh
/// - Pagination for performance
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near the bottom
      final notifier = ref.read(historyNotifierProvider.notifier);
      if (notifier.hasMore) {
        notifier.loadMore();
      }
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(historyNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyNotifierProvider);
    final notifier = ref.read(historyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Data',
            onPressed: () => _showExportDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: historyAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: items.length + (notifier.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  // Loading indicator for pagination
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final item = items[index];
                return _HistoryItemTile(
                  item: item,
                  onTap: () => _navigateToItem(context, item),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading history',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _onRefresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
      ),
    );
  }

  void _navigateToItem(BuildContext context, HistoryItem item) {
    switch (item.type) {
      case HistoryItemType.dailyEntry:
        context.go('/entry/${item.id}');
        break;
      case HistoryItemType.weeklyBrief:
        context.go('/weekly-brief/${item.id}');
        break;
      case HistoryItemType.governanceSession:
        // TODO: Navigate to governance session detail view
        // For now, show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Governance session detail view coming soon'),
          ),
        );
        break;
    }
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ExportDialog(),
    );
  }
}

/// Tile widget for displaying a history item.
class _HistoryItemTile extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;

  const _HistoryItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getIconBackgroundColor(context),
        child: Icon(
          _getIcon(),
          color: _getIconColor(context),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.preview != null)
            Text(
              item.preview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              _TypeChip(type: item.type),
              const SizedBox(width: 8),
              Text(
                _formatTime(item.date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  IconData _getIcon() {
    switch (item.type) {
      case HistoryItemType.dailyEntry:
        return Icons.calendar_today;
      case HistoryItemType.weeklyBrief:
        return Icons.description;
      case HistoryItemType.governanceSession:
        return Icons.gavel;
    }
  }

  Color _getIconBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (item.type) {
      case HistoryItemType.dailyEntry:
        return colorScheme.primaryContainer;
      case HistoryItemType.weeklyBrief:
        return colorScheme.secondaryContainer;
      case HistoryItemType.governanceSession:
        return colorScheme.tertiaryContainer;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (item.type) {
      case HistoryItemType.dailyEntry:
        return colorScheme.onPrimaryContainer;
      case HistoryItemType.weeklyBrief:
        return colorScheme.onSecondaryContainer;
      case HistoryItemType.governanceSession:
        return colorScheme.onTertiaryContainer;
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Small chip showing the type of history item.
class _TypeChip extends StatelessWidget {
  final HistoryItemType type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _getTextColor(context),
            ),
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case HistoryItemType.dailyEntry:
        return colorScheme.primaryContainer.withOpacity(0.5);
      case HistoryItemType.weeklyBrief:
        return colorScheme.secondaryContainer.withOpacity(0.5);
      case HistoryItemType.governanceSession:
        return colorScheme.tertiaryContainer.withOpacity(0.5);
    }
  }

  Color _getTextColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case HistoryItemType.dailyEntry:
        return colorScheme.onPrimaryContainer;
      case HistoryItemType.weeklyBrief:
        return colorScheme.onSecondaryContainer;
      case HistoryItemType.governanceSession:
        return colorScheme.onTertiaryContainer;
    }
  }
}

/// Dialog for exporting data.
class _ExportDialog extends ConsumerStatefulWidget {
  const _ExportDialog();

  @override
  ConsumerState<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<_ExportDialog> {
  String _selectedFormat = 'json';
  bool _isExporting = false;
  String? _exportedPath;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(exportPreviewProvider);

    return AlertDialog(
      title: const Text('Export Data'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Export summary
            previewAsync.when(
              data: (summary) => _buildSummary(context, summary),
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Format selection
            Text(
              'Export Format',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('JSON'),
              subtitle: const Text('Machine-readable, can be imported later'),
              value: 'json',
              groupValue: _selectedFormat,
              onChanged: _isExporting
                  ? null
                  : (value) => setState(() => _selectedFormat = value!),
            ),
            RadioListTile<String>(
              title: const Text('Markdown'),
              subtitle: const Text('Human-readable document'),
              value: 'markdown',
              groupValue: _selectedFormat,
              onChanged: _isExporting
                  ? null
                  : (value) => setState(() => _selectedFormat = value!),
            ),

            // Status messages
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_exportedPath != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 8),
                    const Text('Export successful!'),
                    const SizedBox(height: 4),
                    Text(
                      _exportedPath!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isExporting || _exportedPath != null ? null : _export,
          child: Text(_exportedPath != null ? 'Done' : 'Export'),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, ExportSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data to Export',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('Daily Entries: ${summary.dailyEntriesCount}'),
        Text('Weekly Briefs: ${summary.weeklyBriefsCount}'),
        Text('Problems: ${summary.problemsCount}'),
        Text('Board Members: ${summary.boardMembersCount}'),
        Text('Governance Sessions: ${summary.governanceSessionsCount}'),
        Text('Bets: ${summary.betsCount}'),
        const SizedBox(height: 8),
        Text(
          'Total: ${summary.totalCount} items',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _error = null;
    });

    try {
      final exportService = ref.read(exportServiceProvider);

      String content;
      if (_selectedFormat == 'json') {
        content = await exportService.exportToJson();
      } else {
        content = await exportService.exportToMarkdown();
      }

      final path = await exportService.saveExportFile(content, _selectedFormat);

      setState(() {
        _exportedPath = path;
        _isExporting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Export failed: $e';
        _isExporting = false;
      });
    }
  }
}
