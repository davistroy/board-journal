import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/data.dart';
import '../../../../providers/providers.dart';
import '../../../../services/services.dart';

/// View for evaluating the last bet (Q1).
class BetEvaluationView extends ConsumerStatefulWidget {
  final VoidCallback onEvaluated;
  final VoidCallback onSkipped;

  const BetEvaluationView({
    super.key,
    required this.onEvaluated,
    required this.onSkipped,
  });

  @override
  ConsumerState<BetEvaluationView> createState() => _BetEvaluationViewState();
}

class _BetEvaluationViewState extends ConsumerState<BetEvaluationView> {
  BetStatus? _selectedStatus;
  final _rationaleController = TextEditingController();
  final List<QuarterlyEvidence> _evidence = [];

  @override
  void dispose() {
    _rationaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastBetAsync = ref.watch(lastOpenBetProvider);
    final sessionState = ref.watch(quarterlySessionProvider);

    return lastBetAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, error.toString()),
      data: (bet) {
        if (bet == null) {
          return _buildNoBet(context, sessionState);
        }
        return _buildBetEvaluation(context, bet, sessionState);
      },
    );
  }

  Widget _buildNoBet(BuildContext context, QuarterlySessionState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.casino_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'No Active Bet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'You do not have an active bet to evaluate. This is your first quarterly report '
            'or your previous bet has already been evaluated.',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      ref
                          .read(quarterlySessionProvider.notifier)
                          .skipBetEvaluation();
                    },
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetEvaluation(
      BuildContext context, Bet bet, QuarterlySessionState state) {
    // Check if bet is expired
    final isExpired = bet.dueAtUtc.isBefore(DateTime.now().toUtc());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evaluate Your Bet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prediction',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bet.prediction,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Wrong If',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(bet.wrongIf),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isExpired ? Icons.timer_off : Icons.timer,
                        size: 16,
                        color: isExpired
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'Due date passed: ${_formatDate(bet.dueAtUtc)}'
                            : 'Due: ${_formatDate(bet.dueAtUtc)}',
                        style: TextStyle(
                          color: isExpired
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'What was the outcome?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            context,
            status: BetStatus.correct,
            icon: Icons.check_circle,
            label: 'Correct',
            description: 'Your prediction came true',
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          _buildStatusOption(
            context,
            status: BetStatus.wrong,
            icon: Icons.cancel,
            label: 'Wrong',
            description: 'Your prediction was incorrect',
            color: Colors.red,
          ),
          if (isExpired) ...[
            const SizedBox(height: 8),
            _buildStatusOption(
              context,
              status: BetStatus.expired,
              icon: Icons.hourglass_disabled,
              label: 'Expired',
              description: 'Due date passed without clear outcome',
              color: Colors.orange,
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _rationaleController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Rationale (optional)',
              hintText: 'Why did you evaluate it this way?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          _buildEvidenceSection(context),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedStatus == null || state.isProcessing
                  ? null
                  : () => _submitEvaluation(bet.id),
              child: state.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Evaluation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required BetStatus status,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
  }) {
    final isSelected = _selectedStatus == status;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Evidence (Receipts)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: () => _showAddEvidenceDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (_evidence.isEmpty)
          const Text(
            'No evidence added. Evidence strengthens your evaluation.',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...List.generate(_evidence.length, (index) {
            final item = _evidence[index];
            return Card(
              child: ListTile(
                leading: _getEvidenceIcon(item.type),
                title: Text(item.description),
                subtitle: Text(
                  '${item.type.displayName} - ${item.strength.displayName}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _evidence.removeAt(index);
                    });
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _getEvidenceIcon(EvidenceType type) {
    IconData icon;
    Color color;

    switch (type) {
      case EvidenceType.decision:
        icon = Icons.gavel;
        color = Colors.green;
        break;
      case EvidenceType.artifact:
        icon = Icons.description;
        color = Colors.green;
        break;
      case EvidenceType.calendar:
        icon = Icons.calendar_today;
        color = Colors.orange;
        break;
      case EvidenceType.proxy:
        icon = Icons.person_outline;
        color = Colors.orange;
        break;
      case EvidenceType.none:
        icon = Icons.help_outline;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color);
  }

  void _showAddEvidenceDialog(BuildContext context) {
    EvidenceType? selectedType;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Evidence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evidence Type'),
              const SizedBox(height: 8),
              DropdownButton<EvidenceType>(
                isExpanded: true,
                value: selectedType,
                hint: const Text('Select type'),
                items: EvidenceType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        ))
                    .toList(),
                onChanged: (type) {
                  setDialogState(() {
                    selectedType = type;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the evidence...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (selectedType != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Strength: ${selectedType!.defaultStrength.displayName}',
                  style: TextStyle(
                    color: _getStrengthColor(selectedType!.defaultStrength),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedType == null ||
                      descriptionController.text.trim().isEmpty
                  ? null
                  : () {
                      setState(() {
                        _evidence.add(QuarterlyEvidence(
                          description: descriptionController.text.trim(),
                          type: selectedType!,
                          strength: selectedType!.defaultStrength,
                        ));
                      });
                      Navigator.of(context).pop();
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStrengthColor(EvidenceStrength strength) {
    switch (strength) {
      case EvidenceStrength.strong:
        return Colors.green;
      case EvidenceStrength.medium:
        return Colors.orange;
      case EvidenceStrength.weak:
        return Colors.red;
      case EvidenceStrength.none:
        return Colors.grey;
    }
  }

  void _submitEvaluation(String betId) {
    ref.read(quarterlySessionProvider.notifier).evaluateBet(
          betId: betId,
          status: _selectedStatus!,
          rationale: _rationaleController.text.trim().isNotEmpty
              ? _rationaleController.text.trim()
              : null,
          evidence: _evidence.isNotEmpty ? _evidence : null,
        );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text('Error loading bet: $error'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
