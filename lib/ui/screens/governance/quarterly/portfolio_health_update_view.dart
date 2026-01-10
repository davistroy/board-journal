import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/providers.dart';
import '../../../../services/services.dart';

/// View for portfolio health trend analysis (Q6).
class PortfolioHealthUpdateView extends ConsumerWidget {
  final HealthTrend? healthTrend;
  final VoidCallback onContinue;

  const PortfolioHealthUpdateView({
    super.key,
    required this.healthTrend,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quarterlySessionProvider);

    if (healthTrend == null && !state.isProcessing) {
      // Need to calculate health trend
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(quarterlySessionProvider.notifier).calculateHealthTrend();
      });
    }

    if (state.isProcessing || healthTrend == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing portfolio health trend...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Health Update',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'How your portfolio composition has changed this quarter.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildTrendCards(context, healthTrend!),
          const SizedBox(height: 24),
          _buildVisualComparison(context, healthTrend!),
          if (healthTrend!.trendDescription != null) ...[
            const SizedBox(height: 24),
            _buildTrendInsight(context, healthTrend!.trendDescription!),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // The state machine will auto-advance after health trend is calculated
              },
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCards(BuildContext context, HealthTrend trend) {
    return Row(
      children: [
        Expanded(
          child: _buildTrendCard(
            context,
            title: 'Appreciating',
            previous: trend.previousAppreciating,
            current: trend.currentAppreciating,
            change: trend.appreciatingChange,
            color: Colors.green,
            isPositiveGood: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTrendCard(
            context,
            title: 'Depreciating',
            previous: trend.previousDepreciating,
            current: trend.currentDepreciating,
            change: trend.depreciatingChange,
            color: Colors.red,
            isPositiveGood: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTrendCard(
            context,
            title: 'Stable',
            previous: trend.previousStable,
            current: trend.currentStable,
            change: trend.stableChange,
            color: Colors.grey,
            isPositiveGood: false, // Neutral
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard(
    BuildContext context, {
    required String title,
    required int previous,
    required int current,
    required int change,
    required Color color,
    required bool isPositiveGood,
  }) {
    final isGood = isPositiveGood ? change > 0 : change < 0;
    final isBad = isPositiveGood ? change < 0 : change > 0;
    final changeColor = change == 0
        ? Colors.grey
        : (isGood ? Colors.green : (isBad ? Colors.red : Colors.orange));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$current%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  change > 0
                      ? Icons.trending_up
                      : (change < 0 ? Icons.trending_down : Icons.trending_flat),
                  size: 16,
                  color: changeColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${change >= 0 ? '+' : ''}$change%',
                  style: TextStyle(
                    color: changeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'from $previous%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualComparison(BuildContext context, HealthTrend trend) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comparison',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildComparisonBar(
              context,
              label: 'Previous Quarter',
              appreciating: trend.previousAppreciating,
              depreciating: trend.previousDepreciating,
              stable: trend.previousStable,
            ),
            const SizedBox(height: 12),
            _buildComparisonBar(
              context,
              label: 'Current Quarter',
              appreciating: trend.currentAppreciating,
              depreciating: trend.currentDepreciating,
              stable: trend.currentStable,
            ),
            const SizedBox(height: 16),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonBar(
    BuildContext context, {
    required String label,
    required int appreciating,
    required int depreciating,
    required int stable,
  }) {
    final total = appreciating + depreciating + stable;
    if (total == 0) {
      return Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(
            child: LinearProgressIndicator(value: 0),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  if (appreciating > 0)
                    Expanded(
                      flex: appreciating,
                      child: Container(color: Colors.green),
                    ),
                  if (stable > 0)
                    Expanded(
                      flex: stable,
                      child: Container(color: Colors.grey),
                    ),
                  if (depreciating > 0)
                    Expanded(
                      flex: depreciating,
                      child: Container(color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(context, 'Appreciating', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem(context, 'Stable', Colors.grey),
        const SizedBox(width: 16),
        _buildLegendItem(context, 'Depreciating', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildTrendInsight(BuildContext context, String description) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trend Insight',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
}
