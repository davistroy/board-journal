import 'package:flutter/material.dart';

import '../../../../data/data.dart';
import '../../../../services/services.dart';

/// Reusable view for adding evidence with strength labeling.
class EvidenceInputView extends StatefulWidget {
  final List<QuarterlyEvidence> evidence;
  final Function(QuarterlyEvidence) onAdd;
  final Function(int) onRemove;

  const EvidenceInputView({
    super.key,
    required this.evidence,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<EvidenceInputView> createState() => _EvidenceInputViewState();
}

class _EvidenceInputViewState extends State<EvidenceInputView> {
  @override
  Widget build(BuildContext context) {
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
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Evidence'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.evidence.isEmpty)
          _buildEmptyState(context)
        else
          _buildEvidenceList(context),
        const SizedBox(height: 16),
        _buildStrengthLegend(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add evidence to support your claims. Receipts over rhetoric.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceList(BuildContext context) {
    return Column(
      children: List.generate(widget.evidence.length, (index) {
        final item = widget.evidence[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _getTypeIcon(item.type),
            title: Text(item.description),
            subtitle: Row(
              children: [
                _getStrengthBadge(item.strength),
                const SizedBox(width: 8),
                Text(item.type.displayName),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => widget.onRemove(index),
            ),
          ),
        );
      }),
    );
  }

  Widget _getTypeIcon(EvidenceType type) {
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

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _getStrengthBadge(EvidenceStrength strength) {
    Color color;
    String label;

    switch (strength) {
      case EvidenceStrength.strong:
        color = Colors.green;
        label = 'Strong';
        break;
      case EvidenceStrength.medium:
        color = Colors.orange;
        label = 'Medium';
        break;
      case EvidenceStrength.weak:
        color = Colors.red;
        label = 'Weak';
        break;
      case EvidenceStrength.none:
        color = Colors.grey;
        label = 'None';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStrengthLegend(BuildContext context) {
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
            'Evidence Strength by Type',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildLegendItem('Decision/Artifact', Colors.green, 'Strong'),
              _buildLegendItem('Proxy', Colors.orange, 'Medium'),
              _buildLegendItem('Calendar', Colors.red, 'Weak'),
              _buildLegendItem('None', Colors.grey, 'None'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String type, Color color, String strength) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$type = $strength',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    EvidenceType? selectedType;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Evidence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What type of evidence do you have?'),
                const SizedBox(height: 12),
                ...EvidenceType.values.map((type) => RadioListTile<EvidenceType>(
                      title: Text(type.displayName),
                      subtitle: Text(_getTypeDescription(type)),
                      value: type,
                      groupValue: selectedType,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                      dense: true,
                    )),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe this evidence...',
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
                      border: Border.all(
                        color: _getStrengthColor(selectedType!.defaultStrength),
                      ),
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
                        Expanded(
                          child: Text(
                            'This will be recorded with ${selectedType!.defaultStrength.displayName} strength',
                            style: TextStyle(
                              color: _getStrengthColor(
                                  selectedType!.defaultStrength),
                            ),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedType == null ||
                      descriptionController.text.trim().isEmpty
                  ? null
                  : () {
                      widget.onAdd(QuarterlyEvidence(
                        description: descriptionController.text.trim(),
                        type: selectedType!,
                        strength: selectedType!.defaultStrength,
                      ));
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeDescription(EvidenceType type) {
    switch (type) {
      case EvidenceType.decision:
        return 'A decision you made and documented';
      case EvidenceType.artifact:
        return 'Something you created (document, code, deliverable)';
      case EvidenceType.calendar:
        return 'Time you scheduled for something';
      case EvidenceType.proxy:
        return 'Indirect evidence (testimonial, metrics)';
      case EvidenceType.none:
        return 'No evidence, just a claim';
    }
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
}
