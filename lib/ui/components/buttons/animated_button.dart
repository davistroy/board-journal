import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/theme.dart';

/// A button with built-in press animation and haptic feedback.
///
/// Wraps Flutter's button styles with consistent animations
/// throughout the app.
class AnimatedFilledButton extends StatefulWidget {
  const AnimatedFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.scaleDown = 0.97,
    this.enableHaptic = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final double scaleDown;
  final bool enableHaptic;

  @override
  State<AnimatedFilledButton> createState() => _AnimatedFilledButtonState();
}

class _AnimatedFilledButtonState extends State<AnimatedFilledButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: widget.style,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// An outlined button with press animation.
class AnimatedOutlinedButton extends StatefulWidget {
  const AnimatedOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.scaleDown = 0.97,
    this.enableHaptic = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final double scaleDown;
  final bool enableHaptic;

  @override
  State<AnimatedOutlinedButton> createState() => _AnimatedOutlinedButtonState();
}

class _AnimatedOutlinedButtonState extends State<AnimatedOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: OutlinedButton(
              onPressed: widget.onPressed,
              style: widget.style,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// A text button with press animation.
class AnimatedTextButton extends StatefulWidget {
  const AnimatedTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.scaleDown = 0.97,
    this.enableHaptic = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final double scaleDown;
  final bool enableHaptic;

  @override
  State<AnimatedTextButton> createState() => _AnimatedTextButtonState();
}

class _AnimatedTextButtonState extends State<AnimatedTextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: TextButton(
              onPressed: widget.onPressed,
              style: widget.style,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// A custom CTA (call-to-action) button with glow effect.
class CTAButton extends StatelessWidget {
  const CTAButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.width,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return AnimatedFilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: Size(width ?? 200, 56),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusLg,
        ),
      ).copyWith(
        elevation: WidgetStateProperty.all(8),
        shadowColor: WidgetStateProperty.all(
          colorScheme.primary.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
