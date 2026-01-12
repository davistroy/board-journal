import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'text_entry_state.dart';

/// Text entry view with input field and word count.
class TextEntryView extends ConsumerWidget {
  const TextEntryView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(textEntryProvider);

    return Column(
      key: const ValueKey('text'),
      children: [
        // Error banner
        if (state.error != null)
          MaterialBanner(
            content: Text(state.error!),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(textEntryProvider.notifier).updateText(state.text);
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),

        // Word count and limit warning
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: state.isOverLimit
                ? Theme.of(context).colorScheme.errorContainer
                : state.isNearLimit
                    ? Theme.of(context).colorScheme.tertiaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              Icon(
                state.isOverLimit
                    ? Icons.warning
                    : state.isNearLimit
                        ? Icons.info_outline
                        : Icons.edit_note,
                size: 16,
                color: state.isOverLimit
                    ? Theme.of(context).colorScheme.error
                    : state.isNearLimit
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${state.wordCount} words',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: state.isOverLimit
                          ? Theme.of(context).colorScheme.error
                          : state.isNearLimit
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (state.isNearLimit || state.isOverLimit) ...[
                const Spacer(),
                Text(
                  state.isOverLimit
                      ? 'Over 7,500 word limit'
                      : 'Approaching limit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: state.isOverLimit
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                ),
              ],
            ],
          ),
        ),

        // Text input
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'What happened today? What\'s on your mind?\n\n'
                    'Write about wins, blockers, risks, decisions you\'re '
                    'avoiding, work that feels productive but isn\'t moving '
                    'you forward, actions you\'re committing to, or insights '
                    'you\'ve had.',
                hintMaxLines: 6,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),

        // Bottom action bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tip: Just write freely. We\'ll extract signals later.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: state.canSave ? onSave : null,
                  child: state.isSaving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(state.saveStatusText),
                          ],
                        )
                      : const Text('Save Entry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
