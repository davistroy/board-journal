import 'package:flutter/material.dart';

import '../../../data/enums/board_role_type.dart';
import '../../../services/governance/setup_state.dart';

/// Widget for displaying the board roster during Setup.
///
/// Per PRD Section 3.3:
/// - 5 core roles (always active)
/// - 2 growth roles (if appreciating problems exist)
/// - Each role anchored to specific problem
class BoardRosterView extends StatelessWidget {
  /// Board members to display.
  final List<SetupBoardMember> boardMembers;

  /// Problems for context.
  final List<SetupProblem> problems;

  /// Called when user wants to edit a persona.
  final void Function(int memberIndex) onEditPersona;

  /// Called when user wants to proceed.
  final VoidCallback onProceed;

  const BoardRosterView({
    super.key,
    required this.boardMembers,
    required this.problems,
    required this.onEditPersona,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final coreMembers = boardMembers.where((m) => !m.isGrowthRole).toList();
    final growthMembers = boardMembers.where((m) => m.isGrowthRole).toList();

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
                  Icons.groups,
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
                      'Your Board',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${boardMembers.length} members created',
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

          // Core roles section
          _SectionHeader(
            title: 'Core Roles',
            subtitle: 'Always active',
            count: coreMembers.length,
          ),
          const SizedBox(height: 12),
          ...coreMembers.asMap().entries.map((entry) {
            return _BoardMemberCard(
              member: entry.value,
              problems: problems,
              onEdit: () => onEditPersona(
                boardMembers.indexOf(entry.value),
              ),
            );
          }),

          // Growth roles section (if any)
          if (growthMembers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Growth Roles',
              subtitle: 'Activated because you have appreciating problems',
              count: growthMembers.length,
            ),
            const SizedBox(height: 12),
            ...growthMembers.map((member) {
              return _BoardMemberCard(
                member: member,
                problems: problems,
                onEdit: () => onEditPersona(
                  boardMembers.indexOf(member),
                ),
                isGrowth: true,
              );
            }),
          ],

          const SizedBox(height: 24),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can edit persona names and profiles in Settings after setup.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
              label: const Text('Finalize Setup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardMemberCard extends StatelessWidget {
  final SetupBoardMember member;
  final List<SetupProblem> problems;
  final VoidCallback onEdit;
  final bool isGrowth;

  const _BoardMemberCard({
    required this.member,
    required this.problems,
    required this.onEdit,
    this.isGrowth = false,
  });

  String? get _anchoredProblemName {
    if (member.anchoredProblemIndex == null) return null;
    if (member.anchoredProblemIndex! >= problems.length) return null;
    return problems[member.anchoredProblemIndex!].name;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isGrowth
                      ? Colors.purple.withValues(alpha: 0.2)
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    member.personaName?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isGrowth
                          ? Colors.purple
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.personaName ?? 'Unknown',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        member.roleType.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isGrowth ? Colors.purple : null,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit persona',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Role function
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.roleType.function,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Anchored problem
            if (_anchoredProblemName != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.anchor,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anchored to: $_anchoredProblemName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Demand
            if (member.anchoredDemand != null &&
                member.anchoredDemand!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.anchoredDemand!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
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
    );
  }
}
