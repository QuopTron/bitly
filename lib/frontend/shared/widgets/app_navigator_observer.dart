import 'package:flutter/widgets.dart';

/// Tracks the name of the current top-most route so the UI can tell which
/// screen is active (e.g. to hide the mini player on the full-screen player
/// page) AND whether a modal (bottom sheet, dialog, etc.) is currently covering
/// the screen.
class AppNavigatorObserver extends NavigatorObserver {
  final ValueNotifier<String?> topRouteName = ValueNotifier<String?>(null);

  /// True whenever at least one [PopupRoute] (modal bottom sheet, dialog,
  /// popover, …) is the top-most route.  The mini-player, navbar, and any
  /// other persistent chrome should hide while this is true.
  final ValueNotifier<bool> isModalShowing = ValueNotifier<bool>(false);

  int _modalStackDepth = 0;

  /// Self-maintained mirror of the navigator's route stack (route names).
  /// go_router's pop/remove callbacks frequently report a null previousRoute
  /// even though a named route remains on the stack (e.g. splash → home), which
  /// would wrongly flip [topRouteName] to null and make the global mini-player
  /// overlay render on top of the home tab. Tracking the stack ourselves keeps
  /// [topRouteName] accurate no matter what the router reports.
  final List<String?> _routeStack = [];

  String? get _topName => _routeStack.isEmpty ? null : _routeStack.last;

  void _update(String? name) {
    // Navigation observers fire during the Navigator's build phase; deferring
    // to the next frame avoids markNeedsBuild()-during-build exceptions for
    // any ValueListenableBuilder that depends on [topRouteName].
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (topRouteName.value != name) {
        topRouteName.value = name;
      }
    });
  }

  void _trackModal(Route route, {required bool pushing}) {
    if (route is PopupRoute) {
      _modalStackDepth = (_modalStackDepth + (pushing ? 1 : -1)).clamp(0, 999);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        isModalShowing.value = _modalStackDepth > 0;
      });
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _routeStack.add(route.settings.name);
    _update(_topName);
    _trackModal(route, pushing: true);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (_routeStack.isNotEmpty) _routeStack.removeLast();
    _update(_topName);
    _trackModal(route, pushing: false);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _routeStack.remove(route.settings.name);
    _update(_topName);
    _trackModal(route, pushing: false);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) {
      final i = _routeStack.lastIndexOf(oldRoute.settings.name);
      if (i >= 0) {
        _routeStack[i] = newRoute?.settings.name;
      } else if (newRoute != null) {
        _routeStack.add(newRoute.settings.name);
      }
    } else if (newRoute != null) {
      _routeStack.add(newRoute.settings.name);
    }
    _update(_topName);
    if (oldRoute != null) _trackModal(oldRoute, pushing: false);
    if (newRoute != null) _trackModal(newRoute, pushing: true);
  }

  void dispose() {
    topRouteName.dispose();
    isModalShowing.dispose();
  }
}
