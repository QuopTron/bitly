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
    _update(route.settings.name);
    _trackModal(route, pushing: true);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _update(previousRoute?.settings.name);
    _trackModal(route, pushing: false);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _update(previousRoute?.settings.name);
    _trackModal(route, pushing: false);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _update(newRoute?.settings.name);
    if (oldRoute != null) _trackModal(oldRoute, pushing: false);
    if (newRoute != null) _trackModal(newRoute, pushing: true);
  }

  void dispose() {
    topRouteName.dispose();
    isModalShowing.dispose();
  }
}
