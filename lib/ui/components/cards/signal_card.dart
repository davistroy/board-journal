import 'package:flutter/material.dart';
import '../../../data/enums/signal_type.dart';
import '../../theme/theme.dart';

/// A card that displays a signal type with distinctive visual treatment.
///
/// Each signal type gets unique styling:
/// - Type-specific color and icon
/// - Left border accent
/// - Gradient background
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.type,
    required this.items,
    this.onTap,
    this.isExpanded = true,
    this.animate = false,
  });

  /// The type of signal.
  final SignalType type;

  /// The items to display in the card.
  final List<String> items;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Whether the card is expanded to show all items.
  final bool isExpanded;

  /// Whether to animate the card appearance.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final signalColor = SignalColors.getPrimary(type);
    final backgroundColor = SignalColors.getBackground(type, brightness);
    final icon = SignalColors.getIcon(type);
    final displayName = SignalColors.getDisplayName(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.cardRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundColor,
                backgroundColor.withOpacity(0.7),
              ],
            ),
            border: Border(
              left: BorderSide(
                color: signalColor,
                width: 4,
              ),
            ),
            boxShadow: AppShadows.signalShadow(signalColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and type name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.15),
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                      child: Icon(
                        icon,
                        color: signalColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: signalColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    // Item count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: signalColor.withOpacity(0.1),
                        borderRadius: AppSpacing.borderRadiusRound,
                      ),
                      child: Text(
                        '${items.length}',
                        style: AppTypography.monoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: signalColor,
                        ),
                      ),
                    ),
                  ],
                ),

                if (isExpanded && items.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  // Items list
                  ...items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: signalColor.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact signal chip for inline display.
class SignalChip extends StatelessWidget {
  const SignalChip({
    super.key,
    required this.type,
    required this.count,
    this.onTap,
  });

  final SignalType type;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final signalColor = SignalColors.getPrimary(type);
    final icon = SignalColors.getIcon(type);
    final label = SignalColors.getShortLabel(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.chipRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: signalColor.withOpacity(0.1),
            borderRadius: AppSpacing.chipRadius,
            border: Border.all(
              color: signalColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: signalColor),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTypography.monoStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: signalColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal scrollable row of signal chips.
class SignalChipsRow extends StatelessWidget {
  const SignalChipsRow({
    super.key,
    required this.signalCounts,
    this.onSignalTap,
  });

  /// Map of signal type to count.
  final Map<SignalType, int> signalCounts;

  /// Called when a signal chip is tapped.
  final void Function(SignalType)? onSignalTap;

  @override
  Widget build(BuildContext context) {
    final nonZeroSignals = signalCounts.entries
        .where((e) => e.value > 0)
        .toList();

    if (nonZeroSignals.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: nonZeroSignals.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: SignalChip(
              type: entry.key,
              count: entry.value,
              onTap: onSignalTap != null
                  ? () => onSignalTap!(entry.key)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
