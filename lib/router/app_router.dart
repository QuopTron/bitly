import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../frontend/features/splash/splash_page.dart';
import '../frontend/features/setup/setup_page.dart';
import '../frontend/features/home/home_page.dart';
import '../frontend/features/player/now_playing_page.dart';

class AppRouter {
  final GlobalKey<NavigatorState>? navigatorKey;
  AppRouter({this.navigatorKey});

  GoRouter get router => GoRouter(
    navigatorKey: navigatorKey,
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
        builder: (_, _) => const NowPlayingPage(),
      ),
    ],
  );
}

