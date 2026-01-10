import 'package:flutter/material.dart';

import '../../../data/enums/problem_direction.dart';
import '../../../services/governance/setup_state.dart';

/// Widget for collecting problem information during Setup.
///
/// Collects:
/// - Problem name
/// - What breaks if not solved
/// - Scarcity signals (2 items or Unknown + reason)
/// - Direction evidence (AI cheaper, Error cost, Trust required)
/// - Direction classification + rationale
class ProblemFormView extends StatefulWidget {
  /// The problem index (1-5).
  final int problemIndex;

  /// Whether this is a required problem (1-3) or optional (4-5).
  final bool isRequired;

  /// Existing problem data to edit.
  final SetupProblem? existingProblem;

  /// Called when problem is submitted.
  final void Function(SetupProblem problem) onSubmit;

  /// Called when user wants to skip (optional problems only).
  final VoidCallback? onSkip;

  const ProblemFormView({
    super.key,
    required this.problemIndex,
    this.isRequired = true,
    this.existingProblem,
    required this.onSubmit,
    this.onSkip,
  });

  @override
  State<ProblemFormView> createState() => _ProblemFormViewState();
}

class _ProblemFormViewState extends State<ProblemFormView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _whatBreaksController;
  late final TextEditingController _scarcity1Controller;
  late final TextEditingController _scarcity2Controller;
  late final TextEditingController _scarcityUnknownController;
  late final TextEditingController _aiCheaperController;
  late final TextEditingController _errorCostController;
  late final TextEditingController _trustRequiredController;
  late final TextEditingController _rationaleController;

  // State
  bool _scarcityUnknown = false;
  ProblemDirection? _selectedDirection;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingProblem;

    _nameController = TextEditingController(text: existing?.name ?? '');
    _whatBreaksController =
        TextEditingController(text: existing?.whatBreaks ?? '');
    _scarcity1Controller = TextEditingController(
      text: existing != null && existing.scarcitySignals.isNotEmpty
          ? existing.scarcitySignals[0]
          : '',
    );
    _scarcity2Controller = TextEditingController(
      text: existing != null && existing.scarcitySignals.length > 1
          ? existing.scarcitySignals[1]
          : '',
    );
    _scarcityUnknownController =
        TextEditingController(text: existing?.scarcityUnknownReason ?? '');
    _aiCheaperController =
        TextEditingController(text: existing?.evidenceAiCheaper ?? '');
    _errorCostController =
        TextEditingController(text: existing?.evidenceErrorCost ?? '');
    _trustRequiredController =
        TextEditingController(text: existing?.evidenceTrustRequired ?? '');
    _rationaleController =
        TextEditingController(text: existing?.directionRationale ?? '');

    _scarcityUnknown = existing?.scarcityUnknownReason?.isNotEmpty ?? false;
    _selectedDirection = existing?.direction;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatBreaksController.dispose();
    _scarcity1Controller.dispose();
    _scarcity2Controller.dispose();
    _scarcityUnknownController.dispose();
    _aiCheaperController.dispose();
    _errorCostController.dispose();
    _trustRequiredController.dispose();
    _rationaleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final problem = SetupProblem(
      name: _nameController.text.trim(),
      whatBreaks: _whatBreaksController.text.trim(),
      scarcitySignals: _scarcityUnknown
          ? []
          : [
              _scarcity1Controller.text.trim(),
              _scarcity2Controller.text.trim(),
            ],
      scarcityUnknownReason:
          _scarcityUnknown ? _scarcityUnknownController.text.trim() : null,
      evidenceAiCheaper: _aiCheaperController.text.trim(),
      evidenceErrorCost: _errorCostController.text.trim(),
      evidenceTrustRequired: _trustRequiredController.text.trim(),
      direction: _selectedDirection,
      directionRationale: _rationaleController.text.trim(),
      timeAllocationPercent: widget.existingProblem?.timeAllocationPercent ?? 0,
    );

    widget.onSubmit(problem);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _SectionHeader(
              number: widget.problemIndex,
              title: 'Problem ${widget.problemIndex}',
              subtitle: widget.isRequired ? 'Required' : 'Optional',
              isRequired: widget.isRequired,
            ),

            const SizedBox(height: 24),

            // Problem Name
            Text(
              'Problem Name',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g., "Strategic Planning", "Team Leadership"',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Problem name is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // What Breaks
            Text(
              'What breaks if this is not solved?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _whatBreaksController,
              decoration: const InputDecoration(
                hintText: 'What are the consequences of not addressing this?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Scarcity Signals
            Text(
              'Scarcity Signals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'What makes this skill rare or valuable? Provide 2 signals, or select "Unknown" if you are not sure.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                FilterChip(
                  label: const Text('I know the signals'),
                  selected: !_scarcityUnknown,
                  onSelected: (selected) {
                    setState(() => _scarcityUnknown = !selected);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Unknown'),
                  selected: _scarcityUnknown,
                  onSelected: (selected) {
                    setState(() => _scarcityUnknown = selected);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!_scarcityUnknown) ...[
              TextFormField(
                controller: _scarcity1Controller,
                decoration: const InputDecoration(
                  labelText: 'Scarcity Signal 1',
                  hintText: 'e.g., "Requires deep domain expertise"',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (!_scarcityUnknown &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Provide at least 2 scarcity signals';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _scarcity2Controller,
                decoration: const InputDecoration(
                  labelText: 'Scarcity Signal 2',
                  hintText: 'e.g., "Few people have this combination"',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (!_scarcityUnknown &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Provide at least 2 scarcity signals';
                  }
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _scarcityUnknownController,
                decoration: const InputDecoration(
                  labelText: 'Why is scarcity unknown?',
                  hintText: 'Explain why you are uncertain about scarcity',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (_scarcityUnknown &&
                      (value == null || value.trim().isEmpty)) {
                    return 'Explain why scarcity is unknown';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Direction Evidence
            Text(
              'Direction Evidence',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Answer these questions to help classify whether this skill is appreciating or depreciating.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // AI Cheaper
            Text(
              '1. Is AI getting cheaper/better at this?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _aiCheaperController,
              decoration: const InputDecoration(
                hintText: 'How is AI affecting this skill area?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Error Cost
            Text(
              '2. What is the cost of errors?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _errorCostController,
              decoration: const InputDecoration(
                hintText: 'What happens when mistakes are made?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Trust Required
            Text(
              '3. Is trust/access required?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _trustRequiredController,
              decoration: const InputDecoration(
                hintText: 'Does this require relationships or special access?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Direction Classification
            Text(
              'Direction Classification',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            _DirectionSelector(
              selectedDirection: _selectedDirection,
              onChanged: (direction) {
                setState(() => _selectedDirection = direction);
              },
            ),

            const SizedBox(height: 16),

            // Rationale
            Text(
              'Classification Rationale',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rationaleController,
              decoration: const InputDecoration(
                hintText: 'One sentence explaining your classification',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Rationale is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                if (widget.onSkip != null)
                  OutlinedButton(
                    onPressed: widget.onSkip,
                    child: const Text('Skip'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool isRequired;

  const _SectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isRequired
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectionSelector extends StatelessWidget {
  final ProblemDirection? selectedDirection;
  final void Function(ProblemDirection?) onChanged;

  const _DirectionSelector({
    required this.selectedDirection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DirectionOption(
          direction: ProblemDirection.appreciating,
          title: 'Appreciating',
          description: 'Becoming more valuable over time',
          icon: Icons.trending_up,
          color: Colors.green,
          isSelected: selectedDirection == ProblemDirection.appreciating,
          onTap: () => onChanged(ProblemDirection.appreciating),
        ),
        const SizedBox(height: 8),
        _DirectionOption(
          direction: ProblemDirection.depreciating,
          title: 'Depreciating',
          description: 'Becoming less valuable over time',
          icon: Icons.trending_down,
          color: Colors.red,
          isSelected: selectedDirection == ProblemDirection.depreciating,
          onTap: () => onChanged(ProblemDirection.depreciating),
        ),
        const SizedBox(height: 8),
        _DirectionOption(
          direction: ProblemDirection.stable,
          title: 'Stable',
          description: 'Direction unclear - revisit next quarter',
          icon: Icons.trending_flat,
          color: Colors.grey,
          isSelected: selectedDirection == ProblemDirection.stable,
          onTap: () => onChanged(ProblemDirection.stable),
        ),
      ],
    );
  }
}

class _DirectionOption extends StatelessWidget {
  final ProblemDirection direction;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionOption({
    required this.direction,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withValues(alpha: 0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}
