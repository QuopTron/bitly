// ─────────────────────────────────────────────────────────────
// controles_orden_mi_espacio.dart — Fila de chips de orden y
// filtro de Mi Espacio, con scroll horizontal. Recibe y devuelve
// los FiltrosMiEspacio por callback. Data-driven: una lista
// describe los chips y el build los genera.
// Se conecta con: modelo_filtros_mi_espacio + responsive.
// Parte del flujo: Home → Mi Espacio (controles de filtro).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../shared/utilidades/plataforma/responsive.dart';
import 'modelo_filtros_mi_espacio.dart';

import 'chip_filtro_mi_espacio.dart';

export 'modelo_filtros_mi_espacio.dart';

/// Un chip de filtro/orden: ícono, etiqueta, si está activo y qué hace.
typedef _Chip = ({
  IconData icon,
  String label,
  bool activo,
  FiltrosMiEspacio Function(FiltrosMiEspacio) aplicar,
});

/// Fila de chips de orden y filtros. Diseño horizontal scroll con
/// chips compactos que se iluminan al activarse.
class ControlesOrdenMiEspacio extends StatelessWidget {
  final FiltrosMiEspacio filtros;
  final ValueChanged<FiltrosMiEspacio> onFiltrosCambiados;
  final Color onBg;

  const ControlesOrdenMiEspacio({
    super.key,
    required this.filtros,
    required this.onFiltrosCambiados,
    required this.onBg,
  });

  /// Descripción de cada chip: el toque alterna orden o filtro.
  List<_Chip> _chips() => [
    // ── Orden ──
    (
      icon: Icons.sort_by_alpha_rounded,
      label: 'A-Z',
      activo: filtros.modoOrden == ModoOrden.az,
      aplicar: (f) => f.copiarCon(modoOrden: ModoOrden.az),
    ),
    (
      icon: Icons.sort_by_alpha_rounded,
      label: 'Z-A',
      activo: filtros.modoOrden == ModoOrden.azInvertido,
      aplicar: (f) => f.copiarCon(modoOrden: ModoOrden.azInvertido),
    ),
    (
      icon: Icons.equalizer_rounded,
      label: 'Escuchados',
      activo: filtros.modoOrden == ModoOrden.masEscuchados,
      aplicar: (f) => f.copiarCon(modoOrden: ModoOrden.masEscuchados),
    ),
    (
      icon: Icons.person_rounded,
      label: 'Artista',
      activo: filtros.modoOrden == ModoOrden.porArtista,
      aplicar: (f) => f.copiarCon(modoOrden: ModoOrden.porArtista),
    ),
    (
      icon: Icons.new_releases_rounded,
      label: 'Nuevos',
      activo: filtros.modoOrden == ModoOrden.nuevos,
      aplicar: (f) => f.copiarCon(modoOrden: ModoOrden.nuevos),
    ),
    // ── Filtros ──
    (
      icon: Icons.favorite_rounded,
      label: 'Amados',
      activo: filtros.soloAmados,
      aplicar: (f) => f.copiarCon(soloAmados: !f.soloAmados),
    ),
    (
      icon: Icons.download_rounded,
      label: 'Descargados',
      activo: filtros.soloDescargados,
      aplicar: (f) => f.copiarCon(soloDescargados: !f.soloDescargados),
    ),
    (
      icon: Icons.queue_music_rounded,
      label: 'Playlist',
      activo: filtros.soloConPlaylist,
      aplicar: (f) => f.copiarCon(soloConPlaylist: !f.soloConPlaylist),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return SizedBox(
      height: r.footerSize + 16,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.spacingS),
        children: [
          for (final chip in _chips()) ...[
            ChipFiltroMiEspacio(
              r: r,
              onBg: onBg,
              icon: chip.icon,
              label: chip.label,
              activo: chip.activo,
              onTap: () => onFiltrosCambiados(chip.aplicar(filtros)),
            ),
            SizedBox(width: r.spacingXS),
          ],
        ],
      ),
    );
  }
}
