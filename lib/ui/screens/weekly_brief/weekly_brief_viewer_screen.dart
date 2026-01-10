import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../../services/ai/ai.dart';

/// Screen for viewing and managing weekly briefs.
///
/// Per PRD Section 5.4:
/// - Executive brief (600-800 words)
/// - Board Micro-Review section (collapsible, remembers preference)
/// - Regeneration options (shorter/actionable/strategic)
/// - Export (Markdown/JSON)
/// - Edit mode
class WeeklyBriefViewerScreen extends ConsumerStatefulWidget {
  const WeeklyBriefViewerScreen({
    this.briefId,
    super.key,
  });

  /// Optional brief ID. If null, shows the latest brief.
  final String? briefId;

  @override
  ConsumerState<WeeklyBriefViewerScreen> createState() =>
      _WeeklyBriefViewerScreenState();
}

class _WeeklyBriefViewerScreenState
    extends ConsumerState<WeeklyBriefViewerScreen> {
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  late TextEditingController _editController;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get brief - either by ID or latest
    final briefAsync = widget.briefId != null
        ? ref.watch(watchBriefByIdProvider(widget.briefId!))
        : ref.watch(weeklyBriefsStreamProvider).whenData(
              (briefs) => briefs.isNotEmpty ? briefs.first : null,
            );

    return briefAsync.when(
      data: (brief) {
        if (brief == null) {
          return _buildNoBriefScreen(context);
        }
        return _buildBriefScreen(context, brief);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Weekly Brief')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Weekly Brief')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading brief: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoBriefScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Brief'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.summarize_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No Weekly Brief Yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Your first weekly brief will be generated after you create some journal entries.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => _generateBriefForCurrentWeek(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Brief'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBriefScreen(BuildContext context, WeeklyBrief brief) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Brief' : 'Weekly Brief'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _hasUnsavedChanges ? () => _saveEdits(brief) : null,
              child: const Text('Save'),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _startEditing(brief),
              tooltip: 'Edit Brief',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(value, brief),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_markdown',
                  child: ListTile(
                    leading: Icon(Icons.description),
                    title: Text('Copy as Markdown'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_json',
                  child: ListTile(
                    leading: Icon(Icons.code),
                    title: Text('Copy as JSON'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _isEditing
          ? _buildEditMode(brief)
          : _buildViewMode(context, brief, colorScheme),
      floatingActionButton: _isEditing
          ? null
          : FloatingActionButton.extended(
              onPressed:
                  _isRegenerating ? null : () => _showRegenerateDialog(brief),
              icon: _isRegenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isRegenerating ? 'Generating...' : 'Regenerate'),
            ),
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    WeeklyBrief brief,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week range header
          _buildWeekHeader(brief, colorScheme),
          const SizedBox(height: 16),

          // Regeneration counter
          _buildRegenCounter(brief, colorScheme),
          const SizedBox(height: 16),

          // Brief content
          _buildBriefContent(brief),

          // Board micro-review section (collapsible)
          if (brief.boardMicroReviewMarkdown != null) ...[
            const SizedBox(height: 24),
            _buildMicroReviewSection(brief, colorScheme),
          ],

          // Entry count footer
          const SizedBox(height: 24),
          _buildEntryCountFooter(brief, colorScheme),

          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildWeekHeader(WeeklyBrief brief, ColorScheme colorScheme) {
    final weekRange = _formatWeekRange(brief.weekStartUtc, brief.weekEndUtc);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            weekRange,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegenCounter(WeeklyBrief brief, ColorScheme colorScheme) {
    final remaining = WeeklyBriefRepository.maxRegenerations - brief.regenCount;
    final isAtLimit = remaining <= 0;

    return Row(
      children: [
        Icon(
          isAtLimit ? Icons.block : Icons.autorenew,
          size: 16,
          color: isAtLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          isAtLimit
              ? 'Regeneration limit reached (can still edit)'
              : 'Regenerations: $remaining of ${WeeklyBriefRepository.maxRegenerations} remaining',
          style: TextStyle(
            fontSize: 12,
            color:
                isAtLimit ? colorScheme.error : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBriefContent(WeeklyBrief brief) {
    return SelectableText(
      brief.briefMarkdown,
      style: const TextStyle(
        fontSize: 15,
        height: 1.6,
      ),
    );
  }

  Widget _buildMicroReviewSection(WeeklyBrief brief, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ExpansionTile(
        initiallyExpanded: !brief.microReviewCollapsed,
        onExpansionChanged: (expanded) => _updateMicroReviewCollapsed(
          brief.id,
          !expanded,
        ),
        leading: Icon(Icons.groups, color: colorScheme.secondary),
        title: const Text(
          'Board Micro-Review',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Quick commentary from your AI board',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              brief.boardMicroReviewMarkdown!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCountFooter(WeeklyBrief brief, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.article_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Based on ${brief.entryCount} ${brief.entryCount == 1 ? 'entry' : 'entries'}',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.access_time,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          'Generated ${_formatTimestamp(brief.generatedAtUtc)}',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(WeeklyBrief brief) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _editController,
        maxLines: null,
        expands: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Edit your brief...',
        ),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          fontFamily: 'monospace',
        ),
        onChanged: (value) {
          if (!_hasUnsavedChanges) {
            setState(() => _hasUnsavedChanges = true);
          }
        },
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (_isEditing && _hasUnsavedChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
            'You have unsaved changes. Do you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isEditing = false;
                  _hasUnsavedChanges = false;
                });
                context.go(AppRoutes.home);
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _startEditing(WeeklyBrief brief) {
    _editController.text = brief.briefMarkdown;
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveEdits(WeeklyBrief brief) async {
    final repo = ref.read(weeklyBriefRepositoryProvider);
    await repo.updateBrief(brief.id, _editController.text);

    if (mounted) {
      setState(() {
        _isEditing = false;
        _hasUnsavedChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brief saved')),
      );
    }
  }

  void _handleMenuAction(String action, WeeklyBrief brief) {
    switch (action) {
      case 'export_markdown':
        _exportMarkdown(brief);
        break;
      case 'export_json':
        _exportJson(brief);
        break;
    }
  }

  void _exportMarkdown(WeeklyBrief brief) {
    final content = StringBuffer();
    content.writeln(brief.briefMarkdown);
    if (brief.boardMicroReviewMarkdown != null) {
      content.writeln();
      content.writeln('---');
      content.writeln();
      content.writeln('## Board Micro-Review');
      content.writeln();
      content.writeln(brief.boardMicroReviewMarkdown);
    }
    content.writeln();
    content.writeln('---');
    content.writeln('*Generated: ${_formatTimestamp(brief.generatedAtUtc)}*');
    content.writeln('*Entries: ${brief.entryCount}*');

    Clipboard.setData(ClipboardData(text: content.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markdown copied to clipboard')),
    );
  }

  void _exportJson(WeeklyBrief brief) {
    final json = {
      'id': brief.id,
      'weekStart': brief.weekStartUtc.toIso8601String(),
      'weekEnd': brief.weekEndUtc.toIso8601String(),
      'timezone': brief.weekTimezone,
      'briefMarkdown': brief.briefMarkdown,
      'boardMicroReview': brief.boardMicroReviewMarkdown,
      'entryCount': brief.entryCount,
      'regenerationCount': brief.regenCount,
      'generatedAt': brief.generatedAtUtc.toIso8601String(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    Clipboard.setData(ClipboardData(text: encoder.convert(json)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON copied to clipboard')),
    );
  }

  Future<void> _updateMicroReviewCollapsed(String id, bool collapsed) async {
    final repo = ref.read(weeklyBriefRepositoryProvider);
    await repo.setMicroReviewCollapsed(id, collapsed);
  }

  Future<void> _showRegenerateDialog(WeeklyBrief brief) async {
    final remaining =
        WeeklyBriefRepository.maxRegenerations - brief.regenCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Regeneration limit reached. You can still edit the brief directly.',
          ),
        ),
      );
      return;
    }

    var options = const BriefRegenerationOptions();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Regenerate Brief'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$remaining regeneration${remaining == 1 ? '' : 's'} remaining',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Options (select any combination):',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Shorter'),
                subtitle: const Text('~40% reduction, fewer bullets'),
                value: options.shorter,
                onChanged: (value) {
                  setDialogState(() {
                    options = BriefRegenerationOptions(
                      shorter: value ?? false,
                      moreActionable: options.moreActionable,
                      moreStrategic: options.moreStrategic,
                    );
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('More Actionable'),
                subtitle: const Text('Every bullet has a next step'),
                value: options.moreActionable,
                onChanged: (value) {
                  setDialogState(() {
                    options = BriefRegenerationOptions(
                      shorter: options.shorter,
                      moreActionable: value ?? false,
                      moreStrategic: options.moreStrategic,
                    );
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('More Strategic'),
                subtitle: const Text('Career trajectory framing'),
                value: options.moreStrategic,
                onChanged: (value) {
                  setDialogState(() {
                    options = BriefRegenerationOptions(
                      shorter: options.shorter,
                      moreActionable: options.moreActionable,
                      moreStrategic: value ?? false,
                    );
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _regenerateBrief(brief, options);
    }
  }

  Future<void> _regenerateBrief(
    WeeklyBrief brief,
    BriefRegenerationOptions options,
  ) async {
    setState(() => _isRegenerating = true);

    try {
      final service = ref.read(weeklyBriefGenerationServiceProvider);
      if (service == null) {
        throw Exception('AI service not configured');
      }

      final entryRepo = ref.read(dailyEntryRepositoryProvider);
      final briefRepo = ref.read(weeklyBriefRepositoryProvider);

      // Get entries for the brief's week
      final entries = await entryRepo.getEntriesForWeek(brief.weekStartUtc);

      // Generate new brief
      final generated = await service.generateBrief(
        entries: entries,
        weekStart: brief.weekStartUtc,
        weekEnd: brief.weekEndUtc,
        options: options,
      );

      // Update brief in database
      await briefRepo.updateBrief(brief.id, generated.briefMarkdown);
      if (generated.boardMicroReviewMarkdown != null) {
        await briefRepo.updateMicroReview(
          brief.id,
          generated.boardMicroReviewMarkdown!,
        );
      }

      // Increment regen count
      await briefRepo.incrementRegenCount(
        brief.id,
        regenOptionsJson: options.toJsonString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brief regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _generateBriefForCurrentWeek(BuildContext context) async {
    setState(() => _isRegenerating = true);

    try {
      final service = ref.read(weeklyBriefGenerationServiceProvider);
      if (service == null) {
        throw Exception(
          'AI service not configured. Please set ANTHROPIC_API_KEY.',
        );
      }

      final entryRepo = ref.read(dailyEntryRepositoryProvider);
      final briefRepo = ref.read(weeklyBriefRepositoryProvider);

      // Get current week's date range
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      // Get entries for current week
      final entries = await entryRepo.getEntriesForWeek(now);

      // Generate brief
      final generated = await service.generateBrief(
        entries: entries,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      // Save to database
      await briefRepo.create(
        weekStartUtc: weekStart,
        weekEndUtc: weekEnd,
        weekTimezone: now.timeZoneName,
        briefMarkdown: generated.briefMarkdown,
        boardMicroReviewMarkdown: generated.boardMicroReviewMarkdown,
        entryCount: generated.entryCount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brief generated!')),
        );
        // Refresh the providers
        ref.invalidate(weeklyBriefsStreamProvider);
        ref.invalidate(latestBriefProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate brief: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the current week
    final weekday = date.weekday;
    return DateTime.utc(
      date.year,
      date.month,
      date.day - (weekday - 1),
    );
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  String _formatTimestamp(DateTime timestamp) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final local = timestamp.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${months[local.month - 1]} ${local.day} at $hour12:$minute $period';
  }
}
