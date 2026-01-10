import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';
import '../../../../services/services.dart';
import 'bet_evaluation_view.dart';
import 'board_interrogation_view.dart';
import 'commitments_view.dart';
import 'evidence_input_view.dart';
import 'next_bet_view.dart';
import 'portfolio_health_update_view.dart';
import 'quarterly_output_view.dart';
import 'trigger_check_view.dart';

/// Main screen for Quarterly Report governance session.
///
/// Routes to different views based on the current state in the state machine.
class QuarterlyScreen extends ConsumerStatefulWidget {
  /// Optional session ID to resume.
  final String? sessionId;

  const QuarterlyScreen({super.key, this.sessionId});

  @override
  ConsumerState<QuarterlyScreen> createState() => _QuarterlyScreenState();
}

class _QuarterlyScreenState extends ConsumerState<QuarterlyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  Future<void> _initSession() async {
    final notifier = ref.read(quarterlySessionProvider.notifier);
    if (widget.sessionId != null) {
      await notifier.resumeSession(widget.sessionId!);
    } else {
      await notifier.startSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quarterlySessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context, state);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quarterly Report'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _handleBack(context, state),
          ),
          actions: [
            if (state.isActive)
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelp(context),
              ),
          ],
        ),
        body: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, QuarterlySessionState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading quarterly report...'),
          ],
        ),
      );
    }

    if (!state.isConfigured) {
      return _buildNotConfigured(context);
    }

    if (state.error != null) {
      return _buildError(context, state);
    }

    return Column(
      children: [
        _buildProgressIndicator(state),
        Expanded(
          child: _buildStateContent(context, state),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(QuarterlySessionState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.currentStateName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${state.progressPercent}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: state.progressPercent / 100,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(BuildContext context, QuarterlySessionState state) {
    switch (state.data.currentState) {
      case QuarterlyState.initial:
      case QuarterlyState.sensitivityGate:
        return _buildSensitivityGate(context, state);

      case QuarterlyState.gate0Prerequisites:
        return _buildPrerequisitesGate(context, state);

      case QuarterlyState.recentReportWarning:
        return _buildRecentReportWarning(context, state);

      case QuarterlyState.q1LastBetEvaluation:
        return BetEvaluationView(
          onEvaluated: () {},
          onSkipped: () {},
        );

      case QuarterlyState.q2CommitmentsVsActuals:
      case QuarterlyState.q2Clarify:
        return CommitmentsView(
          isClarify: state.data.currentState == QuarterlyState.q2Clarify,
          canSkip: state.data.canSkip,
        );

      case QuarterlyState.q3AvoidedDecision:
      case QuarterlyState.q3Clarify:
        return _buildQuestionView(
          context,
          state,
          title: 'Avoided Decision',
          question: ref.read(quarterlySessionProvider.notifier).currentQuestion,
          isClarify: state.data.currentState == QuarterlyState.q3Clarify,
        );

      case QuarterlyState.q4ComfortWork:
      case QuarterlyState.q4Clarify:
        return _buildQuestionView(
          context,
          state,
          title: 'Comfort Work',
          question: ref.read(quarterlySessionProvider.notifier).currentQuestion,
          isClarify: state.data.currentState == QuarterlyState.q4Clarify,
        );

      case QuarterlyState.q5PortfolioCheck:
      case QuarterlyState.q5Clarify:
        return _buildQuestionView(
          context,
          state,
          title: 'Portfolio Check',
          question: ref.read(quarterlySessionProvider.notifier).currentQuestion,
          isClarify: state.data.currentState == QuarterlyState.q5Clarify,
        );

      case QuarterlyState.q6PortfolioHealthUpdate:
        return PortfolioHealthUpdateView(
          healthTrend: state.data.healthTrend,
          onContinue: () {},
        );

      case QuarterlyState.q7ProtectionCheck:
      case QuarterlyState.q7Clarify:
        return _buildQuestionView(
          context,
          state,
          title: 'Protection Check',
          question: ref.read(quarterlySessionProvider.notifier).currentQuestion,
          isClarify: state.data.currentState == QuarterlyState.q7Clarify,
        );

      case QuarterlyState.q8OpportunityCheck:
      case QuarterlyState.q8Clarify:
        return _buildQuestionView(
          context,
          state,
          title: 'Opportunity Check',
          question: ref.read(quarterlySessionProvider.notifier).currentQuestion,
          isClarify: state.data.currentState == QuarterlyState.q8Clarify,
        );

      case QuarterlyState.q9TriggerCheck:
        return TriggerCheckView(
          triggerStatuses: state.data.triggerStatuses,
          anyMet: state.data.anyTriggerMet,
          onContinue: () {},
        );

      case QuarterlyState.q10NextBet:
        return const NextBetView();

      case QuarterlyState.coreBoardInterrogation:
      case QuarterlyState.growthBoardInterrogation:
      case QuarterlyState.boardInterrogationClarify:
        return BoardInterrogationView(
          currentMember: state.currentBoardMember,
          currentQuestion: state.currentBoardQuestion,
          isClarify:
              state.data.currentState == QuarterlyState.boardInterrogationClarify,
          canSkip: state.data.canSkip,
          isGrowthPhase:
              state.data.currentState == QuarterlyState.growthBoardInterrogation,
          coreBoardResponses: state.data.coreBoardResponses,
          growthBoardResponses: state.data.growthBoardResponses,
        );

      case QuarterlyState.generateReport:
        return _buildGeneratingReport(context);

      case QuarterlyState.finalized:
        return QuarterlyOutputView(
          outputMarkdown: state.data.outputMarkdown ?? '',
          betEvaluation: state.data.betEvaluation,
          newBet: state.data.newBet,
          createdBetId: state.data.createdBetId,
        );

      case QuarterlyState.abandoned:
        return _buildAbandoned(context);
    }
  }

  Widget _buildSensitivityGate(
      BuildContext context, QuarterlySessionState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            'Privacy Reminder',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your quarterly report will include detailed analysis of your career decisions. '
            'You can enable abstraction mode to use generic terms instead of specific names.',
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Abstraction Mode'),
            subtitle: const Text('Use generic terms for people and companies'),
            value: state.data.abstractionMode,
            onChanged: null,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isProcessing
                      ? null
                      : () {
                          ref
                              .read(quarterlySessionProvider.notifier)
                              .setSensitivityGate(abstractionMode: false);
                        },
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.isProcessing
                      ? null
                      : () {
                          ref
                              .read(quarterlySessionProvider.notifier)
                              .setSensitivityGate(abstractionMode: true);
                        },
                  child: const Text('Use Abstraction'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesGate(
      BuildContext context, QuarterlySessionState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checklist, size: 48),
          const SizedBox(height: 16),
          Text(
            'Checking Prerequisites',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Quarterly Report requires a portfolio, board, and triggers to be set up. '
            'Let me verify everything is ready.',
          ),
          const SizedBox(height: 24),
          if (state.isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: () {
                ref
                    .read(quarterlySessionProvider.notifier)
                    .processPrerequisitesGate();
              },
              child: const Text('Check Prerequisites'),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentReportWarning(
      BuildContext context, QuarterlySessionState state) {
    final daysSince = state.data.daysSinceLastReport;
    final showWarning = daysSince != null && daysSince < 30;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            showWarning ? Icons.warning_amber : Icons.check_circle_outline,
            size: 48,
            color: showWarning
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            showWarning ? 'Recent Report Warning' : 'Ready to Begin',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (showWarning)
            Text(
              'You completed a quarterly report $daysSince days ago. '
              'Reports are typically done every 90 days. '
              'You can still continue if needed.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            )
          else
            Text(
              daysSince != null
                  ? 'Your last report was $daysSince days ago. You are ready for a new quarterly review.'
                  : 'This will be your first quarterly report. Let us get started!',
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isProcessing
                  ? null
                  : () {
                      ref
                          .read(quarterlySessionProvider.notifier)
                          .processRecentReportWarning();
                    },
              child: Text(showWarning ? 'Continue Anyway' : 'Begin Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView(
    BuildContext context,
    QuarterlySessionState state, {
    required String title,
    required String question,
    required bool isClarify,
  }) {
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (isClarify) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your previous answer was vague. Please provide a concrete example.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: 'Enter your response...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (isClarify && state.data.canSkip)
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isProcessing
                        ? null
                        : () {
                            ref
                                .read(quarterlySessionProvider.notifier)
                                .skipVaguenessGate();
                          },
                    child: Text(
                        'Skip (${2 - state.data.vaguenessSkipCount} left)'),
                  ),
                ),
              if (isClarify && state.data.canSkip) const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.isProcessing
                      ? null
                      : () {
                          if (controller.text.trim().isNotEmpty) {
                            ref
                                .read(quarterlySessionProvider.notifier)
                                .submitAnswer(controller.text.trim());
                          }
                        },
                  child: state.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingReport(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Generating your quarterly report...'),
          SizedBox(height: 8),
          Text(
            'This may take a moment.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAbandoned(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Session Abandoned'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfigured(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'AI Service Not Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please configure your API key in settings to use Quarterly Report.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, QuarterlySessionState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    ref.read(quarterlySessionProvider.notifier).clearError();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleBack(BuildContext context, QuarterlySessionState state) {
    if (state.isActive) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abandon Session?'),
          content: const Text(
            'Your progress will be lost. Are you sure you want to abandon this quarterly report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(quarterlySessionProvider.notifier).abandonSession();
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Abandon'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quarterly Report Help',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Quarterly Report is a comprehensive review of your career progress. '
              'It includes:\n\n'
              '1. Bet evaluation (was your prediction correct?)\n'
              '2. Commitments vs actual actions\n'
              '3. Portfolio health analysis\n'
              '4. Board member interrogation\n'
              '5. New bet creation\n\n'
              'Be specific in your answers - vague responses will trigger follow-up questions. '
              'You can skip up to 2 clarification requests per session.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
