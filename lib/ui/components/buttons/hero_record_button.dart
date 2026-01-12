import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/theme.dart';

/// A prominent, attention-grabbing record button for the home screen.
///
/// Features:
/// - Large circular design with glow effect
/// - Pulsing animation when idle
/// - Ripple animation when pressed
/// - Haptic feedback on tap
class HeroRecordButton extends StatefulWidget {
  const HeroRecordButton({
    super.key,
    required this.onPressed,
    this.size = 80,
    this.isRecording = false,
  });

  /// Called when the button is pressed.
  final VoidCallback onPressed;

  /// The diameter of the button.
  final double size;

  /// Whether recording is currently active.
  final bool isRecording;

  @override
  State<HeroRecordButton> createState() => _HeroRecordButtonState();
}

class _HeroRecordButtonState extends State<HeroRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Only repeat animation if not in test environment
    // Use a delayed call so the widget can be tested with pumpAndSettle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    HapticFeedback.mediumImpact();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Button colors
    final primaryColor = widget.isRecording
        ? Colors.red
        : (isDark ? AppColors.accentGold : AppColors.primaryNavy);
    final glowColor = widget.isRecording
        ? Colors.red.withOpacity(0.3)
        : primaryColor.withOpacity(0.2);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          // Subtle pulse scale when idle
          final pulseScale = widget.isRecording
              ? 1.0
              : 1.0 + (_pulseController.value * 0.03);

          return Transform.scale(
            scale: _isPressed ? 0.95 : pulseScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: widget.size + 32,
                  height: widget.size + 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 24 + (_pulseController.value * 8),
                        spreadRadius: 4 + (_pulseController.value * 4),
                      ),
                    ],
                  ),
                ),

                // Main button
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: widget.size * 0.4,
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

/// A smaller record button for inline use.
class CompactRecordButton extends StatelessWidget {
  const CompactRecordButton({
    super.key,
    required this.onPressed,
    this.size = 56,
    this.isRecording = false,
  });

  final VoidCallback onPressed;
  final double size;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isRecording
        ? Colors.red
        : (isDark ? AppColors.accentGold : AppColors.primaryNavy);

    return Material(
      color: primaryColor,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: size * 0.4,
          ),
        ),
      ),
    )
        .animate(
          target: isRecording ? 1 : 0,
          onPlay: isRecording
              ? (controller) => controller.repeat(reverse: true)
              : null,
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          duration: const Duration(milliseconds: 800),
        );
  }
}
