import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../animations/animations.dart';
import '../../components/components.dart';
import '../../theme/theme.dart';

/// Home screen - the main hub of the app.
///
/// Per PRD Section 5.1:
/// - Record Entry (prominent, one tap away)
/// - Latest Weekly Brief (if exists)
/// - Run 15-min Audit CTA
/// - Governance (Portfolio + Quarterly)
/// - History access
/// - Setup prompt after 3-5 entries if no portfolio
///
/// Redesigned with:
/// - Hero record button
/// - Staggered list animations
/// - Premium card styling
/// - Gradient accents
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Boardroom Journal',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              HapticService.lightTap();
              context.go(AppRoutes.history);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              HapticService.lightTap();
              context.go(AppRoutes.settings);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticService.lightTap();
          ref.invalidate(weeklyBriefsStreamProvider);
          ref.invalidate(dailyEntriesStreamProvider);
          ref.invalidate(hasPortfolioProvider);
          ref.invalidate(shouldShowSetupPromptProvider);
          ref.invalidate(totalEntryCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Setup prompt (if needed)
              const _SetupPromptCard().staggerIn(index: 0),

              // Hero Record Button Section
              _HeroRecordSection().staggerIn(index: 1),

              const SizedBox(height: AppSpacing.lg),

              // Latest Weekly Brief
              const _LatestBriefCard().staggerIn(index: 2),

              const SizedBox(height: AppSpacing.lg),

              // Quick Actions
              _QuickActionsSection().staggerIn(index: 3),

              const SizedBox(height: AppSpacing.lg),

              // Entry Stats
              const _EntryStatsCard().staggerIn(index: 4),

              const SizedBox(height: AppSpacing.xxl),
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
    final brightness = Theme.of(context).brightness;

    return shouldShowPrompt.when(
      data: (show) {
        if (!show) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentGold.withOpacity(0.15),
                AppColors.accentGold.withOpacity(0.05),
              ],
            ),
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(
              color: AppColors.accentGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.2),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.accentGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Ready for your board?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You\'ve recorded a few entries. Set up your board of directors to unlock career governance.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  AnimatedFilledButton(
                    onPressed: () => context.go(AppRoutes.setup),
                    child: const Text('Set Up Board'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedTextButton(
                    onPressed: () async {
                      await ref.read(userPreferencesRepositoryProvider).dismissSetupPrompt();
                      ref.invalidate(shouldShowSetupPromptProvider);
                    },
                    child: const Text('Later'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Hero Record Entry section with prominent button.
class _HeroRecordSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brightness == Brightness.light
              ? [
                  colorScheme.primaryContainer,
                  colorScheme.primaryContainer.withOpacity(0.7),
                ]
              : [
                  AppColors.surfaceDarkMuted,
                  AppColors.surfaceDarkAlt,
                ],
        ),
        borderRadius: AppSpacing.cardRadius,
        boxShadow: AppShadows.cardShadow(brightness),
      ),
      child: Column(
        children: [
          HeroRecordButton(
            onPressed: () => context.go(AppRoutes.recordEntry),
            size: 72,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Record Entry',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Voice or text - capture your day',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return briefsAsync.when(
      data: (briefs) {
        if (briefs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: brightness == Brightness.light
                  ? colorScheme.surface
                  : AppColors.surfaceDarkAlt,
              borderRadius: AppSpacing.cardRadius,
              boxShadow: AppShadows.cardShadow(brightness),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Weekly Brief',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No briefs yet. Generate one now or wait until Sunday 8pm for automatic generation.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                AnimatedFilledButton(
                  onPressed: () => context.go(AppRoutes.latestWeeklyBrief),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Generate Brief'),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final latestBrief = briefs.first;
        final headline = _getPreviewText(latestBrief.briefMarkdown ?? '');

        return LatestBriefBanner(
          headline: headline.isNotEmpty ? headline : 'Your weekly brief is ready',
          date: latestBrief.weekEndUtc,
          onTap: () => context.go(AppRoutes.latestWeeklyBrief),
        );
      },
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: brightness == Brightness.light
              ? colorScheme.surface
              : AppColors.surfaceDarkAlt,
          borderRadius: AppSpacing.cardRadius,
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: AppSpacing.cardRadius,
        ),
        child: Text('Error loading briefs: $error'),
      ),
    );
  }

  String _getPreviewText(String markdown) {
    final lines = markdown.split('\n').where((line) {
      final trimmed = line.trim();
      return trimmed.isNotEmpty && !trimmed.startsWith('#');
    });
    return lines.take(2).join(' ').replaceAll(RegExp(r'\s+'), ' ');
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.timer_outlined,
                label: '15-min Audit',
                color: SignalColors.getPrimary(SignalType.actions),
                onTap: () => context.go(AppRoutes.quickVersion),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.dashboard_outlined,
                label: 'Governance',
                color: AppColors.accentGold,
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
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return PressableScale(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: brightness == Brightness.light
              ? colorScheme.surface
              : AppColors.surfaceDarkAlt,
          borderRadius: AppSpacing.cardRadius,
          boxShadow: AppShadows.cardShadow(brightness),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
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
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? colorScheme.surface
            : AppColors.surfaceDarkAlt,
        borderRadius: AppSpacing.cardRadius,
        boxShadow: AppShadows.cardShadow(brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
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
                  color: SignalColors.getPrimary(SignalType.wins),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatItem(
                  icon: Icons.groups_outlined,
                  label: 'Board',
                  value: hasPortfolio.when(
                    data: (has) => has ? 'Active' : 'Not Set',
                    loading: () => '-',
                    error: (_, __) => '-',
                  ),
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: AppSpacing.borderRadiusSm,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.statNumberStyle(
                fontSize: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
