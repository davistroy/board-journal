import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/router.dart';

/// Quarterly tab - Full quarterly review entry point.
class QuarterlyTab extends StatelessWidget {
  const QuarterlyTab({super.key, required this.hasPortfolio});

  final AsyncValue<bool> hasPortfolio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: hasPortfolio.when(
          data: (exists) {
            if (!exists) {
              return _buildLockedState(context);
            }
            return _buildUnlockedState(context);
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text('Error loading status'),
        ),
      ),
    );
  }

  Widget _buildLockedState(BuildContext context) {
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

  Widget _buildUnlockedState(BuildContext context) {
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
  }
}
