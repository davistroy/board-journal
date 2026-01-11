import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/data.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../router/router.dart';

/// Screen for viewing and editing board personas.
///
/// Per PRD Section 5.9:
/// - View all board personas
/// - Edit persona (name, background, style, phrase)
/// - Reset individual persona to default
/// - Reset all personas to defaults
class PersonaEditorScreen extends ConsumerStatefulWidget {
  const PersonaEditorScreen({super.key});

  @override
  ConsumerState<PersonaEditorScreen> createState() => _PersonaEditorScreenState();
}

class _PersonaEditorScreenState extends ConsumerState<PersonaEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final boardMembersAsync = ref.watch(boardMembersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Personas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.settings),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset_all') {
                _showResetAllDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset_all',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt),
                    SizedBox(width: 8),
                    Text('Reset All Personas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: boardMembersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return _buildEmptyState();
          }

          // Sort: core roles first, then growth roles
          final sortedMembers = List<BoardMember>.from(members)
            ..sort((a, b) {
              if (a.isGrowthRole != b.isGrowthRole) {
                return a.isGrowthRole ? 1 : -1;
              }
              return a.roleType.compareTo(b.roleType);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedMembers.length,
            itemBuilder: (context, index) {
              final member = sortedMembers[index];

              // Add section headers
              if (index == 0 ||
                  (sortedMembers[index - 1].isGrowthRole != member.isGrowthRole)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) const SizedBox(height: 16),
                    _SectionHeader(
                      title: member.isGrowthRole ? 'Growth Roles' : 'Core Roles',
                      subtitle: member.isGrowthRole
                          ? 'Active when appreciating problems exist'
                          : 'Always active',
                    ),
                    const SizedBox(height: 8),
                    _PersonaCard(member: member),
                  ],
                );
              }

              return _PersonaCard(member: member);
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
              Text('Error loading personas: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(boardMembersStreamProvider),
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
            Icons.groups_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No Board Members',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete Setup to create your board.',
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

  Future<void> _showResetAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Personas?'),
        content: const Text(
          'This will restore all board member personas to their original AI-generated values. '
          'Any customizations you\'ve made will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(boardPersonaNotifierProvider.notifier).resetAllPersonas();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All personas reset to defaults')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends ConsumerWidget {
  final BoardMember member;

  const _PersonaCard({required this.member});

  BoardRoleType get roleType {
    return BoardRoleType.values.firstWhere(
      (r) => r.name == member.roleType,
      orElse: () => BoardRoleType.accountability,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditDialog(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: member.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      member.personaName.isNotEmpty
                          ? member.personaName.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: member.isActive
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                member.personaName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (!member.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Inactive',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          roleType.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                member.personaBackground,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (member.personaSignaturePhrase?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  '"${member.personaSignaturePhrase}"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => _PersonaEditDialog(member: member),
    );
  }
}

class _PersonaEditDialog extends ConsumerStatefulWidget {
  final BoardMember member;

  const _PersonaEditDialog({required this.member});

  @override
  ConsumerState<_PersonaEditDialog> createState() => _PersonaEditDialogState();
}

class _PersonaEditDialogState extends ConsumerState<_PersonaEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _backgroundController;
  late final TextEditingController _styleController;
  late final TextEditingController _phraseController;

  BoardRoleType get roleType {
    return BoardRoleType.values.firstWhere(
      (r) => r.name == widget.member.roleType,
      orElse: () => BoardRoleType.accountability,
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.personaName);
    _backgroundController = TextEditingController(text: widget.member.personaBackground);
    _styleController = TextEditingController(text: widget.member.personaCommunicationStyle);
    _phraseController = TextEditingController(text: widget.member.personaSignaturePhrase ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backgroundController.dispose();
    _styleController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(boardPersonaNotifierProvider.notifier).updatePersona(
          widget.member.id,
          name: _nameController.text.trim(),
          background: _backgroundController.text.trim(),
          communicationStyle: _styleController.text.trim(),
          signaturePhrase: _phraseController.text.trim().isEmpty
              ? null
              : _phraseController.text.trim(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona updated')),
      );
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Persona?'),
        content: Text(
          'This will restore ${widget.member.personaName}\'s persona to the original AI-generated values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(boardPersonaNotifierProvider.notifier).resetPersona(widget.member.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persona reset to default')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Persona'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: _reset,
              child: const Text('Reset'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Role info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            roleType.displayName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        roleType.function,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Signature: "${roleType.signatureQuestion}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Name field
              Text(
                'Persona Name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Maya Chen',
                  border: OutlineInputBorder(),
                  helperText: '1-50 characters',
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Background field
              Text(
                'Background',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _backgroundController,
                decoration: const InputDecoration(
                  hintText: 'Brief professional history...',
                  border: OutlineInputBorder(),
                  helperText: '10-300 characters',
                ),
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Background is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Background must be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Communication style field
              Text(
                'Communication Style',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _styleController,
                decoration: const InputDecoration(
                  hintText: 'How they communicate...',
                  border: OutlineInputBorder(),
                  helperText: '10-200 characters',
                ),
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Communication style is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Communication style must be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Signature phrase field
              Text(
                'Signature Phrase (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phraseController,
                decoration: const InputDecoration(
                  hintText: 'A catchphrase or common opening...',
                  border: OutlineInputBorder(),
                  helperText: '0-100 characters',
                ),
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 32),

              // Save button
              FilledButton(
                onPressed: _save,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
