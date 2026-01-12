import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../router/router.dart';

/// Quick Version tab - 15-minute audit entry point.
class QuickVersionTab extends StatelessWidget {
  const QuickVersionTab({super.key});

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
