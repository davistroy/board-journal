import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/setup_providers.dart';
import '../../../router/router.dart';
import '../../../services/governance/setup_state.dart';
import '../../widgets/setup/setup_widgets.dart';

/// Screen for running the Setup workflow.
///
/// Per PRD Section 4.4 and 5.7:
/// - Create portfolio (3-5 problems)
/// - Time allocation validation
/// - Portfolio health calculation
/// - Board role creation (5 core + 0-2 growth)
/// - Persona generation
/// - Re-setup triggers definition
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  Future<void> _initSession() async {
    final notifier = ref.read(setupSessionProvider.notifier);

    // Check for in-progress session
    final inProgressId = await ref.read(hasInProgressSetupProvider.future);
    if (inProgressId != null) {
      await notifier.resumeSession(inProgressId);
    } else {
      // Get remembered abstraction mode preference
      final rememberedMode =
          await ref.read(rememberedSetupAbstractionModeProvider.future);
      await notifier.startSession(abstractionMode: rememberedMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(setupSessionProvider);
    final notifier = ref.read(setupSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(sessionState.currentStateName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context, notifier),
        ),
        actions: [
          // Progress indicator
          if (sessionState.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${sessionState.progressPercent}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
        bottom: sessionState.isActive
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: sessionState.progressPercent / 100,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              )
            : null,
      ),
      body: _buildBody(context, sessionState, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SetupSessionState sessionState,
    SetupSessionNotifier notifier,
  ) {
    // Loading state
    if (sessionState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Not configured state
    if (!sessionState.isConfigured) {
      return _NotConfiguredView(
        onBack: () => context.go(AppRoutes.governanceHub),
      );
    }

    // Error state
    if (sessionState.error != null) {
      return _ErrorView(
        error: sessionState.error!,
        onRetry: () => notifier.clearError(),
        onExit: () => context.go(AppRoutes.governanceHub),
      );
    }

    // Processing overlay
    if (sessionState.isProcessing) {
      return Stack(
        children: [
          _buildStateView(context, sessionState, notifier),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildStateView(context, sessionState, notifier);
  }

  Widget _buildStateView(
    BuildContext context,
    SetupSessionState sessionState,
    SetupSessionNotifier notifier,
  ) {
    final data = sessionState.data;

    switch (data.currentState) {
      case SetupState.initial:
        return const Center(child: CircularProgressIndicator());

      case SetupState.sensitivityGate:
        return SensitivityGateView(
          initialAbstractionMode: data.abstractionMode,
          onProceed: ({required abstractionMode, required rememberChoice}) {
            notifier.setSensitivityGate(
              abstractionMode: abstractionMode,
              rememberChoice: rememberChoice,
            );
          },
        );

      case SetupState.collectProblem1:
      case SetupState.validateProblem1:
        return ProblemFormView(
          problemIndex: 1,
          isRequired: true,
          existingProblem: data.problems.isNotEmpty ? data.problems[0] : null,
          onSubmit: (problem) => notifier.saveProblem(problem),
        );

      case SetupState.collectProblem2:
      case SetupState.validateProblem2:
        return ProblemFormView(
          problemIndex: 2,
          isRequired: true,
          existingProblem:
              data.problems.length > 1 ? data.problems[1] : null,
          onSubmit: (problem) => notifier.saveProblem(problem),
        );

      case SetupState.collectProblem3:
      case SetupState.validateProblem3:
        return ProblemFormView(
          problemIndex: 3,
          isRequired: true,
          existingProblem:
              data.problems.length > 2 ? data.problems[2] : null,
          onSubmit: (problem) => notifier.saveProblem(problem),
        );

      case SetupState.collectProblem4:
      case SetupState.validateProblem4:
        return ProblemFormView(
          problemIndex: 4,
          isRequired: false,
          existingProblem:
              data.problems.length > 3 ? data.problems[3] : null,
          onSubmit: (problem) => notifier.saveProblem(problem),
          onSkip: () => notifier.proceedToTimeAllocation(),
        );

      case SetupState.collectProblem5:
      case SetupState.validateProblem5:
        return ProblemFormView(
          problemIndex: 5,
          isRequired: false,
          existingProblem:
              data.problems.length > 4 ? data.problems[4] : null,
          onSubmit: (problem) => notifier.saveProblem(problem),
          onSkip: () => notifier.proceedToTimeAllocation(),
        );

      case SetupState.portfolioCompleteness:
        return _PortfolioCompletenessView(
          problemCount: data.problemCount,
          canAddMore: data.canAddMoreProblems,
          onAddProblem: () => notifier.addAnotherProblem(),
          onProceed: () => notifier.proceedToTimeAllocation(),
        );

      case SetupState.timeAllocation:
        return TimeAllocationView(
          problems: data.problems,
          onChanged: (allocations) => notifier.updateTimeAllocations(allocations),
          onProceed: () => notifier.proceedFromTimeAllocation(),
          status: data.timeAllocationStatus,
          totalAllocation: data.totalTimeAllocation,
        );

      case SetupState.calculateHealth:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculating portfolio health...'),
            ],
          ),
        );

      case SetupState.createCoreRoles:
      case SetupState.createGrowthRoles:
      case SetupState.createPersonas:
        if (data.portfolioHealth == null) {
          // Still waiting for health calculation
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing board creation...'),
              ],
            ),
          );
        }

        return PortfolioHealthView(
          health: data.portfolioHealth!,
          problems: data.problems,
          onProceed: () => notifier.createBoardAndPersonas(),
        );

      case SetupState.defineReSetupTriggers:
        return BoardRosterView(
          boardMembers: data.boardMembers,
          problems: data.problems,
          onEditPersona: (index) => _showPersonaEditDialog(
            context,
            data.boardMembers[index],
            index,
            notifier,
          ),
          onProceed: () => notifier.defineTriggersAndPublish(),
        );

      case SetupState.publishPortfolio:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Publishing portfolio...'),
            ],
          ),
        );

      case SetupState.finalized:
        return SetupOutputView(
          sessionData: data,
          onDone: () => context.go(AppRoutes.governanceHub),
        );

      case SetupState.abandoned:
        return _AbandonedView(
          onReturn: () => context.go(AppRoutes.governanceHub),
        );
    }
  }

  void _showPersonaEditDialog(
    BuildContext context,
    SetupBoardMember member,
    int index,
    SetupSessionNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => PersonaEditDialog(
        member: member,
        onSave: ({name, background, communicationStyle, signaturePhrase}) {
          notifier.updatePersona(
            memberIndex: index,
            name: name,
            background: background,
            communicationStyle: communicationStyle,
            signaturePhrase: signaturePhrase,
          );
        },
      ),
    );
  }

  void _showExitConfirmation(
    BuildContext context,
    SetupSessionNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Setup?'),
        content: const Text(
          'Your progress will be saved. You can resume this session later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.governanceHub);
            },
            child: const Text('Save & Exit'),
          ),
          TextButton(
            onPressed: () {
              notifier.abandonSession();
              Navigator.of(context).pop();
              context.go(AppRoutes.governanceHub);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredView extends StatelessWidget {
  final VoidCallback onBack;

  const _NotConfiguredView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64),
            const SizedBox(height: 16),
            Text(
              'AI Service Not Configured',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Setup requires AI services to be configured. Please add your API key in Settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onBack,
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onExit,
                  child: const Text('Exit'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioCompletenessView extends StatelessWidget {
  final int problemCount;
  final bool canAddMore;
  final VoidCallback onAddProblem;
  final VoidCallback onProceed;

  const _PortfolioCompletenessView({
    required this.problemCount,
    required this.canAddMore,
    required this.onAddProblem,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '$problemCount Problems Added',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have the minimum required problems. You can add more (up to 5) or continue to time allocation.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            if (canAddMore) ...[
              OutlinedButton.icon(
                onPressed: onAddProblem,
                icon: const Icon(Icons.add),
                label: Text('Add Problem ${problemCount + 1}'),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onProceed,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Time Allocation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbandonedView extends StatelessWidget {
  final VoidCallback onReturn;

  const _AbandonedView({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Session Abandoned',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This setup session has been abandoned.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onReturn,
              child: const Text('Return to Governance Hub'),
            ),
          ],
        ),
      ),
    );
  }
}
