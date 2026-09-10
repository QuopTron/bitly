// ─────────────────────────────────────────────────────────────
// pagina_home.dart — Página de Inicio (contenedor principal de la
// app): elige el shell según la plataforma usando el selector ÚNICO
// usarLayoutEscritorio (escritorio/web/pantalla ancha → sidebar
// lateral; celular/tablet vertical → navbar flotante + PageView).
// Recibe las 3 secciones y el miniplayer como slots; se completa
// cuando se migren Search/Feed/MiEspacio.
// Se conecta con: deteccion_plataforma (selector) + home_movil +
// home_escritorio.
// Parte del flujo: Home (ruta '/home' tras el splash/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/utilidades/deteccion_plataforma.dart';
import 'home_escritorio.dart';
import 'home_movil.dart';

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
    final usarEscritorio = usarLayoutEscritorio(context);

    if (usarEscritorio) {
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