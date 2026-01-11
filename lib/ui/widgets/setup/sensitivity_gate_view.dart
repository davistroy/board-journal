import 'package:flutter/material.dart';

/// Widget for the sensitivity gate at the start of Setup.
///
/// Per PRD Section 4.4:
/// - Privacy reminder before starting
/// - Option to enable abstraction mode
/// - Remember choice for future sessions
class SensitivityGateView extends StatefulWidget {
  /// Initial abstraction mode value.
  final bool initialAbstractionMode;

  /// Whether the user previously chose to remember their preference.
  final bool rememberedChoice;

  /// Called when user proceeds.
  final void Function({
    required bool abstractionMode,
    required bool rememberChoice,
  }) onProceed;

  const SensitivityGateView({
    super.key,
    this.initialAbstractionMode = false,
    this.rememberedChoice = false,
    required this.onProceed,
  });

  @override
  State<SensitivityGateView> createState() => _SensitivityGateViewState();
}

class _SensitivityGateViewState extends State<SensitivityGateView> {
  late bool _abstractionMode;
  bool _rememberChoice = false;

  @override
  void initState() {
    super.initState();
    _abstractionMode = widget.initialAbstractionMode;
    _rememberChoice = widget.rememberedChoice;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Privacy icon and header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.security,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Privacy First',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Before we begin, let\'s talk about your data.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // What you'll be asked
          _InfoCard(
            icon: Icons.edit_note,
            title: 'What You\'ll Share',
            items: const [
              'Your career problems and challenges',
              'What breaks if problems aren\'t solved',
              'How AI and technology affect your work',
              'Time allocation across your responsibilities',
            ],
          ),

          const SizedBox(height: 16),

          // How it's stored
          _InfoCard(
            icon: Icons.storage,
            title: 'How It\'s Stored',
            items: const [
              'All data stays on your device',
              'Nothing is sent to external servers',
              'You can export or delete anytime',
            ],
          ),

          const SizedBox(height: 24),

          // Abstraction mode option
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Abstraction Mode',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      Switch(
                        value: _abstractionMode,
                        onChanged: (value) {
                          setState(() => _abstractionMode = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When enabled, names and companies in your responses will be replaced with placeholders (e.g., "[COMPANY A]", "[PERSON 1]"). This adds an extra layer of privacy.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Remember choice
          CheckboxListTile(
            value: _rememberChoice,
            onChanged: (value) {
              setState(() => _rememberChoice = value ?? false);
            },
            title: const Text('Remember my choice'),
            subtitle: const Text(
              'Use this setting for future Setup sessions',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 32),

          // Proceed button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onProceed(
                abstractionMode: _abstractionMode,
                rememberChoice: _rememberChoice,
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Begin Setup'),
            ),
          ),

          const SizedBox(height: 16),

          // Time estimate
          Center(
            child: Text(
              'This will take about 15-20 minutes',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
