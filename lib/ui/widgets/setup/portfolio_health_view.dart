import 'package:flutter/material.dart';

import '../../../services/governance/setup_state.dart';

/// Widget for displaying portfolio health metrics.
///
/// Per PRD Section 3.3.6:
/// - appreciatingPct: Time allocation for appreciating problems
/// - depreciatingPct: Time allocation for depreciating problems
/// - stablePct: Time allocation for stable problems
/// - riskStatement: Where most exposed
/// - opportunityStatement: Where under-investing
class PortfolioHealthView extends StatelessWidget {
  /// Portfolio health data.
  final SetupPortfolioHealth health;

  /// Problems for context.
  final List<SetupProblem> problems;

  /// Called when user wants to proceed.
  final VoidCallback onProceed;

  const PortfolioHealthView({
    super.key,
    required this.health,
    required this.problems,
    required this.onProceed,
  });

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
                  Icons.health_and_safety,
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
                      'Portfolio Health',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Based on your problem directions and time allocation',
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

          const SizedBox(height: 32),

          // Health breakdown chart
          _HealthChart(
            appreciating: health.appreciatingPercent,
            depreciating: health.depreciatingPercent,
            stable: health.stablePercent,
          ),

          const SizedBox(height: 32),

          // Direction summary cards
          Row(
            children: [
              Expanded(
                child: _DirectionCard(
                  title: 'Appreciating',
                  percent: health.appreciatingPercent,
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DirectionCard(
                  title: 'Depreciating',
                  percent: health.depreciatingPercent,
                  icon: Icons.trending_down,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DirectionCard(
                  title: 'Stable',
                  percent: health.stablePercent,
                  icon: Icons.trending_flat,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Risk statement
          if (health.riskStatement != null &&
              health.riskStatement!.isNotEmpty) ...[
            _StatementCard(
              title: 'Risk',
              icon: Icons.warning_amber,
              color: Colors.orange,
              statement: health.riskStatement!,
            ),
            const SizedBox(height: 16),
          ],

          // Opportunity statement
          if (health.opportunityStatement != null &&
              health.opportunityStatement!.isNotEmpty) ...[
            _StatementCard(
              title: 'Opportunity',
              icon: Icons.lightbulb,
              color: Colors.blue,
              statement: health.opportunityStatement!,
            ),
            const SizedBox(height: 24),
          ],

          // Problems list
          Text(
            'Your Portfolio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...problems.map((p) => _ProblemSummaryCard(problem: p)),

          const SizedBox(height: 32),

          // Next step
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    health.hasAppreciating
                        ? Icons.people
                        : Icons.people_outline,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next: Create Your Board',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          health.hasAppreciating
                              ? '5 core roles + 2 growth roles (you have appreciating problems)'
                              : '5 core roles (no growth roles - no appreciating problems)',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onProceed,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Create Board'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthChart extends StatelessWidget {
  final int appreciating;
  final int depreciating;
  final int stable;

  const _HealthChart({
    required this.appreciating,
    required this.depreciating,
    required this.stable,
  });

  @override
  Widget build(BuildContext context) {
    final total = appreciating + depreciating + stable;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (appreciating > 0)
            Expanded(
              flex: appreciating,
              child: Container(
                color: Colors.green,
                alignment: Alignment.center,
                child: appreciating >= 15
                    ? Text(
                        '$appreciating%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
            ),
          if (stable > 0)
            Expanded(
              flex: stable,
              child: Container(
                color: Colors.grey,
                alignment: Alignment.center,
                child: stable >= 15
                    ? Text(
                        '$stable%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
            ),
          if (depreciating > 0)
            Expanded(
              flex: depreciating,
              child: Container(
                color: Colors.red,
                alignment: Alignment.center,
                child: depreciating >= 15
                    ? Text(
                        '$depreciating%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectionCard extends StatelessWidget {
  final String title;
  final int percent;
  final IconData icon;
  final Color color;

  const _DirectionCard({
    required this.title,
    required this.percent,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              '$percent%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String statement;

  const _StatementCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.statement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statement,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemSummaryCard extends StatelessWidget {
  final SetupProblem problem;

  const _ProblemSummaryCard({required this.problem});

  Color get _directionColor {
    switch (problem.direction) {
      case null:
        return Colors.grey;
      default:
        switch (problem.direction!.name) {
          case 'appreciating':
            return Colors.green;
          case 'depreciating':
            return Colors.red;
          default:
            return Colors.grey;
        }
    }
  }

  IconData get _directionIcon {
    switch (problem.direction) {
      case null:
        return Icons.trending_flat;
      default:
        switch (problem.direction!.name) {
          case 'appreciating':
            return Icons.trending_up;
          case 'depreciating':
            return Icons.trending_down;
          default:
            return Icons.trending_flat;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_directionIcon, color: _directionColor),
        title: Text(problem.name ?? 'Unnamed Problem'),
        subtitle: Text(problem.directionRationale ?? ''),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _directionColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${problem.timeAllocationPercent}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _directionColor,
            ),
          ),
        ),
      ),
    );
  }
}
