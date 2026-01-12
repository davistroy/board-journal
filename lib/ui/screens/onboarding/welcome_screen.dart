import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';
import '../../animations/animations.dart';
import '../../components/components.dart';
import '../../theme/theme.dart';

/// Welcome screen - first screen of onboarding.
///
/// Per PRD Section 5.0:
/// - Value proposition (1 screen)
/// - Target: first entry in <60 seconds
/// - Flow: Welcome -> Privacy -> OAuth -> First Entry (Home)
///
/// Redesigned with:
/// - Immersive gradient background
/// - Staggered animations for value props
/// - Oversized typography
/// - Premium CTAButton
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: brightness == Brightness.light
                ? [
                    colorScheme.surface,
                    AppColors.surfaceLightMuted,
                  ]
                : [
                    AppColors.surfaceDark,
                    AppColors.surfaceDarkMuted,
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Large decorative letter
              Positioned(
                top: -40,
                left: -30,
                child: Text(
                  'B',
                  style: TextStyle(
                    fontSize: size.width * 0.8,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary.withOpacity(0.03),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 200.ms)
                    .slideX(begin: -0.1, end: 0, duration: 800.ms),
              ),

              // Main content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 2),

                    // App name with editorial typography
                    Text(
                      'Boardroom',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 100.ms)
                        .slideY(begin: 0.3, end: 0, duration: 600.ms),

                    Text(
                      'Journal',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGold,
                        height: 1.1,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 200.ms)
                        .slideY(begin: 0.3, end: 0, duration: 600.ms),

                    const SizedBox(height: AppSpacing.md),

                    // Tagline
                    Text(
                      'Your AI-Powered Board of Directors',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .slideY(begin: 0.3, end: 0, duration: 600.ms),

                    const Spacer(),

                    // Value Propositions with stagger animation
                    _ValueProposition(
                      icon: Icons.mic_outlined,
                      title: 'Voice-First Journaling',
                      description: 'Capture your day in seconds with voice entries',
                    ).staggerIn(index: 0, delay: 400.ms),

                    const SizedBox(height: AppSpacing.md),

                    _ValueProposition(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Weekly Executive Briefs',
                      description: 'AI-generated summaries of your progress',
                    ).staggerIn(index: 1, delay: 400.ms),

                    const SizedBox(height: AppSpacing.md),

                    _ValueProposition(
                      icon: Icons.groups_outlined,
                      title: 'Career Governance',
                      description: 'Strategic guidance from your personal board',
                    ).staggerIn(index: 2, delay: 400.ms),

                    const Spacer(flex: 2),

                    // Get Started Button
                    Center(
                      child: CTAButton(
                        onPressed: () => context.go(AppRoutes.onboardingPrivacy),
                        label: 'Get Started',
                        icon: Icons.arrow_forward,
                        width: double.infinity,
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 800.ms)
                          .slideY(begin: 0.3, end: 0, duration: 600.ms),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single value proposition item.
class _ValueProposition extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ValueProposition({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? colorScheme.surface
            : AppColors.surfaceDarkAlt,
        borderRadius: AppSpacing.cardRadius,
        boxShadow: AppShadows.cardShadow(brightness),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.1),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Icon(
              icon,
              size: 24,
              color: AppColors.accentGold,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
