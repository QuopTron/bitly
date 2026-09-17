// ─────────────────────────────────────────────────────────────
// app_router.dart — Router raíz de la app (go_router): define las
// rutas splash ('/'), setup ('/setup'), home ('/home') y tutorial
// ('/tutorial') con sus transiciones. El reproductor completo NO
// tiene ruta propia: se abre con RutaDeslizarArriba (Navigator.push)
// desde el ensamblador de la home.
//
// El `redirect` manda al home cualquier enlace que llegue de fuera
// (p. ej. /open?s=... de un compartido): sin él, go_router lanzaba
// "no routes for location" y mostraba la URL a la vista. El
// `errorBuilder` es la red de seguridad para que eso NUNCA se vea.
//
// Se conecta con: route_names + app_router_enlaces + pagina_splash +
// pagina_setup + ensamblador_home + tutorial_pagina.
// Parte del flujo: navegación raíz (primera pantalla → home/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/shell/ensamblador_home.dart';
import '../features/setup/pagina_setup.dart';
import '../features/splash/pagina_splash.dart';
import '../features/tutorial/pagina/tutorial_pagina.dart';
import 'app_router_enlaces.dart';
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
        // Enlaces de fuera (compartidos, PWA, navegador): se resuelven a una
        // ruta conocida en vez de romper el router con la URL entera.
        redirect: (_, estado) =>
            destinoDeLocationExterna(estado.uri.toString()),
        // Red de seguridad: si alguna vez ninguna ruta coincide, se entra al
        // home en lugar de mostrar la pantalla de error con la URL.
        errorBuilder: (_, _) => const EnsambladorHome(),
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