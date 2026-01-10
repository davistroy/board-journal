import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../router/router.dart';

/// Screen for editing portfolio problems.
///
/// Per PRD Section 5.9:
/// - Edit problems (description, allocation without re-setup)
/// - Delete problem (min 3 enforced, re-anchoring flow)
/// - Time allocations must sum to 95-105%
class PortfolioEditorScreen extends ConsumerStatefulWidget {
  const PortfolioEditorScreen({super.key});

  @override
  ConsumerState<PortfolioEditorScreen> createState() => _PortfolioEditorScreenState();
}

class _PortfolioEditorScreenState extends ConsumerState<PortfolioEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final problemsAsync = ref.watch(problemsStreamProvider);
    final totalAsync = ref.watch(totalAllocationProvider);
    final validationAsync = ref.watch(allocationValidationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Portfolio'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.settings),
        ),
      ),
      body: problemsAsync.when(
        data: (problems) {
          if (problems.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Allocation summary
              _AllocationSummary(
                total: totalAsync.valueOrNull ?? 0,
                validation: validationAsync.valueOrNull,
              ),

              // Problem list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: problems.length,
                  itemBuilder: (context, index) {
                    final problem = problems[index];
                    return _ProblemCard(
                      problem: problem,
                      canDelete: problems.length > ProblemRepository.minProblems,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading problems: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(problemsStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No Problems Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete Setup to define your portfolio.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(AppRoutes.setup),
            child: const Text('Start Setup'),
          ),
        ],
      ),
    );
  }
}

class _AllocationSummary extends StatelessWidget {
  final int total;
  final String? validation;

  const _AllocationSummary({
    required this.total,
    this.validation,
  });

  Color _getStatusColor(BuildContext context) {
    if (total >= 95 && total <= 105) return Colors.green;
    if (total >= 90 && total <= 110) return Colors.orange;
    return Colors.red;
  }

  IconData _getStatusIcon() {
    if (total >= 95 && total <= 105) return Icons.check_circle;
    if (total >= 90 && total <= 110) return Icons.warning_amber;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(), color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Allocation: $total%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                if (validation != null)
                  Text(
                    validation!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                        ),
                  )
                else if (total >= 95 && total <= 105)
                  Text(
                    'Allocation is within ideal range',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends ConsumerWidget {
  final Problem problem;
  final bool canDelete;

  const _ProblemCard({
    required this.problem,
    required this.canDelete,
  });

  ProblemDirection get direction {
    return ProblemDirection.values.firstWhere(
      (d) => d.name == problem.direction,
      orElse: () => ProblemDirection.stable,
    );
  }

  Color _getDirectionColor() {
    switch (direction) {
      case ProblemDirection.appreciating:
        return Colors.green;
      case ProblemDirection.depreciating:
        return Colors.red;
      case ProblemDirection.stable:
        return Colors.grey;
    }
  }

  IconData _getDirectionIcon() {
    switch (direction) {
      case ProblemDirection.appreciating:
        return Icons.trending_up;
      case ProblemDirection.depreciating:
        return Icons.trending_down;
      case ProblemDirection.stable:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDirectionIcon(),
                  color: _getDirectionColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${problem.timeAllocationPercent}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditDialog(context, ref);
                        break;
                      case 'allocation':
                        _showAllocationDialog(context, ref);
                        break;
                      case 'delete':
                        _showDeleteDialog(context, ref);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'allocation',
                      child: Row(
                        children: [
                          Icon(Icons.pie_chart),
                          SizedBox(width: 8),
                          Text('Adjust Allocation'),
                        ],
                      ),
                    ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              problem.whatBreaks,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getDirectionColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    direction.displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _getDirectionColor(),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => _ProblemEditDialog(problem: problem),
    );
  }

  Future<void> _showAllocationDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => _AllocationEditDialog(problem: problem),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref) async {
    // Check for anchored board members
    final anchoredMembers = await ref
        .read(problemEditorNotifierProvider.notifier)
        .getAnchoredMembers(problem.id);

    if (!context.mounted) return;

    final hasAnchored = anchoredMembers.isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Problem?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${problem.name}"?'),
            if (hasAnchored) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${anchoredMembers.length} board member(s) are anchored to this problem and will need to be re-anchored.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await ref
          .read(problemEditorNotifierProvider.notifier)
          .deleteProblem(problem.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Problem deleted'
                  : 'Cannot delete: minimum ${ProblemRepository.minProblems} problems required',
            ),
          ),
        );
      }
    }
  }
}

class _ProblemEditDialog extends ConsumerStatefulWidget {
  final Problem problem;

  const _ProblemEditDialog({required this.problem});

  @override
  ConsumerState<_ProblemEditDialog> createState() => _ProblemEditDialogState();
}

class _ProblemEditDialogState extends ConsumerState<_ProblemEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _whatBreaksController;
  late final TextEditingController _rationaleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.problem.name);
    _whatBreaksController = TextEditingController(text: widget.problem.whatBreaks);
    _rationaleController = TextEditingController(text: widget.problem.directionRationale);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatBreaksController.dispose();
    _rationaleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(problemEditorNotifierProvider.notifier).updateProblem(
          widget.problem.id,
          name: _nameController.text.trim(),
          whatBreaks: _whatBreaksController.text.trim(),
          directionRationale: _rationaleController.text.trim(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Problem updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Problem'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Problem Name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Brief name for this problem',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              Text(
                'What Breaks If Not Solved?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _whatBreaksController,
                decoration: const InputDecoration(
                  hintText: 'Describe the consequences...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              Text(
                'Direction Rationale',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rationaleController,
                decoration: const InputDecoration(
                  hintText: 'Why is this problem classified this way?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Rationale is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To change the direction classification, you\'ll need to run Setup again.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              FilledButton(
                onPressed: _save,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocationEditDialog extends ConsumerStatefulWidget {
  final Problem problem;

  const _AllocationEditDialog({required this.problem});

  @override
  ConsumerState<_AllocationEditDialog> createState() => _AllocationEditDialogState();
}

class _AllocationEditDialogState extends ConsumerState<_AllocationEditDialog> {
  late int _allocation;

  @override
  void initState() {
    super.initState();
    _allocation = widget.problem.timeAllocationPercent;
  }

  Future<void> _save() async {
    await ref.read(problemEditorNotifierProvider.notifier).updateAllocation(
          widget.problem.id,
          _allocation,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Allocation updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust Allocation: ${widget.problem.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_allocation%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: _allocation.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_allocation%',
              onChanged: (value) => setState(() => _allocation = value.round()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Remember: total allocation should be 95-105%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
