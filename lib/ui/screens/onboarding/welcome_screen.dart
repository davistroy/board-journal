import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Welcome screen - first screen of onboarding.
///
/// Per PRD Section 5.0:
/// - Value proposition (1 screen)
/// - Target: first entry in <60 seconds
/// - Flow: Welcome -> Privacy -> OAuth -> First Entry (Home)
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App Logo/Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_outlined,
                  size: 64,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              // App Name
              Text(
                'Boardroom Journal',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Tagline
              Text(
                'Your AI-Powered Board of Directors',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Value Propositions
              _ValueProposition(
                icon: Icons.mic_outlined,
                title: 'Voice-First Journaling',
                description: 'Capture your day in seconds with voice entries',
              ),
              const SizedBox(height: 16),
              _ValueProposition(
                icon: Icons.insights_outlined,
                title: 'Weekly Executive Briefs',
                description: 'AI-generated summaries of your progress',
              ),
              const SizedBox(height: 16),
              _ValueProposition(
                icon: Icons.psychology_outlined,
                title: 'Career Governance',
                description: 'Strategic guidance from your personal board',
              ),

              const Spacer(flex: 3),

              // Get Started Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(AppRoutes.onboardingPrivacy),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Get Started'),
                  ),
                ),
              ),

              const SizedBox(height: 16),
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

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 16),
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
    );
  }
}
