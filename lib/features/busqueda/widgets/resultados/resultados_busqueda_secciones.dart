// ─────────────────────────────────────────────────────────────
// resultados_busqueda_secciones.dart — PART de
// resultados_busqueda.dart: helpers de agrupación y cabeceras de
// los resultados — normalización de categoría, etiquetas
// localizadas, ListView con padding del miniplayer y cabeceras de
// sección por categoría y por fuente (icono + nombre + count).
// Las vistas agrupadas viven en resultados_busqueda_vistas.dart.
// Se conecta con: resultados_busqueda.dart (misma library) +
// constantes_fuente + l10n.
// Parte del flujo: búsqueda (resultados agrupados).
// ─────────────────────────────────────────────────────────────

part of 'resultados_busqueda.dart';

/// Icono por categoría canónica para las cabeceras de sección.
const _iconoPorCategoria = <String, IconData>{
  'tracks': Icons.music_note,
  'artists': Icons.person,
  'albums': Icons.album,
  'playlists': Icons.playlist_play,
};

/// Normaliza el tipo crudo del backend a la categoría canónica.
String _categoriaDe(String crudo) {
  switch (crudo) {
    case 'track':
    case 'tracks':
      return 'tracks';
    case 'artist':
    case 'artists':
      return 'artists';
    case 'album':
    case 'albums':
      return 'albums';
    case 'playlist':
    case 'playlists':
      return 'playlists';
    default:
      return crudo;
  }
}

/// Etiqueta localizada de una categoría canónica.
String _etiquetaCategoria(AppLocalizations loc, String cat) {
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

/// ListView con padding inferior para el miniplayer.
Widget _listado(BuildContext context, Responsive r, List<Widget> children) {
  return ListView(
    padding: EdgeInsets.only(
      top: r.spacingS,
      bottom: r.spacingS + r.val(120, 100, 150),
    ),
    children: children,
  );
}

/// Cabecera de sección por categoría (icono + nombre + count).
Widget _cabeceraSeccion(
  BuildContext context,
  String cat,
  int count,
  Responsive r,
  Color colorBrillo,
  Color onBg,
) {
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
    child: Row(
      children: [
        Icon(
          _iconoPorCategoria[cat] ?? Icons.search,
          size: 18,
          color: onBg.withValues(alpha: 0.6),
        ),
        SizedBox(width: r.spacingS),
        Text(
          _etiquetaCategoria(AppLocalizations.of(context), cat),
          style: TextStyle(
            fontSize: r.subtitleSize + 4,
            fontWeight: FontWeight.bold,
            color: onBg,
          ),
        ),
        SizedBox(width: r.spacingXS),
        Text(
          '($count)',
          style: TextStyle(
            fontSize: r.footerSize + 1,
            color: onBg.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Cabecera de sección por fuente (icono de la extensión + count).
Widget _cabeceraFuente(
  BuildContext context,
  String fuente,
  int count,
  Responsive r,
  Color colorBrillo,
  Color onBg,
) {
  return Padding(
    padding: EdgeInsets.fromLTRB(r.spacingS + 4, r.spacingM, r.spacingS, r.spacingS),
    child: Row(
      children: [
        Icon(
          iconosFuente[fuente] ?? Icons.cloud_outlined,
          size: 18,
          color: onBg.withValues(alpha: 0.6),
        ),
        SizedBox(width: r.spacingS),
        Text(
          nombreFuente(fuente),
          style: TextStyle(
            fontSize: r.subtitleSize + 4,
            fontWeight: FontWeight.bold,
            color: onBg,
          ),
        ),
        SizedBox(width: r.spacingXS),
        Text(
          '($count)',
          style: TextStyle(
            fontSize: r.footerSize + 1,
            color: onBg.withValues(alpha: 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}