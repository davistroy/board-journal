import 'package:flutter/material.dart';
import '../../../data/enums/signal_type.dart';
import '../../theme/theme.dart';

/// A preview card for weekly briefs with editorial styling.
///
/// Designed to look like a newspaper or magazine headline,
/// emphasizing the importance of the weekly brief content.
class BriefPreviewCard extends StatelessWidget {
  const BriefPreviewCard({
    super.key,
    required this.headline,
    required this.date,
    required this.onTap,
    this.winsCount = 0,
    this.blockersCount = 0,
    this.risksCount = 0,
    this.isLatest = false,
  });

  /// The brief headline (max 2 sentences).
  final String headline;

  /// The date of the brief.
  final DateTime date;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Count of wins in this brief.
  final int winsCount;

  /// Count of blockers in this brief.
  final int blockersCount;

  /// Count of risks in this brief.
  final int risksCount;

  /// Whether this is the most recent brief.
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.cardRadius,
            color: brightness == Brightness.light
                ? colorScheme.surface
                : AppColors.surfaceDarkAlt,
            boxShadow: AppShadows.cardShadow(brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and badge
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Weekly Brief',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (isLatest) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.2),
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        child: Text(
                          'LATEST',
                          style: AppTypography.monoStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      _formatDate(date),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Headline
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: textTheme.headlineSmall?.copyWith(
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Stats row
                    Row(
                      children: [
                        _StatBadge(
                          icon: Icons.emoji_events_outlined,
                          count: winsCount,
                          color: SignalColors.getPrimary(
                            SignalType.wins,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatBadge(
                          icon: Icons.block_outlined,
                          count: blockersCount,
                          color: SignalColors.getPrimary(
                            SignalType.blockers,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatBadge(
                          icon: Icons.warning_amber_outlined,
                          count: risksCount,
                          color: SignalColors.getPrimary(
                            SignalType.risks,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTypography.monoStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width brief card for the home screen.
class LatestBriefBanner extends StatelessWidget {
  const LatestBriefBanner({
    super.key,
    required this.headline,
    required this.date,
    required this.onTap,
    this.onRegenerateTap,
  });

  final String headline;
  final DateTime date;
  final VoidCallback onTap;
  final VoidCallback? onRegenerateTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppSpacing.cardRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: brightness == Brightness.light
                  ? [
                      AppColors.primaryNavy,
                      AppColors.primaryNavyLight,
                    ]
                  : [
                      AppColors.surfaceDarkMuted,
                      AppColors.surfaceDarkAlt,
                    ],
            ),
            boxShadow: AppShadows.elevatedShadow(brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.2),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: AppColors.accentGoldLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'LATEST BRIEF',
                          style: AppTypography.monoStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGoldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(date),
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                headline,
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Read full brief',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.accentGoldLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppColors.accentGoldLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[date.weekday - 1]}, ${date.month}/${date.day}';
  }
}
