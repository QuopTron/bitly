// ─────────────────────────────────────────────────────────────
// chips_tipo_busqueda.dart — Chips de categoría de búsqueda
// (burbujas) de la fuente activa: filtra por tracks/artistas/
// álbumes/playlists según los filtros del manifest de la
// extensión. La burbuja seleccionada resalta con vidrio más
// intenso y el icono/etiqueta viene del manifest o del l10n.
// Se conecta con: constantes_fuente + config_busqueda_fuente +
// vidrio + l10n + responsive + colores_app.
// Parte del flujo: búsqueda (filtro por categoría).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/modelos/config_busqueda_fuente.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constantes/constantes_fuente.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/responsive.dart';
import '../../../shared/widgets/contenedor_vidrio.dart';

/// Chips de categoría de búsqueda (burbujas) de la fuente activa.
class ChipsTipoBusqueda extends StatelessWidget {
  /// Categoría de filtro activa (canónica) o null para mostrar todas juntas.
  final String? tipoSeleccionado;

  /// Burbujas de la fuente actual, del manifest.
  final List<ConfigFiltroBusqueda> filtros;
  final ValueChanged<String?> onTipoCambiado;

  const ChipsTipoBusqueda({
    super.key,
    required this.tipoSeleccionado,
    required this.filtros,
    required this.onTipoCambiado,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);
    final loc = AppLocalizations.of(context);

    if (filtros.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtros.map((f) {
            final cat = categoriaBusquedaDe(f.id);
            final sel = tipoSeleccionado == cat;
            return Padding(
              padding: EdgeInsets.only(right: r.spacingXS),
              child: GestureDetector(
                onTap: () => onTipoCambiado(cat),
                child: ContenedorVidrio(
                  borderRadius: 22,
                  borderColor: sel
                      ? onBg.withValues(alpha: 0.2)
                      : onBg.withValues(alpha: 0.08),
                  bgColor:
                      sel ? onBg.withValues(alpha: 0.1) : Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: r.spacingM + 2,
                    vertical: r.spacingXS + 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconoFiltroBusqueda(f.icon, cat),
                        size: r.footerSize + 3,
                        color: sel ? onBg : onBg.withValues(alpha: 0.5),
                      ),
                      SizedBox(width: r.spacingXS),
                      Text(
                        _etiquetaTipo(cat, f.label, loc),
                        style: TextStyle(
                          fontSize: r.subtitleSize,
                          color: sel ? onBg : onBg.withValues(alpha: 0.55),
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _etiquetaTipo(String cat, String etiquetaManifest, AppLocalizations loc) {
    if (etiquetaManifest.isNotEmpty) return etiquetaManifest;
    switch (cat) {
      case 'tracks':
        return loc.setup.searchTracks;
      case 'artists':
        return loc.setup.searchArtists;
      case 'albums':
        return loc.setup.searchAlbums;
      case 'playlists':
        return loc.setup.searchPlaylists;
      default:
        return cat;
    }
  }
}