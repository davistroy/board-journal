import 'package:flutter/material.dart';

import '../../data/enums/signal_type.dart';
import '../../services/ai/models/extracted_signal.dart';

/// Widget for displaying extracted signals from a journal entry.
///
/// Groups signals by type and displays them in expandable sections.
class SignalListWidget extends StatelessWidget {
  /// The extracted signals to display.
  final ExtractedSignals signals;

  /// Whether re-extraction is in progress.
  final bool isExtracting;

  /// Callback when re-extract is requested.
  final VoidCallback? onReExtract;

  const SignalListWidget({
    super.key,
    required this.signals,
    this.isExtracting = false,
    this.onReExtract,
  });

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty && !isExtracting) {
      return _EmptySignalsView(onReExtract: onReExtract);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count and re-extract button
        Row(
          children: [
            Text(
              'Extracted Signals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${signals.totalCount}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
            const Spacer(),
            if (onReExtract != null)
              TextButton.icon(
                onPressed: isExtracting ? null : onReExtract,
                icon: isExtracting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(isExtracting ? 'Extracting...' : 'Re-extract'),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Signal groups
        if (isExtracting)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Extracting signals...'),
                ],
              ),
            ),
          )
        else
          ...SignalType.values.map((type) {
            final typeSignals = signals.byType(type);
            if (typeSignals.isEmpty) return const SizedBox.shrink();
            return _SignalTypeSection(
              type: type,
              signals: typeSignals,
            );
          }),
      ],
    );
  }
}

/// Empty state when no signals are extracted.
class _EmptySignalsView extends StatelessWidget {
  final VoidCallback? onReExtract;

  const _EmptySignalsView({this.onReExtract});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extracted Signals',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No signals extracted yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Signals help identify wins, blockers, risks, avoided decisions, '
                'comfort work, actions, and learnings from your entry.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (onReExtract != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: onReExtract,
                  child: const Text('Extract Signals'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Section for a single signal type.
class _SignalTypeSection extends StatelessWidget {
  final SignalType type;
  final List<ExtractedSignal> signals;

  const _SignalTypeSection({
    required this.type,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type header
            Row(
              children: [
                Icon(
                  _getIcon(),
                  size: 18,
                  color: _getIconColor(context),
                ),
                const SizedBox(width: 8),
                Text(
                  type.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: _getIconColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _getIconColor(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${signals.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _getIconColor(context),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Signal items
            ...signals.map((signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Expanded(
                        child: Text(
                          signal.text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case SignalType.wins:
        return Icons.emoji_events_outlined;
      case SignalType.blockers:
        return Icons.block_outlined;
      case SignalType.risks:
        return Icons.warning_amber_outlined;
      case SignalType.avoidedDecision:
        return Icons.hourglass_empty_outlined;
      case SignalType.comfortWork:
        return Icons.beach_access_outlined;
      case SignalType.actions:
        return Icons.task_alt_outlined;
      case SignalType.learnings:
        return Icons.lightbulb_outline;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case SignalType.wins:
        return Colors.green.shade700;
      case SignalType.blockers:
        return colorScheme.error;
      case SignalType.risks:
        return Colors.orange.shade700;
      case SignalType.avoidedDecision:
        return Colors.amber.shade800;
      case SignalType.comfortWork:
        return Colors.purple.shade600;
      case SignalType.actions:
        return colorScheme.primary;
      case SignalType.learnings:
        return Colors.teal.shade600;
    }
  }

  Color _getBorderColor(BuildContext context) {
    return _getIconColor(context).withOpacity(0.3);
  }
}

/// Compact signal summary for list views.
class SignalSummaryChip extends StatelessWidget {
  final SignalType type;
  final int count;

  const SignalSummaryChip({
    super.key,
    required this.type,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 12,
            color: _getColor(context),
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _getColor(context),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case SignalType.wins:
        return Icons.emoji_events_outlined;
      case SignalType.blockers:
        return Icons.block_outlined;
      case SignalType.risks:
        return Icons.warning_amber_outlined;
      case SignalType.avoidedDecision:
        return Icons.hourglass_empty_outlined;
      case SignalType.comfortWork:
        return Icons.beach_access_outlined;
      case SignalType.actions:
        return Icons.task_alt_outlined;
      case SignalType.learnings:
        return Icons.lightbulb_outline;
    }
  }

  Color _getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case SignalType.wins:
        return Colors.green.shade700;
      case SignalType.blockers:
        return colorScheme.error;
      case SignalType.risks:
        return Colors.orange.shade700;
      case SignalType.avoidedDecision:
        return Colors.amber.shade800;
      case SignalType.comfortWork:
        return Colors.purple.shade600;
      case SignalType.actions:
        return colorScheme.primary;
      case SignalType.learnings:
        return Colors.teal.shade600;
    }
  }
}
