import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Micro-interactions for Boardroom Journal.
///
/// Provides satisfying feedback for user actions like button presses,
/// toggles, saves, and other interactions.
class MicroInteractions {
  MicroInteractions._();

  // Animation durations
  static const Duration quickDuration = Duration(milliseconds: 100);
  static const Duration normalDuration = Duration(milliseconds: 200);
  static const Duration slowDuration = Duration(milliseconds: 350);

  // Animation curves
  static const Curve pressCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
}

/// A button that scales down when pressed, providing tactile feedback.
///
/// Wraps any child widget and makes it respond to taps with a satisfying
/// press animation and optional haptic feedback.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOutCubic,
    this.enableHaptic = true,
    this.hapticType = HapticType.light,
    this.disabled = false,
  });

  /// The child widget to wrap.
  final Widget child;

  /// Called when the widget is tapped.
  final VoidCallback? onPressed;

  /// Called when the widget is long-pressed.
  final VoidCallback? onLongPress;

  /// The scale factor when pressed (1.0 = no scale, 0.9 = 90% size).
  final double scaleDown;

  /// Duration of the scale animation.
  final Duration duration;

  /// Animation curve.
  final Curve curve;

  /// Whether to trigger haptic feedback on press.
  final bool enableHaptic;

  /// Type of haptic feedback.
  final HapticType hapticType;

  /// Whether the button is disabled.
  final bool disabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.disabled) return;
    _controller.forward();
    if (widget.enableHaptic) {
      _triggerHaptic();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.disabled) return;
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _triggerHaptic() {
    switch (widget.hapticType) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: widget.disabled ? 0.5 : 1.0,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// Types of haptic feedback available.
enum HapticType {
  light,
  medium,
  heavy,
  selection,
}

/// Centralized haptic feedback service.
class HapticService {
  HapticService._();

  /// Light tap feedback - for regular button presses.
  static void lightTap() => HapticFeedback.lightImpact();

  /// Medium tap feedback - for important actions.
  static void mediumTap() => HapticFeedback.mediumImpact();

  /// Heavy tap feedback - for major actions like recording start.
  static void heavyTap() => HapticFeedback.heavyImpact();

  /// Selection feedback - for toggles, checkboxes.
  static void selection() => HapticFeedback.selectionClick();

  /// Success feedback pattern.
  static Future<void> success() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  /// Error feedback pattern.
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.heavyImpact();
  }

  /// Recording start feedback.
  static void recordingStart() => HapticFeedback.heavyImpact();

  /// Recording stop feedback.
  static void recordingStop() => HapticFeedback.mediumImpact();
}

/// Extension on Widget for easy micro-interaction animations.
extension MicroInteractionExtension on Widget {
  /// Applies a press scale effect to the widget.
  Widget pressable({
    VoidCallback? onPressed,
    double scaleDown = 0.96,
    bool enableHaptic = true,
    HapticType hapticType = HapticType.light,
  }) {
    return PressableScale(
      onPressed: onPressed,
      scaleDown: scaleDown,
      enableHaptic: enableHaptic,
      hapticType: hapticType,
      child: this,
    );
  }

  /// Applies a shimmer loading effect.
  Widget shimmer({
    Duration duration = const Duration(milliseconds: 1500),
    Color? color,
  }) {
    return animate(
      onPlay: (controller) => controller.repeat(),
    ).shimmer(
      duration: duration,
      color: color ?? Colors.white.withOpacity(0.3),
    );
  }

  /// Applies a pulse effect (good for attention-grabbing).
  Widget pulse({
    Duration duration = const Duration(milliseconds: 1000),
    double begin = 1.0,
    double end = 1.05,
  }) {
    return animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      begin: Offset(begin, begin),
      end: Offset(end, end),
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  /// Applies a success checkmark animation.
  Widget successPop({
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return animate(delay: delay)
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: duration,
          curve: Curves.elasticOut,
        )
        .fade(begin: 0, end: 1, duration: duration ~/ 2);
  }

  /// Applies a shake animation (good for errors).
  Widget shake({
    Duration duration = const Duration(milliseconds: 500),
    double offset = 10,
    int shakes = 4,
  }) {
    return animate()
        .shake(
          duration: duration,
          hz: shakes.toDouble(),
          offset: Offset(offset, 0),
        )
        .then()
        .slideX(begin: 0, end: 0); // Reset position
  }

  /// Applies a bounce-in animation.
  Widget bounceIn({
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return animate(delay: delay)
        .scale(
          begin: const Offset(0.3, 0.3),
          end: const Offset(1, 1),
          duration: duration,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: duration ~/ 2);
  }
}
