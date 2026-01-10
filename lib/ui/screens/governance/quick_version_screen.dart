import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/providers.dart';
import '../../../router/router.dart';
import '../../../services/services.dart';
import '../../widgets/governance/quick_version_question_view.dart';
import '../../widgets/governance/quick_version_output_view.dart';

/// Screen for running the Quick Version (15-min audit).
///
/// Per PRD Section 4.3 and 5.6:
/// - 5-question audit with anti-vagueness enforcement
/// - Sensitivity gate first
/// - One question at a time
/// - Vague response triggers concrete example follow-up
class QuickVersionScreen extends ConsumerStatefulWidget {
  const QuickVersionScreen({super.key});

  @override
  ConsumerState<QuickVersionScreen> createState() => _QuickVersionScreenState();
}

class _QuickVersionScreenState extends ConsumerState<QuickVersionScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSession());
  }

  Future<void> _initSession() async {
    if (_initialized) return;
    _initialized = true;

    final notifier = ref.read(quickVersionSessionProvider.notifier);

    // Check for in-progress session
    final inProgress = await ref.read(hasInProgressQuickVersionProvider.future);
    if (inProgress != null) {
      // Resume existing session
      await notifier.resumeSession(inProgress);
    } else {
      // Start new session
      await notifier.startSession();
    }
  }

  Future<void> _showAbandonConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Session?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Session'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(quickVersionSessionProvider.notifier).abandonSession();
      if (mounted) {
        context.go(AppRoutes.governanceHub);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(quickVersionSessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (sessionState.isCompleted) {
            context.go(AppRoutes.governanceHub);
          } else {
            _showAbandonConfirmation();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('15-Minute Audit'),
          leading: IconButton(
            icon: Icon(sessionState.isCompleted ? Icons.check : Icons.close),
            onPressed: () {
              if (sessionState.isCompleted) {
                context.go(AppRoutes.governanceHub);
              } else {
                _showAbandonConfirmation();
              }
            },
          ),
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
        body: _buildBody(sessionState),
      ),
    );
  }

  Widget _buildBody(QuickVersionSessionState sessionState) {
    // Not configured
    if (!sessionState.isConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Service Not Configured',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Please configure your Anthropic API key to use governance features.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.governanceHub),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Loading
    if (sessionState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting session...'),
          ],
        ),
      );
    }

    // Error
    if (sessionState.error != null) {
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
                'Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                sessionState.error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go(AppRoutes.governanceHub),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () {
                      ref.read(quickVersionSessionProvider.notifier).clearError();
                      _initialized = false;
                      _initSession();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Sensitivity gate
    if (sessionState.data.currentState == QuickVersionState.sensitivityGate) {
      return _SensitivityGateView(
        onContinue: (abstractionMode, remember) {
          ref.read(quickVersionSessionProvider.notifier).setSensitivityGate(
            abstractionMode: abstractionMode,
            rememberChoice: remember,
          );
        },
      );
    }

    // Completed - show output
    if (sessionState.isCompleted) {
      return QuickVersionOutputView(
        sessionData: sessionState.data,
        onDone: () => context.go(AppRoutes.governanceHub),
      );
    }

    // Generating output
    if (sessionState.data.currentState == QuickVersionState.generateOutput ||
        sessionState.isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              sessionState.data.currentState == QuickVersionState.generateOutput
                  ? 'Generating your audit report...'
                  : 'Processing...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    // Question view
    return QuickVersionQuestionView(
      sessionData: sessionState.data,
      questionText: ref.read(quickVersionSessionProvider.notifier).currentQuestion,
      onSubmit: (answer) {
        ref.read(quickVersionSessionProvider.notifier).submitAnswer(answer);
      },
      onSkip: sessionState.data.currentState.isClarify && sessionState.data.canSkip
          ? () async {
              final confirmed = await _showSkipConfirmation();
              if (confirmed && mounted) {
                ref.read(quickVersionSessionProvider.notifier).skipVaguenessGate();
              }
            }
          : null,
      remainingSkips: 2 - sessionState.data.vaguenessSkipCount,
    );
  }

  Future<bool> _showSkipConfirmation() async {
    final sessionState = ref.read(quickVersionSessionProvider);
    final remainingSkips = 2 - sessionState.data.vaguenessSkipCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Example?'),
        content: Text(
          'Skipping reduces the value of your audit. '
          'You have $remainingSkips skip${remainingSkips == 1 ? '' : 's'} remaining.\n\n'
          'Are you sure you want to skip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Provide Example'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Skip Anyway'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }
}

/// View for the sensitivity gate step.
class _SensitivityGateView extends ConsumerStatefulWidget {
  final void Function(bool abstractionMode, bool remember) onContinue;

  const _SensitivityGateView({required this.onContinue});

  @override
  ConsumerState<_SensitivityGateView> createState() =>
      _SensitivityGateViewState();
}

class _SensitivityGateViewState extends ConsumerState<_SensitivityGateView> {
  bool _abstractionMode = false;
  bool _rememberChoice = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final remembered = await ref.read(rememberedAbstractionModeProvider.future);
    if (remembered != null && mounted) {
      setState(() {
        _abstractionMode = remembered;
        _rememberChoice = true;
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Privacy Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Governance sessions discuss your career in detail. '
            'You can enable Abstraction Mode to automatically replace '
            'names, companies, and projects with placeholders.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Abstraction Mode'),
                    subtitle: const Text(
                      'Replace names and companies with placeholders',
                    ),
                    value: _abstractionMode,
                    onChanged: (value) {
                      setState(() => _abstractionMode = value);
                    },
                  ),
                  const Divider(),
                  CheckboxListTile(
                    title: const Text('Remember my choice'),
                    subtitle: const Text(
                      'Apply this setting to future Quick Version sessions',
                    ),
                    value: _rememberChoice,
                    onChanged: (value) {
                      setState(() => _rememberChoice = value ?? false);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_abstractionMode) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'With Abstraction Mode on, your answers and the generated '
                        'output will use placeholders like "my manager", "Company A", '
                        'and "Project X" instead of real names.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onContinue(_abstractionMode, _rememberChoice),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Start Audit'),
            ),
          ),
        ],
      ),
    );
  }
}
