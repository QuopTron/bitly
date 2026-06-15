import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import 'guards/auth_guard.dart';
import 'guards/setup_guard.dart';
import 'transitions/fade_transition.dart';
import 'transitions/slide_transition.dart';

class AppRouter {
  final AuthGuard authGuard;
  final SetupGuard setupGuard;

  AppRouter({
    required this.authGuard,
    required this.setupGuard,
  });

  GoRouter get router => GoRouter(
        initialLocation: RouteNames.splash.path,
        routes: [
          GoRoute(
            path: RouteNames.splash.path,
            name: RouteNames.splash.name,
            builder: (_, _) => const SizedBox(),
          ),
          GoRoute(
            path: RouteNames.tutorial.path,
            name: RouteNames.tutorial.name,
            pageBuilder: (_, _) => FadePageTransition(
              child: const SizedBox(),
              key: ValueKey(RouteNames.tutorial.name),
            ),
          ),
          GoRoute(
            path: RouteNames.setup.path,
            name: RouteNames.setup.name,
            pageBuilder: (_, _) => SlidePageTransition(
              child: const SizedBox(),
              key: ValueKey(RouteNames.setup.name),
            ),
          ),
          GoRoute(
            path: RouteNames.home.path,
            name: RouteNames.home.name,
            pageBuilder: (_, _) => SlidePageTransition(
              child: const SizedBox(),
              key: ValueKey(RouteNames.home.name),
            ),
            routes: [
              GoRoute(
                path: RouteNames.search.name,
                name: RouteNames.search.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: RouteNames.library.name,
                name: RouteNames.library.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: RouteNames.downloads.name,
                name: RouteNames.downloads.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: '${RouteNames.player.name}/:trackId',
                name: RouteNames.player.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: RouteNames.settings.name,
                name: RouteNames.settings.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: RouteNames.extensions.name,
                name: RouteNames.extensions.name,
                builder: (_, _) => const SizedBox(),
              ),
              GoRoute(
                path: RouteNames.extensionsStore.name,
                name: RouteNames.extensionsStore.name,
                builder: (_, _) => const SizedBox(),
              ),
            ],
          ),
        ],
        redirect: (context, state) {
          final uri = state.matchedLocation;
          final authRedirect = authGuard.redirect(uri);
          if (authRedirect != null) return authRedirect;
          final setupRedirect = setupGuard.redirect(uri);
          if (setupRedirect != null) return setupRedirect;
          return null;
        },
      );
}
