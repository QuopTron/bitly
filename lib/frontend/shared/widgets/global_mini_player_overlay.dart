import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import '../../features/home/widgets/floating_navbar.dart';
import 'app_navigator_observer.dart';
import 'mini_player.dart';

/// Pins the bottom chrome — [MiniPlayer] + [FloatingNavbar] — above pushed
/// screens (album/artist/playlist details, etc.), not just the home tab.
///
/// The home route renders its OWN chrome inside [HomePage], so when the top
/// route is the home tab we render nothing here (avoiding a duplicate navbar).
/// We also hide on the full-screen NowPlaying page and while any modal bottom
/// sheet / dialog is showing so the modal properly covers the chrome.
///
/// Tapping a navbar item here pops every pushed route back to the home tab and
/// asks [HomePage] (via the shared home-tab notifier) to switch to that tab.
class GlobalMiniPlayerOverlay extends StatelessWidget {
  final AppNavigatorObserver observer;
  final GoRouter router;

  const GlobalMiniPlayerOverlay({
    super.key,
    required this.observer,
    required this.router,
  });

  bool _shouldHide(String? route, bool isModalShowing) {
    // Hide while any modal (download sheet, settings, queue, ...) is showing.
    if (isModalShowing) return true;
    // The home route renders its own chrome (miniplayer + navbar) already.
    const hiddenRoutes = {'home', 'now_playing', 'splash', 'setup', 'tutorial'};
    final name = route ?? '';
    // Full-screen player guard: some pushes report a null/nullable name, so
    // also check the real router location. The chrome must NEVER float over
    // the expanded NowPlaying page.
    String currentPath = '';
    try {
      currentPath = router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}
    // Check both the route name and the actual path for hidden screens.
    if (name == 'now_playing' ||
        currentPath == '/now_playing' ||
        currentPath.endsWith('/now_playing')) {
      return true;
    }
    if (currentPath == '/setup' || currentPath == '/splash' ||
        currentPath == '/tutorial') {
      return true;
    }
    // Detail pages pushed with Navigator.push() report a null name; those are
    // exactly the screens that need the floating chrome.
    return hiddenRoutes.contains(name);
  }

  /// Pops every pushed route back to the home tab and switches to [index].
  void _goToTab(BuildContext context, int index) {
    final nav = router.routerDelegate.navigatorKey.currentState;
    nav?.popUntil((r) => r.settings.name == 'home' || r.isFirst);
    // Después de que la Home quede visible, pide cambiar de pestaña.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sl<ValueNotifier<int>>().value = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: observer.isModalShowing,
      builder: (context, modalShowing, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: observer.topRouteName,
          builder: (context, route, _) {
            if (_shouldHide(route, modalShowing)) {
              return const SizedBox.shrink();
            }
            return ValueListenableBuilder<int>(
              valueListenable: sl<ValueNotifier<int>>(),
              builder: (context, currentTab, _) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                // SafeArea inferior: igual que el chrome de la Home, para no
                // chocar con la barra de gestos del sistema.
                return SafeArea(
                  top: false,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MultiBlocProvider(
                      providers: [
                        BlocProvider<QueueCubit>.value(value: sl<QueueCubit>()),
                        BlocProvider<PlayerCubit>.value(value: sl<PlayerCubit>()),
                        BlocProvider<LikeCubit>.value(value: sl<LikeCubit>()),
                      ],
                      child: MiniPlayer(
                        onOpenPlayer: () => router.push('/now_playing'),
                      ),
                    ),
                    FloatingNavbar(
                      isDark: isDark,
                      currentIndex: currentTab,
                      onTap: (i) => _goToTab(context, i),
                    ),
                  ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
