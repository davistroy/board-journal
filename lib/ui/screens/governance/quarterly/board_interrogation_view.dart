import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/data.dart';
import '../../../../providers/providers.dart';
import '../../../../services/services.dart';

/// View for board member interrogation.
class BoardInterrogationView extends ConsumerStatefulWidget {
  final BoardMember? currentMember;
  final String? currentQuestion;
  final bool isClarify;
  final bool canSkip;
  final bool isGrowthPhase;
  final List<BoardInterrogationResponse> coreBoardResponses;
  final List<BoardInterrogationResponse> growthBoardResponses;

  const BoardInterrogationView({
    super.key,
    required this.currentMember,
    required this.currentQuestion,
    required this.isClarify,
    required this.canSkip,
    required this.isGrowthPhase,
    required this.coreBoardResponses,
    required this.growthBoardResponses,
  });

  @override
  ConsumerState<BoardInterrogationView> createState() =>
      _BoardInterrogationViewState();
}

class _BoardInterrogationViewState
    extends ConsumerState<BoardInterrogationView> {
  final _controller = TextEditingController();

  BoardRoleType _getRoleType(BoardMember member) {
    return BoardRoleType.values.firstWhere(
      (r) => r.name == member.roleType,
      orElse: () => BoardRoleType.accountability,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quarterlySessionProvider);

    if (widget.currentMember == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading board member...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(context),
          const SizedBox(height: 24),
          _buildMemberCard(context, widget.currentMember!),
          const SizedBox(height: 24),
          if (widget.isClarify)
            _buildClarifyPrompt(context)
          else
            _buildQuestionSection(context),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: widget.isClarify
                  ? 'Provide a concrete example (who/what/when/result)...'
                  : 'Your response to ${widget.currentMember!.personaName}...',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.isClarify && widget.canSkip)
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isProcessing
                        ? null
                        : () {
                            ref
                                .read(quarterlySessionProvider.notifier)
                                .skipBoardClarification();
                          },
                    child: Text(
                        'Skip (${2 - state.data.vaguenessSkipCount} left)'),
                  ),
                ),
              if (widget.isClarify && widget.canSkip) const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.isProcessing ||
                          _controller.text.trim().isEmpty
                      ? null
                      : () => _submit(),
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
          const SizedBox(height: 24),
          _buildPreviousResponses(context),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final coreCount = widget.coreBoardResponses.length;
    final growthCount = widget.growthBoardResponses.length;
    final totalCore = 5;
    final totalGrowth = widget.isGrowthPhase ? 2 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isGrowthPhase ? 'Growth Board' : 'Core Board',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Core: $coreCount/$totalCore',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: coreCount / totalCore,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth: $growthCount/$totalGrowth',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: totalGrowth > 0 ? growthCount / totalGrowth : 0,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberCard(BuildContext context, BoardMember member) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: member.isGrowthRole
                  ? Colors.purple.withOpacity(0.2)
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                member.personaName.substring(0, 1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: member.isGrowthRole
                      ? Colors.purple
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.personaName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: member.isGrowthRole
                              ? Colors.purple.withOpacity(0.2)
                              : Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleType(member).displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: member.isGrowthRole
                                ? Colors.purple
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (member.personaBackground != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      member.personaBackground!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _getRoleType(member).function,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.currentMember!.personaName} asks:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.currentQuestion ?? _getRoleType(widget.currentMember!).signatureQuestion,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
        if (widget.currentMember!.anchoredDemand != null) ...[
          const SizedBox(height: 8),
          Text(
            'Focus: ${widget.currentMember!.anchoredDemand}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildClarifyPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Clarification Needed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your response was vague. Please provide a concrete example with specifics:\n'
            '- Who was involved?\n'
            '- What happened?\n'
            '- When did it occur?\n'
            '- What was the result?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousResponses(BuildContext context) {
    final responses = [
      ...widget.coreBoardResponses,
      ...widget.growthBoardResponses,
    ];

    if (responses.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: Text(
        'Previous Responses (${responses.length})',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: responses.map((response) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      response.personaName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: response.roleType.isGrowthRole
                            ? Colors.purple.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        response.roleType.displayName,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    if (response.wasVague) ...[
                      const SizedBox(width: 8),
                      Icon(
                        response.skipped ? Icons.skip_next : Icons.info,
                        size: 14,
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Q: ${response.question}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A: ${response.response}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (response.concreteExample != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Example: ${response.concreteExample}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
                        ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _submit() {
    final notifier = ref.read(quarterlySessionProvider.notifier);

    if (widget.isClarify) {
      notifier.processBoardClarification(_controller.text.trim());
    } else {
      notifier.processBoardResponse(_controller.text.trim());
    }

    _controller.clear();
  }
}
