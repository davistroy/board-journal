import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for running the Quarterly Report workflow.
///
/// Per PRD Section 4.5 and 5.8:
/// - Requires Portfolio + Board + Triggers
/// - Last bet evaluation
/// - Commitments vs actuals
/// - Portfolio health update
/// - Board interrogation (5-7 roles)
/// - Re-setup trigger check
/// - Next bet creation
///
/// This is a scaffold - full state machine implementation pending.
class QuarterlyScreen extends StatelessWidget {
  const QuarterlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quarterly Report'),
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
              const Icon(Icons.assessment_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Quarterly Report',
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
                'Sections:\n'
                '1. Last Bet Evaluation\n'
                '2. Commitments vs Actuals\n'
                '3. Avoided Decision\n'
                '4. Comfort Work\n'
                '5. Portfolio Health Update\n'
                '6. Board Interrogation\n'
                '7. Re-Setup Trigger Check\n'
                '8. Next Bet',
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
