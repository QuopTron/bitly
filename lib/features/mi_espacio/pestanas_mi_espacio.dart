// ─────────────────────────────────────────────────────────────
// pestanas_mi_espacio.dart — Definición de las pestañas de Mi
// Espacio (Canciones, Playlists, Álbumes, Artistas) y la barra
// horizontal animada que las muestra y selecciona.
// Se conecta con: l10n + responsive + modelos de pestaña.
// Parte del flujo: Home → Mi Espacio (barra de pestañas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/responsive.dart';

/// Definición de una pestaña: etiqueta, icono e índice.
class DefinicionPestana {
  final String etiqueta;
  final IconData icono;
  final int indice;
  const DefinicionPestana(this.etiqueta, this.icono, this.indice);
}

/// Construye las 4 pestañas localizadas de Mi Espacio.
List<DefinicionPestana> construirPestanas(AppLocalizations loc) => [
  DefinicionPestana(loc.setup.miSpaceSongs, Icons.music_note, 0),
  DefinicionPestana(loc.setup.miSpacePlaylists, Icons.queue_music, 1),
  DefinicionPestana(loc.setup.miSpaceAlbums, Icons.album, 2),
  DefinicionPestana(loc.setup.miSpaceArtists, Icons.person, 3),
];

/// Barra horizontal de pestañas de Mi Espacio (chip animado).
class BarraPestanasMiEspacio extends StatelessWidget {
  final int pestanaSeleccionada;
  final ValueChanged<int> onCambioPestana;
  final Color onBg;
  final Color colorBrillo;

  const BarraPestanasMiEspacio({
    super.key,
    required this.pestanaSeleccionada,
    required this.onCambioPestana,
    required this.onBg,
    required this.colorBrillo,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final loc = AppLocalizations.of(context);
    final pestanas = construirPestanas(loc);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.spacingS, r.spacingM, r.spacingS, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(pestanas.length, (i) {
            final p = pestanas[i];
            final seleccionada = pestanaSeleccionada == i;
            return Padding(
              padding: EdgeInsets.only(right: r.spacingXS),
              child: GestureDetector(
                onTap: () => onCambioPestana(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: seleccionada
                        ? colorBrillo.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: seleccionada
                          ? colorBrillo.withValues(alpha: 0.5)
                          : onBg.withValues(alpha: 0.1),
                      width: seleccionada ? 1.0 : 0.6,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.spacingM,
                    vertical: r.spacingXS,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        p.icono,
                        size: r.footerSize + 1,
                        color: seleccionada
                            ? colorBrillo
                            : onBg.withValues(alpha: 0.45),
                      ),
                      SizedBox(width: r.spacingXS),
                      Text(
                        p.etiqueta,
                        style: TextStyle(
                          fontSize: r.footerSize,
                          fontWeight:
                              seleccionada ? FontWeight.w600 : FontWeight.normal,
                          color: seleccionada
                              ? colorBrillo
                              : onBg.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}