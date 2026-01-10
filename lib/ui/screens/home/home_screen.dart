import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';

/// Home screen - the main hub of the app.
///
/// Per PRD Section 5.1:
/// - Record Entry (prominent, one tap away)
/// - Latest Weekly Brief (if exists)
/// - Run 15-min Audit CTA
/// - Governance (Portfolio + Quarterly)
/// - History access
/// - Setup prompt after 3-5 entries if no portfolio
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boardroom Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => context.go(AppRoutes.history),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all relevant providers
          ref.invalidate(weeklyBriefsStreamProvider);
          ref.invalidate(dailyEntriesStreamProvider);
          ref.invalidate(hasPortfolioProvider);
          ref.invalidate(shouldShowSetupPromptProvider);
          ref.invalidate(totalEntryCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Setup prompt (if needed)
              const _SetupPromptCard(),

              // Record Entry button (prominent)
              _RecordEntryCard(),

              const SizedBox(height: 16),

              // Latest Weekly Brief
              const _LatestBriefCard(),

              const SizedBox(height: 16),

              // Quick Actions
              _QuickActionsSection(),

              const SizedBox(height: 16),

              // Entry Stats
              const _EntryStatsCard(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prompt to run Setup after 3-5 entries.
class _SetupPromptCard extends ConsumerWidget {
  const _SetupPromptCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowPrompt = ref.watch(shouldShowSetupPromptProvider);

    return shouldShowPrompt.when(
      data: (show) {
        if (!show) return const SizedBox.shrink();

        return Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ready for your board?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ve recorded a few entries. Set up your board of directors to unlock career governance.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.setup),
                      child: const Text('Set Up Board'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: Dismiss prompt, re-show weekly
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dismiss functionality coming soon'),
                          ),
                        );
                      },
                      child: const Text('Later'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Prominent Record Entry button.
class _RecordEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.go(AppRoutes.recordEntry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Entry',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Voice or text - capture your day',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Latest weekly brief preview.
class _LatestBriefCard extends ConsumerWidget {
  const _LatestBriefCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefsAsync = ref.watch(weeklyBriefsStreamProvider);

    return briefsAsync.when(
      data: (briefs) {
        if (briefs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.summarize_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Brief',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No briefs yet. Record entries throughout the week and your first brief will generate Sunday at 8pm.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        // Get the most recent brief
        final latestBrief = briefs.first;

        return Card(
          child: InkWell(
            onTap: () => context.go(AppRoutes.latestWeeklyBrief),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.summarize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Latest Weekly Brief',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatWeekRange(latestBrief.weekStartUtc, latestBrief.weekEndUtc),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (latestBrief.briefMarkdown != null)
                    Text(
                      _getPreviewText(latestBrief.briefMarkdown!),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${latestBrief.entryCount} entries',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading briefs: $error'),
        ),
      ),
    );
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    return '${start.month}/${start.day} - ${end.month}/${end.day}/${end.year}';
  }

  String _getPreviewText(String markdown) {
    // Simple extraction: get first non-header line
    final lines = markdown.split('\n').where((line) {
      final trimmed = line.trim();
      return trimmed.isNotEmpty && !trimmed.startsWith('#');
    });
    return lines.take(3).join(' ').replaceAll(RegExp(r'\s+'), ' ');
  }
}

/// Quick action buttons section.
class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.timer_outlined,
                label: '15-min Audit',
                onTap: () => context.go(AppRoutes.quickVersion),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.dashboard_outlined,
                label: 'Governance',
                onTap: () => context.go(AppRoutes.governanceHub),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entry statistics card.
class _EntryStatsCard extends ConsumerWidget {
  const _EntryStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCount = ref.watch(totalEntryCountProvider);
    final hasPortfolio = ref.watch(hasPortfolioProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.article_outlined,
                    label: 'Entries',
                    value: totalCount.when(
                      data: (count) => count.toString(),
                      loading: () => '-',
                      error: (_, __) => '-',
                    ),
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.groups_outlined,
                    label: 'Board',
                    value: hasPortfolio.when(
                      data: (has) => has ? 'Active' : 'Not Set',
                      loading: () => '-',
                      error: (_, __) => '-',
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
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
