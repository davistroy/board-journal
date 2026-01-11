import 'package:flutter/material.dart';

import '../../../data/data.dart';
import '../../../services/governance/setup_state.dart';

/// Widget for previewing and editing a board member persona.
///
/// Per PRD Section 3.3.5:
/// - Name (1-50 characters)
/// - Background (10-300 characters)
/// - Communication style (10-200 characters)
/// - Signature phrase (0-100 characters, optional)
class PersonaPreviewView extends StatefulWidget {
  /// The board member to preview/edit.
  final SetupBoardMember member;

  /// Called when persona is saved.
  final void Function({
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) onSave;

  /// Called when dialog is cancelled.
  final VoidCallback onCancel;

  const PersonaPreviewView({
    super.key,
    required this.member,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<PersonaPreviewView> createState() => _PersonaPreviewViewState();
}

class _PersonaPreviewViewState extends State<PersonaPreviewView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _backgroundController;
  late final TextEditingController _styleController;
  late final TextEditingController _phraseController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.personaName);
    _backgroundController =
        TextEditingController(text: widget.member.personaBackground);
    _styleController =
        TextEditingController(text: widget.member.personaCommunicationStyle);
    _phraseController =
        TextEditingController(text: widget.member.personaSignaturePhrase ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backgroundController.dispose();
    _styleController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSave(
      name: _nameController.text.trim(),
      background: _backgroundController.text.trim(),
      communicationStyle: _styleController.text.trim(),
      signaturePhrase: _phraseController.text.trim().isEmpty
          ? null
          : _phraseController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Persona',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        widget.member.roleType.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Role info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                          'Role Function',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.member.roleType.function,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Signature: "${widget.member.roleType.signatureQuestion}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                if (value.trim().length < 1) {
                  return 'Name must be at least 1 character';
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

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog wrapper for persona preview.
class PersonaEditDialog extends StatelessWidget {
  final SetupBoardMember member;
  final void Function({
    String? name,
    String? background,
    String? communicationStyle,
    String? signaturePhrase,
  }) onSave;

  const PersonaEditDialog({
    super.key,
    required this.member,
    required this.onSave,
  });

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
        ),
        body: PersonaPreviewView(
          member: member,
          onSave: (
              {name, background, communicationStyle, signaturePhrase}) {
            onSave(
              name: name,
              background: background,
              communicationStyle: communicationStyle,
              signaturePhrase: signaturePhrase,
            );
            Navigator.of(context).pop();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
