import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/router.dart';

/// Setup tab - Portfolio creation entry point.
class SetupTab extends StatelessWidget {
  const SetupTab({super.key, required this.hasPortfolio});

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
