import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';

/// View for creating a new bet (Q10).
class NextBetView extends ConsumerStatefulWidget {
  const NextBetView({super.key});

  @override
  ConsumerState<NextBetView> createState() => _NextBetViewState();
}

class _NextBetViewState extends ConsumerState<NextBetView> {
  final _predictionController = TextEditingController();
  final _wrongIfController = TextEditingController();
  int _durationDays = 90;

  @override
  void dispose() {
    _predictionController.dispose();
    _wrongIfController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _predictionController.text.trim().isNotEmpty &&
      _wrongIfController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quarterlySessionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your Next Bet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Make a specific, measurable prediction about your career. '
            'You will evaluate this bet in your next quarterly report.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildInfoCard(context),
          const SizedBox(height: 24),
          TextField(
            controller: _predictionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Prediction',
              hintText:
                  'What specific outcome do you predict? Be concrete and measurable.',
              border: OutlineInputBorder(),
              helperText: 'Example: "I will be promoted to Senior Engineer by Q2"',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _wrongIfController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Wrong If',
              hintText:
                  'What would prove this prediction wrong? Be specific.',
              border: OutlineInputBorder(),
              helperText:
                  'Example: "I am still in my current role after April 1st"',
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          _buildDurationSelector(context),
          const SizedBox(height: 24),
          _buildDueDatePreview(context),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !_isValid || state.isProcessing
                  ? null
                  : () => _createBet(),
              child: state.isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Bet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.casino,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'How Bets Work',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              icon: Icons.check_circle_outline,
              text: 'Make a specific, falsifiable prediction',
            ),
            _buildInfoRow(
              context,
              icon: Icons.timer_outlined,
              text: 'Default duration is 90 days',
            ),
            _buildInfoRow(
              context,
              icon: Icons.gavel_outlined,
              text: 'No partial credit - CORRECT, WRONG, or EXPIRED',
            ),
            _buildInfoRow(
              context,
              icon: Icons.alarm_outlined,
              text: 'Auto-expires if not evaluated by due date',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 30,
              label: Text('30 days'),
            ),
            ButtonSegment(
              value: 60,
              label: Text('60 days'),
            ),
            ButtonSegment(
              value: 90,
              label: Text('90 days'),
            ),
          ],
          selected: {_durationDays},
          onSelectionChanged: (values) {
            setState(() {
              _durationDays = values.first;
            });
          },
        ),
        const SizedBox(height: 4),
        Text(
          '90 days is the recommended default for quarterly bets.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  Widget _buildDueDatePreview(BuildContext context) {
    final dueDate = DateTime.now().add(Duration(days: _durationDays));
    final formattedDate =
        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Due Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_durationDays days',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _createBet() {
    ref.read(quarterlySessionProvider.notifier).createNewBet(
          prediction: _predictionController.text.trim(),
          wrongIf: _wrongIfController.text.trim(),
          durationDays: _durationDays,
        );
  }
}
