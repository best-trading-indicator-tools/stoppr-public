// Summary: Centralized screenshot tracking wired to Mixpanel. It listens for
// OS screenshot events using flutter_screenshot_detect and reports a single
// Mixpanel event with the current route name. This avoids per-screen edits.

import 'package:flutter/material.dart';
import 'package:flutter_screenshot_detect/flutter_screenshot_detect.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

/// Observes navigation to keep track of the current route name.
class ScreenRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  String? _currentRouteName;

  String? get currentRouteName => _currentRouteName;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _updateNameFrom(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    _updateNameFrom(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateNameFrom(newRoute);
  }

  void _updateNameFrom(Route? route) {
    if (route is PageRoute) {
      _currentRouteName = route.settings.name ?? route.runtimeType.toString();
    }
  }
}

/// Listens for screenshot events and sends Mixpanel analytics.
class ScreenshotTracker {
  final ScreenRouteObserver routeObserver;
  final FlutterScreenshotDetect _detector = FlutterScreenshotDetect();
  bool _isListening = false;

  ScreenshotTracker({required this.routeObserver});

  void start() {
    if (_isListening) return;
    _isListening = true;
    _detector.startListening((event) {
      final String screen = routeObserver.currentRouteName ?? 'Unknown';
      MixpanelService.trackEvent('$screen Screenshot Captured', properties: {
        'Screen': screen,
        'Timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  void stop() {
    if (!_isListening) return;
    _isListening = false;
    // Some plugin versions don't expose an explicit stop method; rely on
    // _isListening guard to avoid duplicate listeners.
  }
}


