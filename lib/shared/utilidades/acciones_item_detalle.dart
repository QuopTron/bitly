// ─────────────────────────────────────────────────────────────
// acciones_item_detalle.dart — PART de acciones_item.dart:
// helpers internos de las acciones — fetch del detalle de
// álbum/playlist a Go (con parseo seguro), conversión de tracks
// del detalle al mapa que espera el batch de descargas y snack de
// error cuando el detalle no se pudo cargar.
// Se conecta con: acciones_item.dart (misma library) + backend Go
// (fetchAlbumDetail/fetchPlaylistDetail) + modelos de detalle.
// Parte del flujo: acciones de ítem (lote/exportar).
// ─────────────────────────────────────────────────────────────

part of 'acciones_item.dart';

/// Fetch del detalle de álbum a Go (null si falla o viene vacío).
Future<DetalleAlbum?> _fetchDetalleAlbum(String albumId, String src) async {
  try {
    final json = await sl<BackendService>().fetchAlbumDetail(albumId, src);
    if (json.isEmpty || json == '{}') return null;
    return DetalleAlbum.desdeJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Fetch del detalle de playlist a Go (null si falla o viene vacío).
Future<DetallePlaylist?> _fetchDetallePlaylist(
    String playlistId, String src) async {
  try {
    final json = await sl<BackendService>().fetchPlaylistDetail(playlistId, src);
    if (json.isEmpty || json == '{}') return null;
    return DetallePlaylist.desdeJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Convierte tracks del detalle al mapa que espera el batch de descargas.
/// Incluye [cover_url] (la del track, o la del álbum/playlist como respaldo)
/// para que las descargas desde Feed/Búsqueda/Mi Espacio persistan la
/// carátula — antes se omitía y los tracks descargados quedaban sin cover
/// tras reiniciar.
List<Map<String, dynamic>> _tracksAMapas(
  List<TrackDetalle> tracks,
  String source, {
  String? coverUrlPadre,
}) {
  return tracks
      .map((t) => {
            'track_id': t.trackId,
            'track_title': t.name,
            'artist_name': t.artistName ?? '',
            'album_name': t.albumName ?? '',
            'source': t.provider ?? source,
            'isrc': t.isrc,
            'duration_ms': t.durationMs,
            'cover_url': (t.coverUrl?.isNotEmpty == true)
                ? t.coverUrl!
                : coverUrlPadre,
          })
      .toList();
}

/// Snack de error cuando no se pudo cargar el detalle (álbum/playlist).
void _snackError(ScaffoldMessengerState messenger, bool esAlbum) {
  messenger.showSnackBar(SnackBar(
    content: Text(esAlbum
        ? 'No se pudo cargar el álbum'
        : 'No se pudo cargar la playlist'),
    duration: const Duration(seconds: 2),
  ));
}