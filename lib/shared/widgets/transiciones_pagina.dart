// ─────────────────────────────────────────────────────────────
// transiciones_pagina.dart — Rutas de transición reutilizables:
// RutaDesvanecerSubir (fade + slide-up para páginas de detalle),
// RutaDeslizarArriba (slide-up desde abajo para el reproductor
// completo) y RutaDesvanecer (fade-through para modales y ajustes).
// Se conecta con: material (PageRouteBuilder) + páginas de detalle
// + reproductor + ajustes.
// Parte del flujo: navegación entre vistas de la app.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Fade + slide-up suave para páginas de detalle (álbum, playlist, artista).
class RutaDesvanecerSubir<T> extends PageRouteBuilder<T> {
  final Widget pagina;

  RutaDesvanecerSubir({required this.pagina})
      : super(
          pageBuilder: (_, _, _) => pagina,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animacion, animacionSecundaria, hijo) {
            final curva = CurvedAnimation(
              parent: animacion,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curva,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curva),
                child: hijo,
              ),
            );
          },
        );
}

/// Slide-up desde abajo — usado para el reproductor completo (NowPlaying).
class RutaDeslizarArriba<T> extends PageRouteBuilder<T> {
  final Widget pagina;

  RutaDeslizarArriba({required this.pagina})
      : super(
          pageBuilder: (_, _, _) => pagina,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animacion, animacionSecundaria, hijo) {
            final curva = CurvedAnimation(
              parent: animacion,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(curva),
              child: FadeTransition(
                opacity: curva,
                child: hijo,
              ),
            );
          },
        );
}

/// Fade-through para páginas tipo modal (ajustes, modales).
class RutaDesvanecer<T> extends PageRouteBuilder<T> {
  final Widget pagina;

  RutaDesvanecer({required this.pagina})
      : super(
          pageBuilder: (_, _, _) => pagina,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animacion, animacionSecundaria, hijo) {
            final curva = CurvedAnimation(
              parent: animacion,
              curve: Curves.easeInOut,
            );
            return FadeTransition(
              opacity: curva,
              child: hijo,
            );
          },
        );
}