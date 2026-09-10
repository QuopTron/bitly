// ─────────────────────────────────────────────────────────────
// reproduccion_detalle_local.dart — Construye los detalles de
// álbum/artista/playlist desde las tablas drift LOCALES (para
// mostrarlos sin red o como respaldo del fetch por extensión).
// Se conecta con: base_datos (ContentDao, CollectionsDao,
// PlayHistoryDao) + modelos de detalle.
// Parte del flujo: detalle de álbum/artista/playlist (offline/local).
// ─────────────────────────────────────────────────────────────

import '../base_datos/app_database.dart';
import '../base_datos/daos/collections_dao.dart';
import '../base_datos/daos/content_dao.dart';
import '../base_datos/daos/play_history_dao.dart';
import '../modelos/detalle_album.dart';
import '../modelos/detalle_album_ligero.dart';
import '../modelos/detalle_artista.dart';
import '../modelos/detalle_playlist.dart';
import '../modelos/detalle_track.dart';

part 'reproduccion_detalle_artista_local.dart';
part 'reproduccion_detalle_playlist_local.dart';

/// Construye vistas de detalle desde drift local.
class ReproduccionDetalleLocal
    with ReproduccionDetalleArtistaLocal, ReproduccionDetallePlaylistLocal {
  @override
  final ContentDao _contenido;
  @override
  final PlayHistoryDao _historial;
  @override
  final CollectionsDao _colecciones;

  ReproduccionDetalleLocal(AppDatabase db)
      : _contenido = ContentDao(db),
        _historial = PlayHistoryDao(db),
        _colecciones = CollectionsDao(db);

  // ── Artista (ver reproduccion_detalle_artista_local.dart) ──

  // ── Álbum ───────────────────────────────────────────────────

  /// Arma un DetalleAlbum desde drift local, o null si no existe.
  Future<DetalleAlbum?> getDetalleAlbumLocal(String albumId) async {
    final album = await _contenido.getAlbum(albumId);
    if (album == null) return null;

    final tracksAlbum = await _contenido.getTracksByAlbum(albumId);
    final artista = await _contenido.getArtist(album.artistId);

    final tracks = tracksAlbum.map((t) => TrackDetalle(
      trackId: t.id,
      name: t.name,
      durationMs: t.durationMs ?? 0,
      trackNumber: t.trackNumber ?? 0,
      isrc: t.isrc ?? '',
      coverUrl: t.coverUrl,
      coverPath: t.coverPath,
      artistName: artista?.name,
      albumName: album.name,
      provider: t.source,
    )).toList();

    return DetalleAlbum(
      id: album.id,
      name: album.name,
      coverUrl: album.coverUrl,
      coverPath: album.coverPath,
      artistName: artista?.name,
      releaseDate: album.releaseDate,
      albumType: album.albumType,
      totalTracks: album.totalTracks ?? 0,
      tracks: tracks,
    );
  }

  // ── Playlist ────────────────────────────────────────────────
  // (getDetallePlaylistLocal está en reproduccion_detalle_playlist_local.dart)
}