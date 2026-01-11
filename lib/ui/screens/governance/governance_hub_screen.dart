import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';

/// Hub screen for career governance features.
///
/// Per PRD Section 5.5, provides tabs for:
/// - Quick Version (15-min audit)
/// - Setup (Portfolio creation)
/// - Quarterly (Full report)
/// - Board (Roles + personas)
class GovernanceHubScreen extends ConsumerWidget {
  const GovernanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPortfolio = ref.watch(hasPortfolioProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Governance'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.home),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Quick'),
              Tab(text: 'Setup'),
              Tab(text: 'Quarterly'),
              Tab(text: 'Board'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Quick Version tab
            _QuickVersionTab(),
            // Setup tab
            _SetupTab(hasPortfolio: hasPortfolio),
            // Quarterly tab
            _QuarterlyTab(hasPortfolio: hasPortfolio),
            // Board tab
            _BoardTab(hasPortfolio: hasPortfolio),
          ],
        ),
      ),
    );
  }
}

class _QuickVersionTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              '15-Minute Audit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '5 questions to audit your week',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.quickVersion),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Quick Audit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupTab extends StatelessWidget {
  const _SetupTab({required this.hasPortfolio});

  final AsyncValue<bool> hasPortfolio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Portfolio Setup',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            hasPortfolio.when(
              data: (exists) => Text(
                exists
                    ? 'Your portfolio is configured'
                    : 'Create your problem portfolio and board',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading status'),
            ),
            const SizedBox(height: 24),
            hasPortfolio.when(
              data: (exists) => FilledButton.icon(
                onPressed: () => context.go(AppRoutes.setup),
                icon: Icon(exists ? Icons.edit : Icons.add),
                label: Text(exists ? 'Edit Portfolio' : 'Create Portfolio'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuarterlyTab extends StatelessWidget {
  const _QuarterlyTab({required this.hasPortfolio});

  final AsyncValue<bool> hasPortfolio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: hasPortfolio.when(
          data: (exists) {
            if (!exists) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Quarterly Report',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete Setup first to unlock Quarterly Reports',
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
              );
            }

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assessment_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Quarterly Report',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Full board interrogation and portfolio review',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.quarterly),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Quarterly Review'),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading status'),
        ),
      ),
    );
  }
}

/// Board tab showing all board members with their personas and anchoring.
///
/// Per PRD Section 5.5:
/// - Shows 5-7 board members and their anchored problem links
/// - Growth roles (Portfolio Defender, Opportunity Scout) visually distinguished
/// - Inactive growth roles show "Inactive—no appreciating problems" state
class _BoardTab extends ConsumerWidget {
  const _BoardTab({required this.hasPortfolio});

  final AsyncValue<bool> hasPortfolio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return hasPortfolio.when(
      data: (exists) {
        if (!exists) {
          return _buildNoPortfolioState(context);
        }
        return _BoardMemberList();
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
class _BoardMemberList extends ConsumerWidget {
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

                  return _BoardMemberCard(
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
      builder: (context) => _BoardMemberDetailSheet(
        member: member,
        anchoredProblem: problem,
      ),
    );
  }
}

/// Card widget for displaying a single board member.
class _BoardMemberCard extends StatelessWidget {
  final BoardMember member;
  final Problem? anchoredProblem;
  final VoidCallback onTap;

  const _BoardMemberCard({
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

/// Bottom sheet showing full details of a board member.
class _BoardMemberDetailSheet extends StatelessWidget {
  final BoardMember member;
  final Problem? anchoredProblem;

  const _BoardMemberDetailSheet({
    required this.member,
    required this.anchoredProblem,
  });

  @override
  Widget build(BuildContext context) {
    final roleType = _parseRoleType(member.roleType);
    final isInactive = member.isGrowthRole && !member.isActive;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: member.isGrowthRole
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      member.personaName.isNotEmpty
                          ? member.personaName.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: member.isGrowthRole
                            ? Theme.of(context).colorScheme.onTertiaryContainer
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.personaName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (member.isGrowthRole
                                        ? Theme.of(context).colorScheme.tertiary
                                        : Theme.of(context).colorScheme.primary)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                roleType?.displayName ?? member.roleType,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: member.isGrowthRole
                                          ? Theme.of(context).colorScheme.tertiary
                                          : Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                            if (member.isGrowthRole) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isInactive
                                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                                      : Theme.of(context).colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isInactive ? 'Inactive' : 'Growth Role',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: isInactive
                                            ? Theme.of(context).colorScheme.outline
                                            : Theme.of(context).colorScheme.onTertiaryContainer,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Role function
              _buildSection(
                context,
                icon: Icons.work_outline,
                title: 'Role Function',
                content: roleType?.function ?? 'Unknown function',
              ),

              // Interaction style
              _buildSection(
                context,
                icon: Icons.chat_bubble_outline,
                title: 'Interaction Style',
                content: roleType?.interactionStyle ?? 'Unknown style',
              ),

              // Signature question
              _buildSection(
                context,
                icon: Icons.format_quote,
                title: 'Signature Question',
                content: '"${roleType?.signatureQuestion ?? 'Unknown question'}"',
                isQuote: true,
              ),

              // Inactive notice
              if (isInactive)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This growth role is inactive because there are no appreciating problems in your portfolio.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Anchored problem
              if (anchoredProblem != null) ...[
                _buildSection(
                  context,
                  icon: Icons.link,
                  title: 'Anchored Problem',
                  content: anchoredProblem!.name,
                ),
                if (member.anchoredDemand != null)
                  _buildSection(
                    context,
                    icon: Icons.record_voice_over,
                    title: 'Anchored Demand',
                    content: member.anchoredDemand!,
                  ),
              ],

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              // Persona details
              Text(
                'Persona Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              _buildSection(
                context,
                icon: Icons.person_outline,
                title: 'Background',
                content: member.personaBackground,
              ),

              _buildSection(
                context,
                icon: Icons.record_voice_over_outlined,
                title: 'Communication Style',
                content: member.personaCommunicationStyle,
              ),

              if (member.personaSignaturePhrase != null &&
                  member.personaSignaturePhrase!.isNotEmpty)
                _buildSection(
                  context,
                  icon: Icons.format_quote,
                  title: 'Signature Phrase',
                  content: '"${member.personaSignaturePhrase}"',
                  isQuote: true,
                ),

              const SizedBox(height: 24),

              // Edit button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(AppRoutes.personaEditor);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Persona'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    bool isQuote = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: isQuote ? FontStyle.italic : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoardRoleType? _parseRoleType(String roleTypeStr) {
    try {
      return BoardRoleType.values.firstWhere((r) => r.name == roleTypeStr);
    } catch (_) {
      return null;
    }
  }
}
