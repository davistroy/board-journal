import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';
import '../../../../services/services.dart';

/// View for re-setup trigger status check (Q9).
class TriggerCheckView extends ConsumerStatefulWidget {
  final List<TriggerStatus> triggerStatuses;
  final bool anyMet;
  final VoidCallback onContinue;

  const TriggerCheckView({
    super.key,
    required this.triggerStatuses,
    required this.anyMet,
    required this.onContinue,
  });

  @override
  ConsumerState<TriggerCheckView> createState() => _TriggerCheckViewState();
}

class _TriggerCheckViewState extends ConsumerState<TriggerCheckView> {
  @override
  void initState() {
    super.initState();
    // Auto-check triggers on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.triggerStatuses.isEmpty) {
        ref.read(quarterlySessionProvider.notifier).checkTriggerStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quarterlySessionProvider);

    if (state.isProcessing && widget.triggerStatuses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking re-setup triggers...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Re-Setup Trigger Check',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Checking if any conditions suggest you should re-evaluate your portfolio setup.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (widget.anyMet)
            _buildWarningBanner(context)
          else
            _buildAllClearBanner(context),
          const SizedBox(height: 24),
          _buildTriggerList(context),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      // Continue to next step
                    },
              child: Text(widget.anyMet ? 'Acknowledge & Continue' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    final metCount = widget.triggerStatuses.where((t) => t.isMet).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$metCount Trigger${metCount > 1 ? 's' : ''} Met',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consider running Setup again to refresh your portfolio and board.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 32,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Clear',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No re-setup triggers are met. Your portfolio remains valid.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerList(BuildContext context) {
    if (widget.triggerStatuses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No triggers configured. This may indicate Setup was not fully completed.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trigger Status',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...widget.triggerStatuses.map((trigger) => _buildTriggerCard(
              context,
              trigger,
            )),
      ],
    );
  }

  Widget _buildTriggerCard(BuildContext context, TriggerStatus trigger) {
    final isMet = trigger.isMet;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMet
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            isMet ? Icons.warning : Icons.check,
            color: isMet
                ? Theme.of(context).colorScheme.onError
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          trigger.description,
          style: TextStyle(
            fontWeight: isMet ? FontWeight.bold : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMet
                        ? Theme.of(context).colorScheme.error
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMet ? 'MET' : 'Not Met',
                    style: TextStyle(
                      color: isMet
                          ? Theme.of(context).colorScheme.onError
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getTriggerTypeLabel(trigger.triggerType),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (trigger.details != null) ...[
              const SizedBox(height: 4),
              Text(
                trigger.details!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTriggerTypeLabel(String triggerType) {
    switch (triggerType.toLowerCase()) {
      case 'annual':
        return 'Annual Review';
      case 'role_change':
        return 'Role Change';
      case 'problem_obsolete':
        return 'Problem Obsolete';
      case 'market_shift':
        return 'Market Shift';
      case 'direction_shift':
        return 'Direction Shift';
      default:
        return triggerType;
    }
  }
}
