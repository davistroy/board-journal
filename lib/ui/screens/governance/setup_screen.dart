import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Screen for running the Setup workflow.
///
/// Per PRD Section 4.4 and 5.7:
/// - Create portfolio (3-5 problems)
/// - Time allocation validation
/// - Portfolio health calculation
/// - Board role creation (5 core + 0-2 growth)
/// - Persona generation
/// - Re-setup triggers definition
///
/// This is a scaffold - full state machine implementation pending.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Setup'),
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
              const Icon(Icons.construction_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Setup',
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
                'Steps:\n'
                '1. Sensitivity Gate\n'
                '2. Problem Collection (3-5)\n'
                '3. Time Allocation Validation\n'
                '4. Portfolio Health Calculation\n'
                '5. Board Role Creation\n'
                '6. Persona Generation\n'
                '7. Re-Setup Triggers',
                textAlign: TextAlign.left,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
