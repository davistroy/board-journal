import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/services.dart';

/// Widget for displaying the completed Quick Version audit output.
///
/// Shows:
/// - Assessment
/// - Problem direction table
/// - Avoided decision
/// - 90-day bet
/// - Export options
class QuickVersionOutputView extends StatelessWidget {
  /// The completed session data.
  final QuickVersionSessionData sessionData;

  /// Called when user is done viewing.
  final VoidCallback onDone;

  const QuickVersionOutputView({
    super.key,
    required this.sessionData,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Your 15-minute audit has been saved',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Assessment section
          if (sessionData.assessment != null &&
              sessionData.assessment!.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.psychology,
              title: 'Honest Assessment',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  sessionData.assessment!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Problem directions
          if (sessionData.problems.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.trending_up,
              title: 'Problem Directions',
            ),
            const SizedBox(height: 12),
            _ProblemDirectionsTable(problems: sessionData.problems),
            const SizedBox(height: 24),
          ],

          // Avoided decision
          if (sessionData.avoidedDecision != null &&
              sessionData.avoidedDecision!.isNotEmpty &&
              sessionData.avoidedDecision!.toLowerCase() != 'none') ...[
            _SectionHeader(
              icon: Icons.warning_amber,
              title: 'Avoided Decision',
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionData.avoidedDecision!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (sessionData.avoidedDecisionCost != null &&
                        sessionData.avoidedDecisionCost!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Cost: ${sessionData.avoidedDecisionCost}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Comfort work
          if (sessionData.comfortWork != null &&
              sessionData.comfortWork!.isNotEmpty &&
              sessionData.comfortWork!.toLowerCase() != 'none') ...[
            _SectionHeader(
              icon: Icons.hourglass_empty,
              title: 'Comfort Work',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  sessionData.comfortWork!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 90-day bet
          if (sessionData.betPrediction != null &&
              sessionData.betPrediction!.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.casino,
              title: '90-Day Bet',
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sessionData.betPrediction!,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (sessionData.betWrongIf != null &&
                        sessionData.betWrongIf!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.not_interested,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Wrong if: ${sessionData.betWrongIf}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontStyle: FontStyle.italic,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'This bet will expire in 90 days. You\'ll be prompted to evaluate it.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Export buttons
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _shareMarkdown(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  String _generateMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# 15-Minute Audit Results');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toIso8601String().split('T')[0]}');
    buffer.writeln();

    if (sessionData.assessment != null && sessionData.assessment!.isNotEmpty) {
      buffer.writeln('## Honest Assessment');
      buffer.writeln();
      buffer.writeln(sessionData.assessment);
      buffer.writeln();
    }

    if (sessionData.problems.isNotEmpty) {
      buffer.writeln('## Problem Directions');
      buffer.writeln();
      buffer.writeln('| Problem | AI cheaper? | Error cost? | Trust required? | Direction |');
      buffer.writeln('|---------|-------------|-------------|-----------------|-----------|');
      for (final problem in sessionData.problems) {
        buffer.writeln(
          '| ${problem.name} | ${problem.aiCheaper ?? "-"} | '
          '${problem.errorCost ?? "-"} | ${problem.trustRequired ?? "-"} | '
          '${problem.direction?.displayName ?? "-"} |',
        );
      }
      buffer.writeln();
    }

    if (sessionData.avoidedDecision != null &&
        sessionData.avoidedDecision!.isNotEmpty &&
        sessionData.avoidedDecision!.toLowerCase() != 'none') {
      buffer.writeln('## Avoided Decision');
      buffer.writeln();
      buffer.writeln('**What:** ${sessionData.avoidedDecision}');
      if (sessionData.avoidedDecisionCost != null) {
        buffer.writeln('**Cost:** ${sessionData.avoidedDecisionCost}');
      }
      buffer.writeln();
    }

    if (sessionData.comfortWork != null &&
        sessionData.comfortWork!.isNotEmpty &&
        sessionData.comfortWork!.toLowerCase() != 'none') {
      buffer.writeln('## Comfort Work');
      buffer.writeln();
      buffer.writeln(sessionData.comfortWork);
      buffer.writeln();
    }

    if (sessionData.betPrediction != null &&
        sessionData.betPrediction!.isNotEmpty) {
      buffer.writeln('## 90-Day Bet');
      buffer.writeln();
      buffer.writeln('**Prediction:** ${sessionData.betPrediction}');
      if (sessionData.betWrongIf != null) {
        buffer.writeln('**Wrong if:** ${sessionData.betWrongIf}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    final markdown = _generateMarkdown();
    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareMarkdown(BuildContext context) {
    final markdown = _generateMarkdown();
    Share.share(markdown, subject: '15-Minute Audit Results');
  }
}

/// Section header with icon.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

/// Table showing problem directions.
class _ProblemDirectionsTable extends StatelessWidget {
  final List<IdentifiedProblem> problems;

  const _ProblemDirectionsTable({required this.problems});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Problem')),
            DataColumn(label: Text('Direction')),
          ],
          rows: problems.map((problem) {
            final direction = problem.direction;
            final color = direction == ProblemDirection.appreciating
                ? Colors.green
                : direction == ProblemDirection.depreciating
                    ? Colors.red
                    : Colors.grey;

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      problem.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          direction == ProblemDirection.appreciating
                              ? Icons.trending_up
                              : direction == ProblemDirection.depreciating
                                  ? Icons.trending_down
                                  : Icons.trending_flat,
                          size: 16,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          direction?.displayName ?? 'Unknown',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
