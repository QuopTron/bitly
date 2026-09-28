// ─────────────────────────────────────────────────────────────
// pagina_home.dart — Página de Inicio (contenedor principal de la
// app): elige el shell entre las TRES variantes según la plataforma —
// TV (navegación arriba), escritorio/web/pantalla ancha (sidebar) y
// celular/tablet vertical (navbar flotante + PageView). La TV se
// pregunta primero porque también entra en el layout de escritorio.
// Recibe las 3 secciones y el miniplayer como slots.
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

  const PaginaHome({
    super.key,
    required this.buscador,
    required this.feed,
    required this.miEspacio,
    required this.miniPlayer,
  });

  @override
  Widget build(BuildContext context) {
    // Tres variantes: TV (navegación ARRIBA, ver home_tv), PC (barra lateral)
    // y celular (navbar flotante + PageView). La TV se pregunta PRIMERO porque
    // una tele ancha también entraría en el layout de escritorio.
    //
    // Los tres shells comparten la pestaña activa (ver `pestanaHomeInicial` en
    // ensamblador_home.dart), así que cambiar de tamaño/plataforma o volver a
    // la Home no reinicia dónde estabas.
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
    );
  }
}
