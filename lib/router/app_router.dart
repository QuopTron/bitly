// ─────────────────────────────────────────────────────────────
// app_router.dart — Router raíz de la app (go_router): define las
// rutas splash ('/'), setup ('/setup'), home ('/home') y tutorial
// ('/tutorial') con sus transiciones. El reproductor completo NO
// tiene ruta propia: se abre con RutaDeslizarArriba (Navigator.push)
// desde el ensamblador de la home.
// Se conecta con: route_names + pagina_splash + pagina_setup +
// ensamblador_home + tutorial_pagina.
// Parte del flujo: navegación raíz (primera pantalla → home/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/ensamblador_home.dart';
import '../features/setup/pagina_setup.dart';
import '../features/splash/pagina_splash.dart';
import '../features/tutorial/tutorial_pagina.dart';
import 'route_names.dart';

/// Construye el GoRouter con las rutas raíz de la app.
class AppRouter {
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver>? navigatorObservers;

  const AppRouter({this.navigatorKey, this.navigatorObservers});

  GoRouter get router => GoRouter(
        navigatorKey: navigatorKey,
        observers: navigatorObservers,
        initialLocation: RouteNames.splash.path,
        routes: [
          GoRoute(
            path: RouteNames.splash.path,
            name: 'splash',
            builder: (_, _) => const PaginaSplash(),
          ),
          GoRoute(
            path: RouteNames.setup.path,
            name: 'setup',
            pageBuilder: (_, _) => CustomTransitionPage(
              key: const ValueKey('setup'),
              child: const PaginaSetup(),
              transitionsBuilder: (_, animacion, _, hijo) =>
                  FadeTransition(opacity: animacion, child: hijo),
            ),
          ),
          GoRoute(
            path: RouteNames.home.path,
            name: 'home',
            builder: (_, _) => const EnsambladorHome(),
          ),
          GoRoute(
            path: RouteNames.tutorial.path,
            name: 'tutorial',
            builder: (_, _) => const TutorialPagina(),
          ),
        ],
      );
}