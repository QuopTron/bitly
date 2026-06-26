import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/splash/splash_page.dart';
import '../../features/setup/setup_page.dart';
import '../../features/home/home_page.dart';

class AppRouter {
  AppRouter();

  GoRouter get router => GoRouter(
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
    ],
  );
}
