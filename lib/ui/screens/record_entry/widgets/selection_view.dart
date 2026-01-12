import 'package:flutter/material.dart';

/// Mode selection view with voice and text options.
class SelectionView extends StatelessWidget {
  const SelectionView({
    super.key,
    required this.onVoicePressed,
    required this.onTextPressed,
  });

  final VoidCallback onVoicePressed;
  final VoidCallback onTextPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('selection'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voice recording button
            FilledButton.icon(
              onPressed: onVoicePressed,
              icon: const Icon(Icons.mic),
              label: const Text('Record Voice'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
            const SizedBox(height: 16),
            // Text entry button
            OutlinedButton.icon(
              onPressed: onTextPressed,
              icon: const Icon(Icons.edit),
              label: const Text('Type Instead'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Just talk about your day.\nWe\'ll extract the important signals.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
