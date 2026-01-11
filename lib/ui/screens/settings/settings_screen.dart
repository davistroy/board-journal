import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/repository_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../router/router.dart';

/// Settings screen with account, privacy, data, and board options.
///
/// Per PRD Section 5.9:
/// - Account: OAuth providers, sessions, delete account
/// - Privacy: Abstraction mode, analytics
/// - Data: Export/import, delete all
/// - Board: View/edit personas
/// - Portfolio: Version history, edit problems, re-setup triggers
/// - About: Version, terms, privacy, support
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final abstractionModeAsync = ref.watch(abstractionModeNotifierProvider);
    final analyticsAsync = ref.watch(analyticsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: ListView(
        children: [
          // ==================
          // Account Section
          // ==================
          _SettingsSection(
            title: 'Account',
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Sign-in Methods'),
                subtitle: const Text('Manage linked accounts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Sign-in methods'),
              ),
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('Active Sessions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Active sessions'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: const Text('7-day grace period'),
                onTap: () => _showComingSoon(context, 'Delete account'),
              ),
            ],
          ),

          // ==================
          // Privacy Section
          // ==================
          _SettingsSection(
            title: 'Privacy',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Abstraction Mode'),
                subtitle: const Text('Replace names with placeholders'),
                value: abstractionModeAsync.valueOrNull ?? false,
                onChanged: (value) {
                  ref.read(abstractionModeNotifierProvider.notifier).setEnabled(value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.analytics_outlined),
                title: const Text('Analytics'),
                subtitle: const Text('Help improve the app'),
                value: analyticsAsync.valueOrNull ?? true,
                onChanged: (value) {
                  ref.read(analyticsNotifierProvider.notifier).setEnabled(value);
                },
              ),
            ],
          ),

          // ==================
          // Data Section
          // ==================
          _SettingsSection(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export All Data'),
                subtitle: const Text('Download as JSON'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Export data'),
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Import Data'),
                subtitle: const Text('Restore from backup'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Import data'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete All Data',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _showDeleteAllDataDialog(),
              ),
            ],
          ),

          // ==================
          // Board Section
          // ==================
          _SettingsSection(
            title: 'Board',
            children: [
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Board Personas'),
                subtitle: const Text('Customize your board members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.personaEditor),
              ),
            ],
          ),

          // ==================
          // Portfolio Section
          // ==================
          _SettingsSection(
            title: 'Portfolio',
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Problems'),
                subtitle: const Text('Modify descriptions and allocations'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.portfolioEditor),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Version History'),
                subtitle: const Text('View and compare past versions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.versionHistory),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Re-Setup Triggers'),
                subtitle: const Text('View trigger conditions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showTriggersDialog(),
              ),
            ],
          ),

          // ==================
          // About Section
          // ==================
          _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version'),
                trailing: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showComingSoon(context, 'Terms of service'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showComingSoon(context, 'Privacy policy'),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Send Feedback'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showComingSoon(context, 'Send feedback'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Boardroom Journal',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  Future<void> _showDeleteAllDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete all your data including:',
            ),
            const SizedBox(height: 12),
            const Text('- Daily journal entries'),
            const Text('- Weekly briefs'),
            const Text('- Portfolio and problems'),
            const Text('- Board members and personas'),
            const Text('- Governance sessions'),
            const Text('- Bets and evidence'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show second confirmation
      final doubleConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: const Text(
            'Type "DELETE" to confirm you want to permanently erase all data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            _DeleteConfirmButton(
              onConfirm: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (doubleConfirmed == true && mounted) {
        await ref.read(dataManagementNotifierProvider.notifier).deleteAllData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data deleted')),
          );
          context.go(AppRoutes.home);
        }
      }
    }
  }

  Future<void> _showTriggersDialog() async {
    final triggersAsync = ref.read(allTriggersProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                          'Re-Setup Triggers',
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
                  child: triggersAsync.when(
                    data: (triggers) {
                      if (triggers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              const Text('No triggers configured'),
                              const SizedBox(height: 8),
                              Text(
                                'Triggers are created during Setup',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: triggers.length,
                        itemBuilder: (context, index) {
                          final trigger = triggers[index];
                          return _TriggerCard(trigger: trigger);
                        },
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
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _DeleteConfirmButton extends StatefulWidget {
  final VoidCallback onConfirm;

  const _DeleteConfirmButton({required this.onConfirm});

  @override
  State<_DeleteConfirmButton> createState() => _DeleteConfirmButtonState();
}

class _DeleteConfirmButtonState extends State<_DeleteConfirmButton> {
  final _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _canConfirm = _controller.text.toUpperCase() == 'DELETE';
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _canConfirm ? widget.onConfirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _TriggerCard extends StatelessWidget {
  final dynamic trigger;

  const _TriggerCard({required this.trigger});

  @override
  Widget build(BuildContext context) {
    final isMet = trigger.isMet as bool? ?? false;
    final triggerType = trigger.triggerType as String? ?? 'unknown';
    final description = trigger.description as String? ?? '';
    final condition = trigger.condition as String? ?? '';
    final recommendedAction = trigger.recommendedAction as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isMet ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isMet ? Icons.warning : Icons.flag_outlined,
                  color: isMet
                      ? Theme.of(context).colorScheme.onErrorContainer
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isMet
                              ? Theme.of(context).colorScheme.onErrorContainer
                              : null,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMet ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMet ? 'Met' : 'Active',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${_formatTriggerType(triggerType)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              'Condition: $condition',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              'Action: ${_formatAction(recommendedAction)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTriggerType(String type) {
    switch (type) {
      case 'role_change':
        return 'Role Change';
      case 'scope_change':
        return 'Scope Change';
      case 'direction_shift':
        return 'Direction Shift';
      case 'time_drift':
        return 'Time Drift';
      case 'annual':
        return 'Annual Review';
      default:
        return type;
    }
  }

  String _formatAction(String action) {
    switch (action) {
      case 'full_resetup':
        return 'Full Re-Setup';
      case 'update_problem':
        return 'Update Problem';
      case 'review_health':
        return 'Review Portfolio Health';
      default:
        return action;
    }
  }
}
