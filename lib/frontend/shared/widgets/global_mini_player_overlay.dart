import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../backend/services/like_cubit.dart';
import '../../../backend/services/player_cubit.dart';
import '../../../backend/services/queue_cubit.dart';
import '../../../injection.dart';
import 'app_navigator_observer.dart';
import 'mini_player.dart';

/// Pins the [MiniPlayer] above EVERY screen of the app (home tabs, search,
/// downloads, album/artist/playlist detail pages, settings…), not just the
/// home tab. It hides itself on the full-screen NowPlaying page, on the
/// splash/setup flows (where there is no track yet anyway), and whenever a
/// modal bottom sheet / dialog / popover is on top so the modal properly
/// covers the miniplayer.
class GlobalMiniPlayerOverlay extends StatelessWidget {
  final AppNavigatorObserver observer;
  final GoRouter router;

  const GlobalMiniPlayerOverlay({
    super.key,
    required this.observer,
    required this.router,
  });

  bool _shouldHide(String? route, bool isModalShowing) {
    // Hide while any modal (download sheet, settings, queue, …) is showing.
    if (isModalShowing) return true;
    const hiddenRoutes = {'home', 'now_playing', 'splash', 'setup'};
    final name = route ?? '';
    // Full-screen player guard: some pushes report a null/nullable name, so
    // also check the real router location. The mini player must NEVER float
    // over the expanded NowPlaying page.
    String currentPath = '';
    try {
      currentPath = router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}
    if (name == 'now_playing' ||
        currentPath == '/now_playing' ||
        currentPath.endsWith('/now_playing')) {
      return true;
    }
    // Detail pages pushed with Navigator.push() report a null name; those are
    // exactly the screens that need the floating mini player.
    return hiddenRoutes.contains(name);
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
            return MultiBlocProvider(
              providers: [
                BlocProvider<QueueCubit>.value(value: sl<QueueCubit>()),
                BlocProvider<PlayerCubit>.value(value: sl<PlayerCubit>()),
                BlocProvider<LikeCubit>.value(value: sl<LikeCubit>()),
              ],
              child: MiniPlayer(
                onOpenPlayer: () => router.push('/now_playing'),
              ),
            );
          },
        );
      },
    );
  }
}
