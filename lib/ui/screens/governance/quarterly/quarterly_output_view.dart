import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../services/services.dart';

/// View for displaying the final quarterly report.
class QuarterlyOutputView extends StatelessWidget {
  final String outputMarkdown;
  final BetEvaluation? betEvaluation;
  final NewBet? newBet;
  final String? createdBetId;

  const QuarterlyOutputView({
    super.key,
    required this.outputMarkdown,
    this.betEvaluation,
    this.newBet,
    this.createdBetId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSuccessBanner(context),
          const SizedBox(height: 24),
          _buildSummaryCards(context),
          const SizedBox(height: 24),
          _buildReportSection(context),
          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quarterly Report Complete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your report has been generated and saved.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Row(
      children: [
        if (betEvaluation != null)
          Expanded(
            child: _buildSummaryCard(
              context,
              title: 'Previous Bet',
              value: betEvaluation!.status.displayName.toUpperCase(),
              color: _getBetStatusColor(betEvaluation!.status),
              icon: _getBetStatusIcon(betEvaluation!.status),
            ),
          ),
        if (betEvaluation != null && newBet != null) const SizedBox(width: 12),
        if (newBet != null)
          Expanded(
            child: _buildSummaryCard(
              context,
              title: 'New Bet',
              value: 'Created',
              color: Colors.blue,
              icon: Icons.casino,
              subtitle: '${newBet!.durationDays} days',
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Color _getBetStatusColor(BetStatus status) {
    switch (status) {
      case BetStatus.correct:
        return Colors.green;
      case BetStatus.wrong:
        return Colors.red;
      case BetStatus.expired:
        return Colors.orange;
      case BetStatus.open:
        return Colors.blue;
    }
  }

  IconData _getBetStatusIcon(BetStatus status) {
    switch (status) {
      case BetStatus.correct:
        return Icons.check_circle;
      case BetStatus.wrong:
        return Icons.cancel;
      case BetStatus.expired:
        return Icons.hourglass_disabled;
      case BetStatus.open:
        return Icons.pending;
    }
  }

  Widget _buildReportSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Full Report',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                  onPressed: () => _copyToClipboard(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildMarkdownContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context) {
    // Simple markdown rendering
    final lines = outputMarkdown.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            line.substring(2),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            line.substring(3),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(4),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\u2022 '),
              Expanded(
                child: Text(line.substring(2)),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('**') && line.endsWith('**')) {
        widgets.add(Text(
          line.substring(2, line.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (line.isNotEmpty) {
        widgets.add(Text(line));
      } else {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _shareReport(context),
            icon: const Icon(Icons.share),
            label: const Text('Share Report'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: outputMarkdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareReport(BuildContext context) {
    Share.share(outputMarkdown, subject: 'Quarterly Report');
  }
}
