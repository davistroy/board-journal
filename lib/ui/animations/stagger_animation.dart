import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Staggered list reveal animations for Boardroom Journal.
///
/// Provides animations for list items that cascade in one by one,
/// creating a polished, premium feel.
class StaggerAnimation {
  StaggerAnimation._();

  /// Default stagger delay between items.
  static const Duration defaultDelay = Duration(milliseconds: 50);

  /// Default animation duration per item.
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// Default curve for stagger animations.
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Animates a widget with a staggered fade and slide effect.
  ///
  /// Use this on list items to create a cascading reveal effect.
  /// [index] determines the delay - higher index = later animation.
  static Widget staggeredItem({
    required Widget child,
    required int index,
    Duration delay = defaultDelay,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    Offset beginOffset = const Offset(0, 20),
  }) {
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .slideY(
          begin: beginOffset.dy / 100,
          end: 0,
          duration: duration,
          curve: curve,
        );
  }

  /// Animates a widget with a staggered scale and fade effect.
  ///
  /// Good for card grids or icon groups.
  static Widget staggeredScale({
    required Widget child,
    required int index,
    Duration delay = defaultDelay,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    double beginScale = 0.9,
  }) {
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .scale(
          begin: Offset(beginScale, beginScale),
          end: const Offset(1, 1),
          duration: duration,
          curve: curve,
        );
  }

  /// Animates a widget sliding in from the left.
  static Widget staggeredSlideFromLeft({
    required Widget child,
    required int index,
    Duration delay = defaultDelay,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
  }) {
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .slideX(begin: -0.3, end: 0, duration: duration, curve: curve);
  }

  /// Animates a widget sliding in from the right.
  static Widget staggeredSlideFromRight({
    required Widget child,
    required int index,
    Duration delay = defaultDelay,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
  }) {
    return child
        .animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .slideX(begin: 0.3, end: 0, duration: duration, curve: curve);
  }

  /// Builds a staggered list with animated children.
  ///
  /// Returns a Column of animated items. Use this for simple lists.
  static Widget buildStaggeredList({
    required List<Widget> children,
    Duration delay = defaultDelay,
    Duration duration = defaultDuration,
    Curve curve = defaultCurve,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    MainAxisSize mainAxisSize = MainAxisSize.min,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: List.generate(
        children.length,
        (index) => staggeredItem(
          child: children[index],
          index: index,
          delay: delay,
          duration: duration,
          curve: curve,
        ),
      ),
    );
  }

  /// Extension method on widgets to easily apply stagger animation.
  /// Use: widget.staggerIn(index: 2)
}

/// Extension on Widget for easy stagger animations.
extension StaggerAnimationExtension on Widget {
  /// Applies staggered fade-slide animation based on index.
  Widget staggerIn({
    required int index,
    Duration delay = const Duration(milliseconds: 50),
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .slideY(begin: 0.2, end: 0, duration: duration, curve: curve);
  }

  /// Applies staggered scale animation based on index.
  Widget staggerScale({
    required int index,
    Duration delay = const Duration(milliseconds: 50),
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
    double beginScale = 0.9,
  }) {
    return animate(delay: delay * index)
        .fadeIn(duration: duration, curve: curve)
        .scale(
          begin: Offset(beginScale, beginScale),
          end: const Offset(1, 1),
          duration: duration,
          curve: curve,
        );
  }
}
