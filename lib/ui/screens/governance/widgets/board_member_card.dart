import 'package:flutter/material.dart';

import '../../../../data/data.dart';

/// Card widget for displaying a single board member.
class BoardMemberCard extends StatelessWidget {
  final BoardMember member;
  final Problem? anchoredProblem;
  final VoidCallback onTap;

  const BoardMemberCard({
    super.key,
    required this.member,
    required this.anchoredProblem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final roleType = _parseRoleType(member.roleType);
    final isInactive = member.isGrowthRole && !member.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: isInactive ? 0.6 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with role indicator
                _buildAvatar(context, roleType),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and badges
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              member.personaName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (member.isGrowthRole)
                            _buildBadge(
                              context,
                              label: isInactive ? 'Inactive' : 'Growth',
                              color: isInactive
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.tertiary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Role name and function
                      Text(
                        roleType?.displayName ?? member.roleType,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roleType?.function ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      // Inactive message
                      if (isInactive) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Inactive — no appreciating problems',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                      // Anchored problem
                      if (anchoredProblem != null && !isInactive) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.link,
                              size: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Anchored to: ${anchoredProblem!.name}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Chevron
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, BoardRoleType? roleType) {
    final initial = member.personaName.isNotEmpty
        ? member.personaName.substring(0, 1).toUpperCase()
        : '?';

    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: member.isGrowthRole
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: member.isGrowthRole
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getRoleIcon(roleType),
              size: 14,
              color: member.isGrowthRole
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, {required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  IconData _getRoleIcon(BoardRoleType? roleType) {
    if (roleType == null) return Icons.person;
    switch (roleType) {
      case BoardRoleType.accountability:
        return Icons.fact_check;
      case BoardRoleType.marketReality:
        return Icons.analytics;
      case BoardRoleType.avoidance:
        return Icons.psychology;
      case BoardRoleType.longTermPositioning:
        return Icons.trending_up;
      case BoardRoleType.devilsAdvocate:
        return Icons.balance;
      case BoardRoleType.portfolioDefender:
        return Icons.shield;
      case BoardRoleType.opportunityScout:
        return Icons.explore;
    }
  }

  BoardRoleType? _parseRoleType(String roleTypeStr) {
    try {
      return BoardRoleType.values.firstWhere((r) => r.name == roleTypeStr);
    } catch (_) {
      return null;
    }
  }
}
