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
