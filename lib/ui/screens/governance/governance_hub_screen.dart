import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/providers.dart';
import '../../../router/router.dart';

/// Hub screen for career governance features.
///
/// Per PRD Section 5.5, provides tabs for:
/// - Quick Version (15-min audit)
/// - Setup (Portfolio creation)
/// - Quarterly (Full report)
/// - Board (Roles + personas)
///
/// This is a scaffold - full implementation pending.
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

class _BoardTab extends StatelessWidget {
  const _BoardTab({required this.hasPortfolio});

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
              );
            }

            // Placeholder for board member list
            return Column(
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
                  '5-7 board members anchored to your problems',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                const Text('Board member list coming soon'),
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
