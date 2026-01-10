import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../../services/ai/ai.dart';
import '../../widgets/widgets.dart';

/// Provider for fetching a single entry by ID.
final entryByIdProvider =
    FutureProvider.family<DailyEntry?, String>((ref, entryId) async {
  final repo = ref.watch(dailyEntryRepositoryProvider);
  return repo.getById(entryId);
});

/// Screen for reviewing and editing a journal entry.
///
/// Per PRD Section 5.3:
/// - Transcript editable
/// - Detected signals preview (7 types)
/// - Quick fix option for extracted bullets
class EntryReviewScreen extends ConsumerStatefulWidget {
  const EntryReviewScreen({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  ConsumerState<EntryReviewScreen> createState() => _EntryReviewScreenState();
}

class _EntryReviewScreenState extends ConsumerState<EntryReviewScreen> {
  final _textController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(dailyEntryRepositoryProvider);
      await repo.updateTranscript(widget.entryId, _textController.text);

      // Refresh the entry
      ref.invalidate(entryByIdProvider(widget.entryId));
      ref.invalidate(dailyEntriesStreamProvider);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _hasChanges = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
          'This entry will be moved to trash and permanently deleted after 30 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(dailyEntryRepositoryProvider);
        await repo.softDelete(widget.entryId);
        ref.invalidate(dailyEntriesStreamProvider);

        if (mounted) {
          context.go(AppRoutes.home);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<bool> _handleBackPress() async {
    if (_hasChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('Do you want to save your changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (result == 'save') {
        await _saveChanges();
        return true;
      } else if (result == 'discard') {
        return true;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryByIdProvider(widget.entryId));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Entry' : 'Review Entry'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && context.mounted) {
                context.go(AppRoutes.home);
              }
            },
          ),
          actions: [
            if (_isEditing)
              TextButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () {
                  final entry = entryAsync.valueOrNull;
                  if (entry != null) {
                    _textController.text = entry.transcriptEdited;
                    setState(() => _isEditing = true);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: _deleteEntry,
              ),
            ],
          ],
        ),
        body: entryAsync.when(
          data: (entry) {
            if (entry == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Entry not found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              );
            }

            return _isEditing
                ? _EditView(
                    controller: _textController,
                    onChanged: () {
                      if (!_hasChanges) {
                        setState(() => _hasChanges = true);
                      }
                    },
                  )
                : _ReadView(entry: entry);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      ref.refresh(entryByIdProvider(widget.entryId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider for re-extraction state for a specific entry.
final reExtractionProvider =
    StateProvider.family.autoDispose<bool, String>((ref, entryId) => false);

/// Read-only view of the entry.
class _ReadView extends ConsumerWidget {
  const _ReadView({required this.entry});

  final DailyEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExtracting = ref.watch(reExtractionProvider(entry.id));
    final signals = _parseSignals(entry.extractedSignalsJson);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata
          Row(
            children: [
              Icon(
                entry.entryType == 'voice' ? Icons.mic : Icons.edit,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                entry.entryType == 'voice' ? 'Voice entry' : 'Text entry',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(entry.createdAtUtc),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.notes,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${entry.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (entry.durationSeconds != null) ...[
                const SizedBox(width: 16),
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(entry.durationSeconds!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Transcript
          Text(
            'Transcript',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: SelectableText(
              entry.transcriptEdited,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),

          const SizedBox(height: 24),

          // Extracted Signals
          SignalListWidget(
            signals: signals,
            isExtracting: isExtracting,
            onReExtract: () => _handleReExtract(ref, context),
          ),
        ],
      ),
    );
  }

  ExtractedSignals _parseSignals(String signalsJson) {
    try {
      if (signalsJson.isEmpty || signalsJson == '{}') {
        return const ExtractedSignals([]);
      }
      final json = jsonDecode(signalsJson) as Map<String, dynamic>;
      return ExtractedSignals.fromJson(json);
    } catch (_) {
      return const ExtractedSignals([]);
    }
  }

  Future<void> _handleReExtract(WidgetRef ref, BuildContext context) async {
    final service = ref.read(signalExtractionServiceProvider);

    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI service not configured. Please set ANTHROPIC_API_KEY.'),
        ),
      );
      return;
    }

    ref.read(reExtractionProvider(entry.id).notifier).state = true;

    try {
      final signals = await service.extractSignals(entry.transcriptEdited);

      if (signals.isNotEmpty) {
        final repo = ref.read(dailyEntryRepositoryProvider);
        final signalsJson = jsonEncode(signals.toJson());
        await repo.updateExtractedSignals(entry.id, signalsJson);

        // Refresh the entry
        ref.invalidate(entryByIdProvider(entry.id));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted ${signals.totalCount} signals'),
          ),
        );
      }
    } on SignalExtractionError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Extraction failed: ${e.message}')),
        );
      }
    } finally {
      ref.read(reExtractionProvider(entry.id).notifier).state = false;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    String dayPart;
    if (entryDate == today) {
      dayPart = 'Today';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      dayPart = 'Yesterday';
    } else {
      dayPart = '${date.month}/${date.day}/${date.year}';
    }

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';

    return '$dayPart at $hour:$minute $period';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }
}

/// Edit view for modifying the transcript.
class _EditView extends StatelessWidget {
  const _EditView({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Word count bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final wordCount = value.text.trim().isEmpty
                      ? 0
                      : value.text.trim().split(RegExp(r'\s+')).length;
                  return Text(
                    '$wordCount words',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  );
                },
              ),
            ],
          ),
        ),

        // Text editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Edit your entry...',
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}
