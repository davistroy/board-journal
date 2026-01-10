import 'package:flutter/material.dart';

import '../../../services/governance/setup_state.dart';

/// Widget for configuring time allocation percentages for problems.
///
/// Per PRD Section 4.4:
/// - 95-105%: Green, proceed
/// - 90-94% or 106-110%: Yellow warning, allow proceed
/// - <90% or >110%: Red error, block proceed
class TimeAllocationView extends StatefulWidget {
  /// The problems to allocate time for.
  final List<SetupProblem> problems;

  /// Called when allocations are updated.
  final void Function(List<int> allocations) onChanged;

  /// Called when user wants to proceed.
  final VoidCallback onProceed;

  /// Current validation status.
  final TimeAllocationStatus? status;

  /// Current total allocation.
  final int totalAllocation;

  const TimeAllocationView({
    super.key,
    required this.problems,
    required this.onChanged,
    required this.onProceed,
    this.status,
    this.totalAllocation = 0,
  });

  @override
  State<TimeAllocationView> createState() => _TimeAllocationViewState();
}

class _TimeAllocationViewState extends State<TimeAllocationView> {
  late List<int> _allocations;

  @override
  void initState() {
    super.initState();
    _allocations = widget.problems.map((p) => p.timeAllocationPercent).toList();

    // If all allocations are 0, distribute evenly
    if (_allocations.every((a) => a == 0)) {
      final evenAlloc = 100 ~/ widget.problems.length;
      _allocations = List.filled(widget.problems.length, evenAlloc);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(_allocations);
      });
    }
  }

  @override
  void didUpdateWidget(TimeAllocationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.problems.length != oldWidget.problems.length) {
      _allocations =
          widget.problems.map((p) => p.timeAllocationPercent).toList();
    }
  }

  int get _total => _allocations.fold(0, (sum, a) => sum + a);

  TimeAllocationStatus get _status =>
      SetupSessionData.validateTimeAllocation(_total);

  Color get _statusColor {
    switch (_status) {
      case TimeAllocationStatus.valid:
        return Colors.green;
      case TimeAllocationStatus.warning:
        return Colors.orange;
      case TimeAllocationStatus.error:
        return Colors.red;
    }
  }

  void _updateAllocation(int index, int value) {
    setState(() {
      _allocations[index] = value;
    });
    widget.onChanged(_allocations);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pie_chart,
                  size: 28,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Allocation',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'How much time do you spend on each problem?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Total indicator
          _TotalIndicator(
            total: _total,
            status: _status,
            color: _statusColor,
          ),

          const SizedBox(height: 24),

          // Allocation sliders
          ...List.generate(widget.problems.length, (index) {
            final problem = widget.problems[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _AllocationSlider(
                problemName: problem.name ?? 'Problem ${index + 1}',
                direction: problem.direction,
                value: _allocations[index],
                onChanged: (value) => _updateAllocation(index, value),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Guidelines
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Allocation Guidelines',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _GuidelineItem(
                    color: Colors.green,
                    label: '95-105%',
                    description: 'Ideal range',
                  ),
                  const SizedBox(height: 4),
                  _GuidelineItem(
                    color: Colors.orange,
                    label: '90-94% or 106-110%',
                    description: 'Acceptable with warning',
                  ),
                  const SizedBox(height: 4),
                  _GuidelineItem(
                    color: Colors.red,
                    label: '<90% or >110%',
                    description: 'Must adjust before proceeding',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _status.canProceed ? widget.onProceed : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
            ),
          ),

          if (!_status.canProceed) ...[
            const SizedBox(height: 12),
            Text(
              _status.getMessage(_total),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalIndicator extends StatelessWidget {
  final int total;
  final TimeAllocationStatus status;
  final Color color;

  const _TotalIndicator({
    required this.total,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == TimeAllocationStatus.valid
                ? Icons.check_circle
                : status == TimeAllocationStatus.warning
                    ? Icons.warning_amber
                    : Icons.error,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total: $total%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                status.getMessage(total),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllocationSlider extends StatelessWidget {
  final String problemName;
  final dynamic direction; // ProblemDirection
  final int value;
  final void Function(int) onChanged;

  const _AllocationSlider({
    required this.problemName,
    this.direction,
    required this.value,
    required this.onChanged,
  });

  Color get _directionColor {
    if (direction == null) return Colors.grey;
    switch (direction.toString().split('.').last) {
      case 'appreciating':
        return Colors.green;
      case 'depreciating':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _directionIcon {
    if (direction == null) return Icons.trending_flat;
    switch (direction.toString().split('.').last) {
      case 'appreciating':
        return Icons.trending_up;
      case 'depreciating':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_directionIcon, size: 20, color: _directionColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                problemName,
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
                '$value%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '$value%',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final Color color;
  final String label;
  final String description;

  const _GuidelineItem({
    required this.color,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
