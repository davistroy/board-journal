import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/router.dart';

/// Settings screen with account, privacy, data, and board options.
///
/// Per PRD Section 5.9:
/// - Account: OAuth providers, sessions, delete account
/// - Privacy: Abstraction mode, audio retention, analytics
/// - Data: Export/import, delete all
/// - Board: View/edit personas
/// - Portfolio: Version history, edit problems
/// - About: Version, terms, privacy, support
///
/// This is a scaffold - full implementation pending.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                onTap: () => _showComingSoon(context, 'Delete account'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Privacy',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Abstraction Mode'),
                subtitle: const Text('Replace names with placeholders'),
                value: false,
                onChanged: (value) => _showComingSoon(context, 'Abstraction mode'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.analytics_outlined),
                title: const Text('Analytics'),
                subtitle: const Text('Help improve the app'),
                value: true,
                onChanged: (value) => _showComingSoon(context, 'Analytics'),
              ),
            ],
          ),
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
                onTap: () => _showComingSoon(context, 'Delete all data'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Board',
            children: [
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Board Personas'),
                subtitle: const Text('Customize your board members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Board personas'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Portfolio',
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Version History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Version history'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Re-Setup Triggers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showComingSoon(context, 'Re-setup triggers'),
              ),
            ],
          ),
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
                onTap: () => showLicensePage(context: context),
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
