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

part of '../base/resultados_busqueda.dart';

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

/// Scroll de resultados: `CustomScrollView` con el padding del miniplayer
/// alrededor de todos los slivers.
///
/// Por qué slivers: la lista de resultados se armaba COMPLETA (todas las
/// cabeceras, todas las tarjetas y todas las grillas con `shrinkWrap`) antes de
/// pintar el primer frame. Con slivers se construye por índice visible, así una
/// búsqueda de 60 resultados ya no paga las 60 tarjetas de entrada.
Widget _listado(BuildContext context, Responsive r, List<Widget> slivers) {
  // La apariencia se escucha UNA vez, envolviendo el scroll entero: al mover
  // los controles de Ajustes → Apariencia los slivers se reconstruyen igual
  // que antes, pero sin necesidad de envolver cada grilla (que es lo que
  // obligaba a tener cajas alrededor de slivers).
  return ValueListenableBuilder<PreferenciasApariencia>(
    valueListenable: AparienciaHelper.notifier(),
    builder:
        (context, _, _) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: r.spacingS,
                bottom: r.spacingS + r.val(120, 100, 150),
              ),
              // `SliverMainAxisGroup` encadena los slivers como si fueran una
              // sola lista, así el padding de arriba/abajo cae donde toca.
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        ),
  );
}
