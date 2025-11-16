import 'package:flutter/material.dart';
import 'package:passage/services/perf_monitor.dart';

/// Centralized navigation helper to allow navigation from overlays or services
/// that sit outside the normal Navigator context (e.g., MaterialApp.builder overlays).
class AppNavigation {
  AppNavigation._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get _state => navigatorKey.currentState;

  static BuildContext? get context => navigatorKey.currentContext;

  static Future<T?>? pushNamed<T extends Object?>(String routeName, {Object? arguments}) {
    return _state?.pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?>? push<T extends Object?>(Route<T> route) {
    return _state?.push<T>(route);
  }

  static void pop<T extends Object?>([T? result]) {
    _state?.pop<T>(result);
  }

  static Future<T?>? pushReplacementNamed<T extends Object?, TO extends Object?> (
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return _state?.pushReplacementNamed<T, TO>(routeName, result: result, arguments: arguments);
  }

  static Future<T?>? pushNamedAndRemoveUntil<T extends Object?> (
    String newRouteName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return _state?.pushNamedAndRemoveUntil<T>(newRouteName, predicate, arguments: arguments);
  }
}

/// Tracks the current route so global overlays (like AI bubble) can adapt per-screen
class AppRouteTracker extends NavigatorObserver {
  AppRouteTracker._internal();
  static final AppRouteTracker instance = AppRouteTracker._internal();

  static String? currentRouteName;

  void _set(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      currentRouteName = name;
    } else {
      // Fallback to the route type to at least detect changes
      currentRouteName = route.runtimeType.toString();
    }
    // Feed route name to PerformanceMonitor so logs are attributed.
    PerformanceMonitor.instance.setRoute(currentRouteName!);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({ Route<dynamic>? newRoute, Route<dynamic>? oldRoute }) {
    _set(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(previousRoute);
    super.didPop(route, previousRoute);
  }
}
