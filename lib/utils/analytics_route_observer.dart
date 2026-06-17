import 'package:flutter/widgets.dart';
import '../services/analytics_engine.dart';

class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  String? _currentScreen;
  final Map<Route<dynamic>, DateTime> _routePushTimes = {};

  void _sendScreenView(PageRoute<dynamic> route) {
    final String? screenName = route.settings.name;
    if (screenName != null) {
      AnalyticsEngine().logScreenViewed(
        screenName: screenName,
        previousScreen: _currentScreen,
      );
      _currentScreen = screenName;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routePushTimes[route] = DateTime.now();
    
    if (route is PageRoute) {
      _sendScreenView(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _sendScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    
    final pushTime = _routePushTimes.remove(route);
    if (pushTime != null && route.settings.name != null) {
      final durationMs = DateTime.now().difference(pushTime).inMilliseconds;
      
      // Property details screen u_turn check
      if (durationMs < 2000 && route.settings.name == 'ad_details') {
        AnalyticsEngine().logEvent('u_turn', {
          'screen_name': route.settings.name,
          'duration_ms': durationMs,
        });
      }
    }

    if (previousRoute is PageRoute && route is PageRoute) {
      _sendScreenView(previousRoute);
    }
  }
}
