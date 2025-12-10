import 'package:flutter/material.dart';

/// Helper class for consistent app navigation transitions
class AppRouter {
  /// Creates a page route with a clean fade transition without any sliding effect
  static PageRouteBuilder createFadeRoute({
    required Widget page,
    String? routeName,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: duration,
      settings: routeName != null ? RouteSettings(name: routeName) : null,
    );
  }
} 