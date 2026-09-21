// ─────────────────────────────────────────────────────────────
// pagina_home.dart — Página de Inicio (contenedor principal de la
// app): elige el shell entre las TRES variantes según la plataforma —
// TV (navegación arriba), escritorio/web/pantalla ancha (sidebar) y
// celular/tablet vertical (navbar flotante + PageView). La TV se
// pregunta primero porque también entra en el layout de escritorio.
// Recibe las 3 secciones y el miniplayer como slots; se completa
// cuando se migren Search/Feed/MiEspacio.
// Se conecta con: deteccion_plataforma (selectores) + home_movil +
// home_escritorio + home_tv.
// Parte del flujo: Home (ruta '/home' tras el splash/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../escritorio/home_escritorio.dart';
import '../movil/base/home_movil.dart';
import '../tv/home_tv.dart';

/// Página principal: elige layout móvil o escritorio según plataforma.
class PaginaHome extends StatelessWidget {
  final Widget buscador;
  final Widget feed;
  final Widget miEspacio;
  final Widget miniPlayer;

  /// Overlay de preparación de sesiones (solo relevante en móvil).
  final bool preparando;
  final VoidCallback? onSaltarEspera;

  const PaginaHome({
    super.key,
    required this.buscador,
    required this.feed,
    required this.miEspacio,
    required this.miniPlayer,
    this.preparando = false,
    this.onSaltarEspera,
  });

  @override
  Widget build(BuildContext context) {
    // Tres variantes: TV (navegación ARRIBA, ver home_tv), PC (barra lateral)
    // y celular (navbar flotante + PageView). La TV se pregunta PRIMERO porque
    // una tele ancha también entraría en el layout de escritorio.
    if (usarLayoutTv(context)) {
      return HomeTv(
        buscador: buscador,
        feed: feed,
        miEspacio: miEspacio,
        miniPlayer: miniPlayer,
      );
    }

    if (usarLayoutEscritorio(context)) {
      return HomeEscritorio(
        buscador: buscador,
        feed: feed,
        miEspacio: miEspacio,
        miniPlayer: miniPlayer,
      );
    }

    return HomeMovil(
      buscador: buscador,
      feed: feed,
      miEspacio: miEspacio,
      miniPlayer: miniPlayer,
      preparando: preparando,
      onSaltarEspera: onSaltarEspera,
    );
  }
}
