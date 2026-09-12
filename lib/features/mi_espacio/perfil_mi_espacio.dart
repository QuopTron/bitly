// ─────────────────────────────────────────────────────────────
// perfil_mi_espacio.dart — Cabecera de perfil de Mi Espacio:
// compone la fila del avatar (nombre, contadores, botón de
// ajustes) y la barra de nivel/progreso. Las piezas viven en
// perfil_mi_espacio_piezas.dart y la sincronización con el
// tutorial interactivo (abre/cierra la hoja de ajustes) en
// perfil_mi_espacio_tutorial.dart.
// Se conecta con: l10n + responsive + settings_sheet_new + tutorial.
// Parte del flujo: Home → Mi Espacio (cabecera del perfil).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/indicador_red.dart';
import '../ajustes/settings_sheet_new.dart';
import '../home/ensamblador_home.dart';
import '../tutorial_interactivo/tutorial_controller.dart';
import '../tutorial_interactivo/tutorial_pasos.dart';

part 'perfil_mi_espacio_avatar.dart';
part 'perfil_mi_espacio_piezas.dart';
part 'perfil_mi_espacio_tutorial.dart';

/// Cabecera de perfil con avatar, contadores y nivel.
class PerfilMiEspacio extends StatefulWidget {
  final String username;
  final int cancionesAmadas;
  final int playlistsCount;
  final int descargadosCount;
  final int nivel;
  final double progresoNivel;
  final int siguienteNivel;
  final Color onBg;
  final Color colorBrillo;
  final ValueChanged<bool>? onTemaCambiado;
  final VoidCallback? onIdiomaCambiado;

  const PerfilMiEspacio({
    super.key,
    required this.username,
    required this.cancionesAmadas,
    required this.playlistsCount,
    this.descargadosCount = 0,
    this.nivel = 0,
    this.progresoNivel = 0.0,
    this.siguienteNivel = 1,
    required this.onBg,
    required this.colorBrillo,
    this.onTemaCambiado,
    this.onIdiomaCambiado,
  });

  @override
  State<PerfilMiEspacio> createState() => _PerfilMiEspacioState();
}

class _PerfilMiEspacioState extends State<PerfilMiEspacio> {
  /// Controller del tutorial, cuando la app corre con tutorial (ver
  /// perfil_mi_espacio_tutorial.dart).
  TutorialController? tutorial;

  /// Si la hoja de ajustes abierta es la que abrió el tutorial.
  bool hojaAjustesAbierta = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sincronizarAjustesTutorial(context);
  }

  @override
  void dispose() {
    tutorial?.removeListener(alCambiarTutorial);
    super.dispose();
  }

  /// El controller avisa en cada paso: acá se abre/cierra la hoja.
  void alCambiarTutorial() {
    if (!mounted) return;
    sincronizarAjustesTutorial(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    // El KeyedSubtree le da al tutorial el GlobalKey de esta cabecera: es el
    // punto desde donde se abren los ajustes (y por eso el paso de ajustes
    // apunta acá). Va en la página y no en un widget de lista, porque un
    // GlobalKey no puede estar montado dos veces a la vez.
    return KeyedSubtree(
      key: keyTutorialAjustes,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: Column(
          children: [
            _filaAvatar(widget, context),
            SizedBox(height: r.spacingS),
            _barraNivel(widget, context),
          ],
        ),
      ),
    );
  }
}
