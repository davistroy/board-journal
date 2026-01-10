import 'package:flutter/material.dart';

/// Widget that displays a countdown when silence is detected during recording.
///
/// Per PRD Section 4.1:
/// - 8-second silence timeout
/// - Visual countdown in last 3 seconds
class SilenceCountdownWidget extends StatefulWidget {
  /// Current seconds of continuous silence.
  final int silenceSeconds;

  /// Total silence duration before auto-stop.
  final int silenceTimeout;

  /// How many seconds before timeout to start showing countdown.
  final int countdownStart;

  /// Called when user taps to dismiss/cancel silence stop.
  final VoidCallback? onDismiss;

  const SilenceCountdownWidget({
    super.key,
    required this.silenceSeconds,
    this.silenceTimeout = 8,
    this.countdownStart = 3,
    this.onDismiss,
  });

  @override
  State<SilenceCountdownWidget> createState() => _SilenceCountdownWidgetState();
}

class _SilenceCountdownWidgetState extends State<SilenceCountdownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(SilenceCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pulse animation when countdown number changes
    if (widget.silenceSeconds != oldWidget.silenceSeconds && _shouldShowCountdown) {
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _shouldShowCountdown {
    final remaining = widget.silenceTimeout - widget.silenceSeconds;
    return remaining <= widget.countdownStart && remaining > 0;
  }

  int get _remainingSeconds => widget.silenceTimeout - widget.silenceSeconds;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowCountdown) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.error.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Countdown number with pulse animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_remainingSeconds',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onError,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Message
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Silence detected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tap anywhere to keep recording',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A more prominent fullscreen overlay version of the silence countdown.
class SilenceCountdownOverlay extends StatelessWidget {
  /// Current seconds of continuous silence.
  final int silenceSeconds;

  /// Total silence duration before auto-stop.
  final int silenceTimeout;

  /// How many seconds before timeout to start showing countdown.
  final int countdownStart;

  /// Called when user taps to dismiss/cancel silence stop.
  final VoidCallback? onDismiss;

  const SilenceCountdownOverlay({
    super.key,
    required this.silenceSeconds,
    this.silenceTimeout = 8,
    this.countdownStart = 3,
    this.onDismiss,
  });

  bool get _shouldShow {
    final remaining = silenceTimeout - silenceSeconds;
    return remaining <= countdownStart && remaining > 0;
  }

  int get _remainingSeconds => silenceTimeout - silenceSeconds;

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large countdown number
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.error.withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$_remainingSeconds',
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: theme.colorScheme.onError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Message
              Text(
                'Silence detected',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recording will stop automatically',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              // Tap to continue hint
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Tap anywhere to keep recording',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline silence indicator for recording UI.
class SilenceIndicator extends StatelessWidget {
  /// Whether silence is currently being detected.
  final bool isSilent;

  /// Current seconds of continuous silence.
  final int silenceSeconds;

  const SilenceIndicator({
    super.key,
    required this.isSilent,
    required this.silenceSeconds,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSilent || silenceSeconds < 2) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AnimatedOpacity(
      opacity: isSilent ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_off,
              size: 14,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Silence ${silenceSeconds}s',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
