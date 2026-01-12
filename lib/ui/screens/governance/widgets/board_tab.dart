import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/data.dart';
import '../../../../providers/providers.dart';
import '../../../../router/router.dart';
import 'board_member_card.dart';
import 'board_member_detail_sheet.dart';

/// Board tab showing all board members with their personas and anchoring.
///
/// Per PRD Section 5.5:
/// - Shows 5-7 board members and their anchored problem links
/// - Growth roles (Portfolio Defender, Opportunity Scout) visually distinguished
/// - Inactive growth roles show "Inactive—no appreciating problems" state
class BoardTab extends ConsumerWidget {
  const BoardTab({super.key, required this.hasPortfolio});

  final AsyncValue<bool> hasPortfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return hasPortfolio.when(
      data: (exists) {
        if (!exists) {
          return _buildNoPortfolioState(context);
        }
        return const BoardMemberList();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading status')),
    );
  }

  Widget _buildNoPortfolioState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Your Board',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Complete Setup to create your board of directors',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.setup),
              icon: const Icon(Icons.construction),
              label: const Text('Run Setup'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that displays the list of board members.
class BoardMemberList extends ConsumerWidget {
  const BoardMemberList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardMembersAsync = ref.watch(boardMembersStreamProvider);
    final problemsAsync = ref.watch(problemsStreamProvider);

    return boardMembersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return _buildEmptyState(context);
        }

        // Sort members: core roles first, then growth roles
        final sortedMembers = List<BoardMember>.from(members)
          ..sort((a, b) {
            // Core roles come first
            if (a.isGrowthRole != b.isGrowthRole) {
              return a.isGrowthRole ? 1 : -1;
            }
            // Within same category, sort by role type order
            return _getRoleOrder(a.roleType).compareTo(_getRoleOrder(b.roleType));
          });

        // Get problems map for displaying anchored problem names
        final problemsMap = problemsAsync.whenData((problems) {
          return {for (var p in problems) p.id: p};
        });

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.groups,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Board of Directors',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go(AppRoutes.personaEditor),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ),
            // Member count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildMemberCountChip(
                    context,
                    count: sortedMembers.where((m) => !m.isGrowthRole).length,
                    label: 'Core',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildMemberCountChip(
                    context,
                    count: sortedMembers.where((m) => m.isGrowthRole && m.isActive).length,
                    label: 'Growth',
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Member list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: sortedMembers.length,
                itemBuilder: (context, index) {
                  final member = sortedMembers[index];
                  final problem = problemsMap.whenData(
                    (map) => member.anchoredProblemId != null
                        ? map[member.anchoredProblemId]
                        : null,
                  );

                  return BoardMemberCard(
                    member: member,
                    anchoredProblem: problem.valueOrNull,
                    onTap: () => _showMemberDetails(context, member, problem.valueOrNull),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Error loading board members: $error'),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No Board Members',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Run Setup to create your board of directors',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.setup),
              icon: const Icon(Icons.add),
              label: const Text('Run Setup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCountChip(
    BuildContext context, {
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$count $label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  int _getRoleOrder(String roleType) {
    const order = {
      'accountability': 0,
      'marketReality': 1,
      'avoidance': 2,
      'longTermPositioning': 3,
      'devilsAdvocate': 4,
      'portfolioDefender': 5,
      'opportunityScout': 6,
    };
    return order[roleType] ?? 99;
  }

  void _showMemberDetails(BuildContext context, BoardMember member, Problem? problem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BoardMemberDetailSheet(
        member: member,
        anchoredProblem: problem,
      ),
    );
  }
}
