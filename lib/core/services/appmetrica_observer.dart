import 'package:appmetrica_plugin/appmetrica_plugin.dart';
import 'package:flutter/widgets.dart';

class AppMetricaNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _report(previousRoute);
  }

  void _report(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    AppMetrica.reportEventWithMap('screen_view', {'screen': name});
  }
}
