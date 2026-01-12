import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/data.dart';
import '../../../../router/router.dart';

/// Bottom sheet showing full details of a board member.
class BoardMemberDetailSheet extends StatelessWidget {
  final BoardMember member;
  final Problem? anchoredProblem;

  const BoardMemberDetailSheet({
    super.key,
    required this.member,
    required this.anchoredProblem,
  });

  @override
  Widget build(BuildContext context) {
    final roleType = _parseRoleType(member.roleType);
    final isInactive = member.isGrowthRole && !member.isActive;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              _buildHeader(context, roleType, isInactive),

              const SizedBox(height: 24),

              // Role function
              _buildSection(
                context,
                icon: Icons.work_outline,
                title: 'Role Function',
                content: roleType?.function ?? 'Unknown function',
              ),

              // Interaction style
              _buildSection(
                context,
                icon: Icons.chat_bubble_outline,
                title: 'Interaction Style',
                content: roleType?.interactionStyle ?? 'Unknown style',
              ),

              // Signature question
              _buildSection(
                context,
                icon: Icons.format_quote,
                title: 'Signature Question',
                content: '"${roleType?.signatureQuestion ?? 'Unknown question'}"',
                isQuote: true,
              ),

              // Inactive notice
              if (isInactive) _buildInactiveNotice(context),

              // Anchored problem
              if (anchoredProblem != null) ...[
                _buildSection(
                  context,
                  icon: Icons.link,
                  title: 'Anchored Problem',
                  content: anchoredProblem!.name,
                ),
                if (member.anchoredDemand != null)
                  _buildSection(
                    context,
                    icon: Icons.record_voice_over,
                    title: 'Anchored Demand',
                    content: member.anchoredDemand!,
                  ),
              ],

              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              // Persona details
              Text(
                'Persona Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              _buildSection(
                context,
                icon: Icons.person_outline,
                title: 'Background',
                content: member.personaBackground,
              ),

              _buildSection(
                context,
                icon: Icons.record_voice_over_outlined,
                title: 'Communication Style',
                content: member.personaCommunicationStyle,
              ),

              if (member.personaSignaturePhrase != null &&
                  member.personaSignaturePhrase!.isNotEmpty)
                _buildSection(
                  context,
                  icon: Icons.format_quote,
                  title: 'Signature Phrase',
                  content: '"${member.personaSignaturePhrase}"',
                  isQuote: true,
                ),

              const SizedBox(height: 24),

              // Edit button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(AppRoutes.personaEditor);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Persona'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BoardRoleType? roleType, bool isInactive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: member.isGrowthRole
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            member.personaName.isNotEmpty
                ? member.personaName.substring(0, 1).toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: member.isGrowthRole
                  ? Theme.of(context).colorScheme.onTertiaryContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.personaName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (member.isGrowthRole
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.primary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roleType?.displayName ?? member.roleType,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: member.isGrowthRole
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  if (member.isGrowthRole) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isInactive
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isInactive ? 'Inactive' : 'Growth Role',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isInactive
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInactiveNotice(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This growth role is inactive because there are no appreciating problems in your portfolio.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    bool isQuote = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: isQuote ? FontStyle.italic : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoardRoleType? _parseRoleType(String roleTypeStr) {
    try {
      return BoardRoleType.values.firstWhere((r) => r.name == roleTypeStr);
    } catch (_) {
      return null;
    }
  }
}
