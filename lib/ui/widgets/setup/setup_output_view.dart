import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/data.dart';
import '../../../services/governance/setup_state.dart';

/// Widget for displaying the completed Setup output.
///
/// Shows:
/// - Portfolio summary
/// - Health metrics
/// - Board members
/// - Re-setup triggers
/// - Export options
class SetupOutputView extends StatelessWidget {
  /// The completed session data.
  final SetupSessionData sessionData;

  /// Called when user is done viewing.
  final VoidCallback onDone;

  const SetupOutputView({
    super.key,
    required this.sessionData,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final health = sessionData.portfolioHealth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setup Complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Your portfolio and board have been created',
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

          // Portfolio summary
          _SectionHeader(
            icon: Icons.work,
            title: 'Your Portfolio',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Problems',
                    value: '${sessionData.problemCount}',
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBox(
                          label: 'Appreciating',
                          value: '${health?.appreciatingPercent ?? 0}%',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBox(
                          label: 'Stable',
                          value: '${health?.stablePercent ?? 0}%',
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBox(
                          label: 'Depreciating',
                          value: '${health?.depreciatingPercent ?? 0}%',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Problems list
          ...sessionData.problems.map((problem) {
            return _ProblemCard(problem: problem);
          }),

          const SizedBox(height: 24),

          // Health statements
          if (health != null) ...[
            if (health.riskStatement != null &&
                health.riskStatement!.isNotEmpty) ...[
              _StatementCard(
                title: 'Risk',
                icon: Icons.warning_amber,
                color: Colors.orange,
                statement: health.riskStatement!,
              ),
              const SizedBox(height: 12),
            ],
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
          ],

          // Board summary
          _SectionHeader(
            icon: Icons.groups,
            title: 'Your Board',
          ),
          const SizedBox(height: 12),
          ...sessionData.boardMembers.map((member) {
            return _BoardMemberSummaryCard(
              member: member,
              problems: sessionData.problems,
            );
          }),

          const SizedBox(height: 24),

          // Triggers summary
          _SectionHeader(
            icon: Icons.schedule,
            title: 'Re-Setup Triggers',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...sessionData.triggers.map((trigger) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            trigger.triggerType == 'annual'
                                ? Icons.calendar_today
                                : Icons.flag,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trigger.description,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (trigger.dueAtUtc != null)
                                  Text(
                                    'Due: ${_formatDate(trigger.dueAtUtc!)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
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
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Export buttons
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _shareMarkdown(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _copyToClipboard(BuildContext context) {
    final markdown = sessionData.outputMarkdown ?? 'No output generated';
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareMarkdown(BuildContext context) {
    final markdown = sessionData.outputMarkdown ?? 'No output generated';
    Share.share(markdown, subject: 'Portfolio Setup Results');
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  final SetupProblem problem;

  const _ProblemCard({required this.problem});

  Color get _directionColor {
    switch (problem.direction?.name) {
      case 'appreciating':
        return Colors.green;
      case 'depreciating':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _directionIcon {
    switch (problem.direction?.name) {
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_directionIcon, color: _directionColor),
        title: Text(problem.name ?? 'Unnamed'),
        trailing: Text(
          '${problem.timeAllocationPercent}%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _directionColor,
          ),
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
      color: color.withOpacity(0.1),
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

class _BoardMemberSummaryCard extends StatelessWidget {
  final SetupBoardMember member;
  final List<SetupProblem> problems;

  const _BoardMemberSummaryCard({
    required this.member,
    required this.problems,
  });

  String? get _anchoredProblemName {
    if (member.anchoredProblemIndex == null) return null;
    if (member.anchoredProblemIndex! >= problems.length) return null;
    return problems[member.anchoredProblemIndex!].name;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isGrowthRole
              ? Colors.purple.withOpacity(0.2)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            member.personaName?.substring(0, 1).toUpperCase() ?? '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: member.isGrowthRole
                  ? Colors.purple
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(member.personaName ?? 'Unknown'),
        subtitle: Text(
          '${member.roleType.displayName}${_anchoredProblemName != null ? ' - $_anchoredProblemName' : ''}',
        ),
        trailing: member.isGrowthRole
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Growth',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
