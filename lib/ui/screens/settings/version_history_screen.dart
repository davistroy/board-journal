import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/data.dart';
import '../../../providers/settings_providers.dart';
import '../../../router/router.dart';

/// Screen for viewing portfolio version history.
///
/// Per PRD Section 5.9:
/// - List of portfolio versions (date, summary)
/// - Tap to view details
/// - Compare two versions side-by-side
class VersionHistoryScreen extends ConsumerStatefulWidget {
  const VersionHistoryScreen({super.key});

  @override
  ConsumerState<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  final Set<int> _selectedVersions = {};
  bool _isCompareMode = false;

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(allVersionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCompareMode ? 'Select Versions to Compare' : 'Version History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isCompareMode) {
              setState(() {
                _isCompareMode = false;
                _selectedVersions.clear();
              });
            } else {
              context.go(AppRoutes.settings);
            }
          },
        ),
        actions: [
          if (!_isCompareMode)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              tooltip: 'Compare Versions',
              onPressed: () => setState(() => _isCompareMode = true),
            ),
          if (_isCompareMode && _selectedVersions.length == 2)
            FilledButton(
              onPressed: _showComparison,
              child: const Text('Compare'),
            ),
        ],
      ),
      body: versionsAsync.when(
        data: (versions) {
          if (versions.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final version = versions[index];
              final isSelected = _selectedVersions.contains(version.versionNumber);

              return _VersionCard(
                version: version,
                isCompareMode: _isCompareMode,
                isSelected: isSelected,
                onTap: () {
                  if (_isCompareMode) {
                    _toggleSelection(version.versionNumber);
                  } else {
                    _showVersionDetails(version);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading versions: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(allVersionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No Version History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete Setup to create your first portfolio version.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go(AppRoutes.setup),
            child: const Text('Start Setup'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int versionNumber) {
    setState(() {
      if (_selectedVersions.contains(versionNumber)) {
        _selectedVersions.remove(versionNumber);
      } else if (_selectedVersions.length < 2) {
        _selectedVersions.add(versionNumber);
      }
    });
  }

  void _showVersionDetails(PortfolioVersion version) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _VersionDetailsSheet(version: version),
    );
  }

  void _showComparison() {
    if (_selectedVersions.length != 2) return;

    final versions = _selectedVersions.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _VersionComparisonSheet(
        v1: versions[0],
        v2: versions[1],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final PortfolioVersion version;
  final bool isCompareMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _VersionCard({
    required this.version,
    required this.isCompareMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isCompareMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    'v${version.versionNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(version.createdAtUtc.toLocal()),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${timeFormat.format(version.createdAtUtc.toLocal())} - ${version.triggerReason}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _HealthSummary(healthJson: version.healthSnapshotJson),
                  ],
                ),
              ),
              if (!isCompareMode)
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  final String healthJson;

  const _HealthSummary({required this.healthJson});

  @override
  Widget build(BuildContext context) {
    try {
      final health = json.decode(healthJson) as Map<String, dynamic>;
      final appreciating = health['appreciatingPercent'] ?? 0;
      final depreciating = health['depreciatingPercent'] ?? 0;
      final stable = health['stablePercent'] ?? 0;

      return Row(
        children: [
          _HealthChip(
            label: '$appreciating%',
            color: Colors.green,
            icon: Icons.trending_up,
          ),
          const SizedBox(width: 4),
          _HealthChip(
            label: '$depreciating%',
            color: Colors.red,
            icon: Icons.trending_down,
          ),
          const SizedBox(width: 4),
          _HealthChip(
            label: '$stable%',
            color: Colors.grey,
            icon: Icons.trending_flat,
          ),
        ],
      );
    } catch (e) {
      return const Text('Health data unavailable');
    }
  }
}

class _HealthChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _HealthChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionDetailsSheet extends StatelessWidget {
  final PortfolioVersion version;

  const _VersionDetailsSheet({required this.version});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();

    List<dynamic> problems = [];
    Map<String, dynamic> health = {};

    try {
      problems = json.decode(version.problemsSnapshotJson) as List<dynamic>;
      health = json.decode(version.healthSnapshotJson) as Map<String, dynamic>;
    } catch (e) {
      // Handle JSON parse error
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        'v${version.versionNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version ${version.versionNumber}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${dateFormat.format(version.createdAtUtc.toLocal())} at ${timeFormat.format(version.createdAtUtc.toLocal())}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Trigger reason
                    _DetailSection(
                      title: 'Trigger',
                      child: Text(version.triggerReason),
                    ),

                    const SizedBox(height: 16),

                    // Portfolio health
                    _DetailSection(
                      title: 'Portfolio Health',
                      child: Row(
                        children: [
                          Expanded(
                            child: _HealthBar(
                              label: 'Appreciating',
                              percent: health['appreciatingPercent'] ?? 0,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HealthBar(
                              label: 'Depreciating',
                              percent: health['depreciatingPercent'] ?? 0,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HealthBar(
                              label: 'Stable',
                              percent: health['stablePercent'] ?? 0,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Problems
                    _DetailSection(
                      title: 'Problems (${problems.length})',
                      child: Column(
                        children: problems.map((p) {
                          final problem = p as Map<String, dynamic>;
                          return _ProblemTile(
                            name: problem['name'] ?? 'Unknown',
                            direction: problem['direction'] ?? 'stable',
                            allocation: problem['timeAllocationPercent'] ?? 0,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _HealthBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _HealthBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$percent%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent / 100,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _ProblemTile extends StatelessWidget {
  final String name;
  final String direction;
  final int allocation;

  const _ProblemTile({
    required this.name,
    required this.direction,
    required this.allocation,
  });

  Color _getDirectionColor() {
    switch (direction) {
      case 'appreciating':
        return Colors.green;
      case 'depreciating':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getDirectionIcon() {
    switch (direction) {
      case 'appreciating':
        return Icons.trending_up;
      case 'depreciating':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_getDirectionIcon(), color: _getDirectionColor(), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$allocation%',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionComparisonSheet extends ConsumerWidget {
  final int v1;
  final int v2;

  const _VersionComparisonSheet({
    required this.v1,
    required this.v2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(versionComparisonProvider((v1: v1, v2: v2)));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Compare v$v1 vs v$v2',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Content
              Expanded(
                child: comparisonAsync.when(
                  data: (versions) {
                    if (versions.length < 2) {
                      return const Center(child: Text('Could not load versions'));
                    }

                    final version1 = versions[0];
                    final version2 = versions[1];

                    return _ComparisonContent(
                      version1: version1,
                      version2: version2,
                      scrollController: scrollController,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonContent extends StatelessWidget {
  final PortfolioVersion version1;
  final PortfolioVersion version2;
  final ScrollController scrollController;

  const _ComparisonContent({
    required this.version1,
    required this.version2,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    Map<String, dynamic> health1 = {};
    Map<String, dynamic> health2 = {};
    List<dynamic> problems1 = [];
    List<dynamic> problems2 = [];

    try {
      health1 = json.decode(version1.healthSnapshotJson) as Map<String, dynamic>;
      health2 = json.decode(version2.healthSnapshotJson) as Map<String, dynamic>;
      problems1 = json.decode(version1.problemsSnapshotJson) as List<dynamic>;
      problems2 = json.decode(version2.problemsSnapshotJson) as List<dynamic>;
    } catch (e) {
      // Handle JSON parse error
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Version headers
        Row(
          children: [
            Expanded(
              child: _ComparisonHeader(
                version: version1.versionNumber,
                date: dateFormat.format(version1.createdAtUtc.toLocal()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ComparisonHeader(
                version: version2.versionNumber,
                date: dateFormat.format(version2.createdAtUtc.toLocal()),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Health comparison
        Text(
          'Portfolio Health',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),

        _ComparisonRow(
          label: 'Appreciating',
          value1: '${health1['appreciatingPercent'] ?? 0}%',
          value2: '${health2['appreciatingPercent'] ?? 0}%',
          color: Colors.green,
        ),
        _ComparisonRow(
          label: 'Depreciating',
          value1: '${health1['depreciatingPercent'] ?? 0}%',
          value2: '${health2['depreciatingPercent'] ?? 0}%',
          color: Colors.red,
        ),
        _ComparisonRow(
          label: 'Stable',
          value1: '${health1['stablePercent'] ?? 0}%',
          value2: '${health2['stablePercent'] ?? 0}%',
          color: Colors.grey,
        ),

        const SizedBox(height: 24),

        // Problem count
        Text(
          'Problems',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),

        _ComparisonRow(
          label: 'Count',
          value1: '${problems1.length}',
          value2: '${problems2.length}',
        ),

        const SizedBox(height: 16),

        // Problems side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: problems1.map((p) {
                  final problem = p as Map<String, dynamic>;
                  return _ProblemTile(
                    name: problem['name'] ?? 'Unknown',
                    direction: problem['direction'] ?? 'stable',
                    allocation: problem['timeAllocationPercent'] ?? 0,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: problems2.map((p) {
                  final problem = p as Map<String, dynamic>;
                  return _ProblemTile(
                    name: problem['name'] ?? 'Unknown',
                    direction: problem['direction'] ?? 'stable',
                    allocation: problem['timeAllocationPercent'] ?? 0,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  final int version;
  final String date;

  const _ComparisonHeader({
    required this.version,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'v$version',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          Text(
            date,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String value1;
  final String value2;
  final Color? color;

  const _ComparisonRow({
    required this.label,
    required this.value1,
    required this.value2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color?.withOpacity(0.1) ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color?.withOpacity(0.1) ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
