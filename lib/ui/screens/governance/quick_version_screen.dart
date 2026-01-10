import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for running the Quick Version (15-min audit).
///
/// Per PRD Section 4.3 and 5.6:
/// - 5-question audit with anti-vagueness enforcement
/// - Sensitivity gate first
/// - One question at a time
/// - Vague response triggers concrete example follow-up
///
/// This is a scaffold - full state machine implementation pending.
class QuickVersionScreen extends StatelessWidget {
  const QuickVersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('15-Minute Audit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.governanceHub),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Quick Version',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'State machine implementation pending',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Questions:\n'
                '1. Role Context\n'
                '2. Paid Problems (3)\n'
                '3. Problem Direction Loop\n'
                '4. Avoided Decision\n'
                '5. Comfort Work',
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
