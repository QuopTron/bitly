// ─────────────────────────────────────────────────────────────
// perfil_mi_espacio.dart — Cabecera de perfil de Mi Espacio:
// compone la fila del avatar (nombre, contadores, botón de
// ajustes) y la barra de nivel/progreso. Las piezas viven en
// perfil_mi_espacio_piezas.dart y la hoja de ajustes en
// perfil_hoja_ajustes.dart.
// Se conecta con: l10n + responsive + perfil_hoja_ajustes.
// Parte del flujo: Home → Mi Espacio (cabecera del perfil).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/responsive.dart';
import '../ajustes/settings_sheet_new.dart';

part 'perfil_mi_espacio_avatar.dart';
part 'perfil_mi_espacio_piezas.dart';

/// Cabecera de perfil con avatar, contadores y nivel.
class PerfilMiEspacio extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
      child: Column(
        children: [
          _filaAvatar(this, context),
          SizedBox(height: r.spacingS),
          _barraNivel(this, context),
        ],
      ),
    );
  }
}