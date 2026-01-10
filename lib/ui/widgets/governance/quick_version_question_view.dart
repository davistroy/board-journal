import 'package:flutter/material.dart';

import '../../../services/services.dart';

/// Widget for displaying a question in the Quick Version audit.
///
/// Shows:
/// - Question number and progress
/// - The question text
/// - Text input for the answer
/// - Optional skip button for clarify states
class QuickVersionQuestionView extends StatefulWidget {
  /// Current session data.
  final QuickVersionSessionData sessionData;

  /// The question text to display.
  final String questionText;

  /// Called when user submits an answer.
  final void Function(String answer) onSubmit;

  /// Called when user wants to skip (clarify states only).
  final VoidCallback? onSkip;

  /// Number of skips remaining.
  final int remainingSkips;

  const QuickVersionQuestionView({
    super.key,
    required this.sessionData,
    required this.questionText,
    required this.onSubmit,
    this.onSkip,
    this.remainingSkips = 2,
  });

  @override
  State<QuickVersionQuestionView> createState() =>
      _QuickVersionQuestionViewState();
}

class _QuickVersionQuestionViewState extends State<QuickVersionQuestionView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.sessionData.currentState;
    final isClarify = state.isClarify;
    final questionNumber = state.questionNumber;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number indicator
          _QuestionIndicator(
            questionNumber: questionNumber,
            totalQuestions: 5,
            displayName: state.displayName,
          ),

          const SizedBox(height: 24),

          // Clarify indicator if applicable
          if (isClarify) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your answer was vague. Please provide a concrete example.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Question text
          Text(
            widget.questionText,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),

          const SizedBox(height: 8),

          // Helper text for specific questions
          if (_getHelperText() != null) ...[
            Text(
              _getHelperText()!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 16),

          // Answer input
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: isClarify
                  ? 'Provide a specific example with who, what, when, and result...'
                  : 'Type your answer...',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onSubmitted: (_) => _submit(),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Skip button (only for clarify states with skips remaining)
              if (isClarify && widget.onSkip != null)
                OutlinedButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip (${widget.remainingSkips} left)',
                  ),
                ),

              const Spacer(),

              // Submit button
              FilledButton.icon(
                onPressed: _hasText ? _submit : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
              ),
            ],
          ),

          // Context from previous answers if in Q3 direction loop
          if (state == QuickVersionState.q3DirectionLoop &&
              widget.sessionData.currentProblem != null) ...[
            const SizedBox(height: 32),
            _DirectionProgressCard(
              problem: widget.sessionData.currentProblem!,
              currentSubQuestion: widget.sessionData.currentDirectionSubQuestion,
            ),
          ],
        ],
      ),
    );
  }

  String? _getHelperText() {
    final state = widget.sessionData.currentState;

    switch (state) {
      case QuickVersionState.q1RoleContext:
        return 'Be specific about your title, team, and what you actually do day-to-day.';
      case QuickVersionState.q2PaidProblems:
        return 'These are the challenges or outcomes you\'re responsible for. List each one briefly.';
      case QuickVersionState.q4AvoidedDecision:
        return 'Think about conversations you\'ve been putting off or decisions you\'re delaying. '
            'What would happen if you waited another month?';
      case QuickVersionState.q5ComfortWork:
        return 'Tasks that feel productive but don\'t move the needle on your important goals.';
      default:
        if (state.isClarify) {
          return 'Include: Who was involved, What specifically happened, When it occurred, '
              'What was the observable result.';
        }
        return null;
    }
  }
}

/// Indicator showing current question number.
class _QuestionIndicator extends StatelessWidget {
  final int questionNumber;
  final int totalQuestions;
  final String displayName;

  const _QuestionIndicator({
    required this.questionNumber,
    required this.totalQuestions,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Q$questionNumber of $totalQuestions',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Card showing direction evaluation progress for Q3.
class _DirectionProgressCard extends StatelessWidget {
  final IdentifiedProblem problem;
  final int currentSubQuestion;

  const _DirectionProgressCard({
    required this.problem,
    required this.currentSubQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evaluating: ${problem.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ProgressItem(
              label: 'AI cheaper?',
              value: problem.aiCheaper,
              isCurrent: currentSubQuestion == 0,
              isCompleted: problem.aiCheaper != null,
            ),
            const SizedBox(height: 8),
            _ProgressItem(
              label: 'Error cost?',
              value: problem.errorCost,
              isCurrent: currentSubQuestion == 1,
              isCompleted: problem.errorCost != null,
            ),
            const SizedBox(height: 8),
            _ProgressItem(
              label: 'Trust required?',
              value: problem.trustRequired,
              isCurrent: currentSubQuestion == 2,
              isCompleted: problem.trustRequired != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String label;
  final String? value;
  final bool isCurrent;
  final bool isCompleted;

  const _ProgressItem({
    required this.label,
    this.value,
    this.isCurrent = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isCompleted
              ? Icons.check_circle
              : isCurrent
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
          size: 20,
          color: isCompleted
              ? Colors.green
              : isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (isCompleted && value != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '"${value!.length > 40 ? '${value!.substring(0, 40)}...' : value}"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
