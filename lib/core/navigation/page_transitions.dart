import 'package:flutter/material.dart';

/// A custom page route that provides a fade transition between pages
class FadePageRoute<T> extends PageRoute<T> {
  final Widget child;
  
  FadePageRoute({
    required this.child,
    RouteSettings? settings,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.maintainState = true,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  final Duration transitionDuration;
  
  @override
  final Duration reverseTransitionDuration;
  
  @override
  final bool opaque;
  
  @override
  final bool barrierDismissible;
  
  @override
  final Color? barrierColor;
  
  @override
  final String? barrierLabel;
  
  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

/// A custom page route that provides a bottom-to-top slide transition
class BottomToTopPageRoute<T> extends PageRoute<T> {
  final Widget child;
  
  BottomToTopPageRoute({
    required this.child,
    RouteSettings? settings,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.reverseTransitionDuration = const Duration(milliseconds: 500),
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.maintainState = true,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  final Duration transitionDuration;
  
  @override
  final Duration reverseTransitionDuration;
  
  @override
  final bool opaque;
  
  @override
  final bool barrierDismissible;
  
  @override
  final Color? barrierColor;
  
  @override
  final String? barrierLabel;
  
  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // For bottom-to-top slide transitions
    final Tween<Offset> position = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Start from bottom
      end: Offset.zero, // End at center
    );
    
    return SlideTransition(
      position: position.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: child,
    );
  }
}

/// A custom page route that provides a horizontal slide transition between pages
class SlidePageRoute<T> extends PageRoute<T> {
  final Widget child;
  final bool slideFromRight;
  
  SlidePageRoute({
    required this.child,
    RouteSettings? settings,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.reverseTransitionDuration = const Duration(milliseconds: 300),
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.maintainState = true,
    bool fullscreenDialog = false,
    this.slideFromRight = true,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  final Duration transitionDuration;
  
  @override
  final Duration reverseTransitionDuration;
  
  @override
  final bool opaque;
  
  @override
  final bool barrierDismissible;
  
  @override
  final Color? barrierColor;
  
  @override
  final String? barrierLabel;
  
  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // For sliding transitions
    final Tween<Offset> position = Tween<Offset>(
      begin: Offset(slideFromRight ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    );
    
    return SlideTransition(
      position: position.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}

/// A custom PageTransitionBuilder that uses fade transition instead of the default slide
class FadeTransitionBuilder extends PageTransitionsBuilder {
  const FadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

/// A custom PageTransitionBuilder that uses horizontal slide transitions
class SlideTransitionBuilder extends PageTransitionsBuilder {
  final bool slideFromRight;
  
  const SlideTransitionBuilder({this.slideFromRight = true});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // For sliding transitions
    final Tween<Offset> position = Tween<Offset>(
      begin: Offset(slideFromRight ? 1.0 : -1.0, 0.0),
      end: Offset.zero,
    );
    
    return SlideTransition(
      position: position.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}

/// A custom transition class for horizontal slide animations between tab items
class HorizontalSlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> position;
  final bool slideFromRight;

  const HorizontalSlideTransition({
    Key? key,
    required this.child,
    required this.position,
    this.slideFromRight = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: position,
      builder: (context, child) {
        final double xOffset = slideFromRight 
          ? position.value * MediaQuery.of(context).size.width 
          : -1.0 * position.value * MediaQuery.of(context).size.width;
          
        return Transform.translate(
          offset: Offset(xOffset, 0),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// A custom page route that provides a top-to-bottom slide transition for back/close navigation
class TopToBottomPageRoute<T> extends PageRoute<T> {
  final Widget child;
  
  TopToBottomPageRoute({
    required this.child,
    RouteSettings? settings,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.reverseTransitionDuration = const Duration(milliseconds: 500),
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.maintainState = true,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  final Duration transitionDuration;
  
  @override
  final Duration reverseTransitionDuration;
  
  @override
  final bool opaque;
  
  @override
  final bool barrierDismissible;
  
  @override
  final Color? barrierColor;
  
  @override
  final String? barrierLabel;
  
  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // For top-to-bottom slide transitions
    final Tween<Offset> position = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Start from top
      end: Offset.zero, // End at center
    );
    
    return SlideTransition(
      position: position.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: child,
    );
  }
}



/// A page route that makes the new screen slide up from bottom, 
/// creating the visual effect of the previous screen sliding out to top
class BottomToTopDismissPageRoute<T> extends PageRoute<T> {
  final Widget child;
  
  BottomToTopDismissPageRoute({
    required this.child,
    RouteSettings? settings,
    this.transitionDuration = const Duration(milliseconds: 500),
    this.reverseTransitionDuration = const Duration(milliseconds: 500),
    this.opaque = true,
    this.barrierDismissible = false,
    this.barrierColor,
    this.barrierLabel,
    this.maintainState = true,
    bool fullscreenDialog = false,
  }) : super(
          settings: settings,
          fullscreenDialog: fullscreenDialog,
        );

  @override
  final Duration transitionDuration;
  
  @override
  final Duration reverseTransitionDuration;
  
  @override
  final bool opaque;
  
  @override
  final bool barrierDismissible;
  
  @override
  final Color? barrierColor;
  
  @override
  final String? barrierLabel;
  
  @override
  final bool maintainState;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // New screen slides up from bottom
    final Tween<Offset> position = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Start from bottom
      end: Offset.zero, // End at center
    );
    
    return SlideTransition(
      position: position.animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: child,
    );
  }
} 