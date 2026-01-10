import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/data.dart';
import '../../../../providers/providers.dart';
import '../../../../services/services.dart';

/// View for commitments vs actuals review (Q2).
class CommitmentsView extends ConsumerStatefulWidget {
  final bool isClarify;
  final bool canSkip;

  const CommitmentsView({
    super.key,
    this.isClarify = false,
    required this.canSkip,
  });

  @override
  ConsumerState<CommitmentsView> createState() => _CommitmentsViewState();
}

class _CommitmentsViewState extends ConsumerState<CommitmentsView> {
  final _controller = TextEditingController();
  final List<QuarterlyEvidence> _evidence = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quarterlySessionProvider);
    final question =
        ref.read(quarterlySessionProvider.notifier).currentQuestion;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commitments vs Actuals',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (widget.isClarify) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your previous answer was vague. Please provide a concrete example with specific details.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Describe your commitments and how they compared to your actual actions...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          _buildEvidenceSection(context),
          const SizedBox(height: 24),
          _buildEvidenceStrengthLegend(context),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.isClarify && widget.canSkip)
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isProcessing
                        ? null
                        : () {
                            ref
                                .read(quarterlySessionProvider.notifier)
                                .skipVaguenessGate();
                          },
                    child: Text(
                        'Skip (${2 - state.data.vaguenessSkipCount} left)'),
                  ),
                ),
              if (widget.isClarify && widget.canSkip) const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.isProcessing ||
                          _controller.text.trim().isEmpty
                      ? null
                      : () => _submit(),
                  child: state.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
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
        const SizedBox(height: 8),
        if (_evidence.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add evidence to strengthen your claims. Decision or Artifact = Strong, Proxy = Medium, Calendar = Weak.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
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

  Widget _buildEvidenceStrengthLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evidence Strength Guide',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _buildStrengthRow(
            context,
            icon: Icons.check_circle,
            color: Colors.green,
            label: 'Strong',
            description: 'Decision made or Artifact created',
          ),
          _buildStrengthRow(
            context,
            icon: Icons.circle,
            color: Colors.orange,
            label: 'Medium',
            description: 'Proxy evidence (testimonial, metrics)',
          ),
          _buildStrengthRow(
            context,
            icon: Icons.circle_outlined,
            color: Colors.red,
            label: 'Weak',
            description: 'Calendar entry only',
          ),
          _buildStrengthRow(
            context,
            icon: Icons.help_outline,
            color: Colors.grey,
            label: 'None',
            description: 'No receipt (recorded as such)',
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
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
        color = Colors.red;
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
          content: SingleChildScrollView(
            child: Column(
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
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the evidence...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedType != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStrengthColor(selectedType!.defaultStrength)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color:
                              _getStrengthColor(selectedType!.defaultStrength),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This will be marked as ${selectedType!.defaultStrength.displayName} strength',
                          style: TextStyle(
                            color: _getStrengthColor(
                                selectedType!.defaultStrength),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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

  void _submit() {
    ref
        .read(quarterlySessionProvider.notifier)
        .submitAnswer(_controller.text.trim());
  }
}
