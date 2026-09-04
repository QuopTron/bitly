import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../frontend/features/splash/splash_page.dart';
import '../frontend/features/setup/setup_page.dart';
import '../frontend/features/home/home_page.dart';
import '../frontend/features/player/now_playing_page.dart';
import '../frontend/features/tutorial/tutorial_page.dart';

/// Slide-up + fade transition used by [CustomTransitionPage] below.
Widget _slideUpTransitions(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
    child: FadeTransition(opacity: curved, child: child),
  );
}

class AppRouter {
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver>? navigatorObservers;
  AppRouter({this.navigatorKey, this.navigatorObservers});

  GoRouter get router => GoRouter(
    navigatorKey: navigatorKey,
    observers: navigatorObservers,
    initialLocation: RouteNames.splash.path,
    routes: [
      GoRoute(
        path: RouteNames.splash.path,
        name: 'splash',
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: RouteNames.setup.path,
        name: 'setup',
        pageBuilder: (_, _) => CustomTransitionPage(
          key: const ValueKey('setup'),
          child: const SetupPage(),
          transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: RouteNames.home.path,
        name: 'home',
        builder: (_, _) => const HomePage(),
      ),
      GoRoute(
        path: RouteNames.nowPlaying.path,
        name: 'now_playing',
        // `name` makes the route observable by AppNavigatorObserver so the
        // global MiniPlayer overlay can hide while the full-screen player is up.
        pageBuilder: (_, _) => CustomTransitionPage<void>(
          name: 'now_playing',
          key: const ValueKey('now_playing_page'),
          child: const NowPlayingPage(),
          transitionsBuilder: _slideUpTransitions,
        ),
      ),
      GoRoute(
        path: RouteNames.tutorial.path,
        name: 'tutorial',
        builder: (_, _) => const TutorialPage(),
      ),
    ],
  );
}

