import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

/// Custom page transitions for Boardroom Journal.
///
/// Provides distinctive transitions between screens that feel premium
/// and intentional, not default.
class PageTransitions {
  PageTransitions._();

  /// Default transition duration for page animations.
  static const Duration defaultDuration = Duration(milliseconds: 350);

  /// Fast transition duration for quick navigation.
  static const Duration fastDuration = Duration(milliseconds: 250);

  /// Slow transition duration for major transitions.
  static const Duration slowDuration = Duration(milliseconds: 500);

  /// Shared axis transition (Material motion) - good for related content.
  ///
  /// Use for navigation between related screens (e.g., home -> entry detail).
  static Widget sharedAxisTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    SharedAxisTransitionType type = SharedAxisTransitionType.horizontal,
  }) {
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: type,
      child: child,
    );
  }

  /// Fade through transition - good for unrelated content.
  ///
  /// Use for navigation between unrelated screens (e.g., home -> settings).
  static Widget fadeThroughTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  /// Fade scale transition - good for dialogs and overlays.
  static Widget fadeScaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeScaleTransition(
      animation: animation,
      child: child,
    );
  }

  /// Custom slide up transition for modal-like screens.
  ///
  /// Use for recording screen, governance flows.
  static Widget slideUpTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeOutCubic;
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curvedAnimation),
        child: child,
      ),
    );
  }

  /// Custom slide from right transition for detail screens.
  static Widget slideFromRightTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeOutCubic;
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: curve,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );
  }

  /// Create a custom page route with the specified transition.
  static Route<T> createRoute<T>({
    required Widget page,
    required Widget Function(
      BuildContext,
      Animation<double>,
      Animation<double>,
      Widget,
    ) transitionBuilder,
    Duration duration = const Duration(milliseconds: 350),
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: transitionBuilder,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      settings: settings,
    );
  }

  /// Shared axis horizontal route - for related content navigation.
  static Route<T> sharedAxisHorizontalRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return createRoute<T>(
      page: page,
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          sharedAxisTransition(
            context,
            animation,
            secondaryAnimation,
            child,
            type: SharedAxisTransitionType.horizontal,
          ),
      settings: settings,
    );
  }

  /// Shared axis vertical route - for drill-down navigation.
  static Route<T> sharedAxisVerticalRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return createRoute<T>(
      page: page,
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          sharedAxisTransition(
            context,
            animation,
            secondaryAnimation,
            child,
            type: SharedAxisTransitionType.vertical,
          ),
      settings: settings,
    );
  }

  /// Fade through route - for unrelated content.
  static Route<T> fadeThroughRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return createRoute<T>(
      page: page,
      transitionBuilder: fadeThroughTransition,
      settings: settings,
    );
  }

  /// Slide up route - for modal-like screens.
  static Route<T> slideUpRoute<T>({
    required Widget page,
    RouteSettings? settings,
  }) {
    return createRoute<T>(
      page: page,
      transitionBuilder: slideUpTransition,
      duration: slowDuration,
      settings: settings,
    );
  }
}
