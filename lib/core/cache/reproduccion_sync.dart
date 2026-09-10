// ─────────────────────────────────────────────────────────────
// reproduccion_sync.dart — Sincroniza los detalles obtenidos de
// las extensiones (álbum/playlist/artista) hacia las tablas drift
// locales, para uso offline y respaldo local.
// Se conecta con: base_datos (ContentDao, CollectionsDao) + modelos
// de detalle + backend_go (detalle_mixin llama estos métodos).
// Parte del flujo: detalle de álbum/playlist/artista.
// ─────────────────────────────────────────────────────────────

import 'package:drift/drift.dart';

import '../base_datos/app_database.dart';
import '../base_datos/daos/collections_dao.dart';
import '../base_datos/daos/content_dao.dart';
import '../modelos/detalle_album.dart';
import '../modelos/detalle_artista.dart';
import '../modelos/detalle_playlist.dart';

/// Sincroniza detalles de extensiones hacia drift local.
class ReproduccionSync {
  final ContentDao _contenido;
  final CollectionsDao _colecciones;

  ReproduccionSync(AppDatabase db)
      : _contenido = ContentDao(db),
        _colecciones = CollectionsDao(db);

  /// Guarda el detalle de álbum obtenido por extensión en drift local.
  Future<void> sincronizarDetalleAlbum(DetalleAlbum detalle, {String? fuente}) async {
    // Upsert del artista si hay nombre (el id real es desconocido, se usa
    // el id del álbum como placeholder).
    if (detalle.artistName != null && detalle.artistName!.isNotEmpty) {
      await _contenido.upsertArtist(ArtistsCompanion(
        id: Value(detalle.id),
        name: Value(detalle.artistName!),
        normalizedName: Value(detalle.artistName!.trim().toLowerCase()),
        provider: Value(fuente ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }

    await _contenido.upsertAlbum(AlbumsCompanion(
      id: Value(detalle.id),
      name: Value(detalle.name),
      normalizedName: Value(detalle.name.trim().toLowerCase()),
      artistId: Value(detalle.id), // placeholder
      coverUrl: Value(detalle.coverUrl ?? ''),
      coverPath: Value(detalle.coverPath ?? ''),
      releaseDate: Value(detalle.releaseDate ?? ''),
      albumType: Value(detalle.albumType ?? ''),
      totalTracks: Value(detalle.totalTracks),
      provider: Value(fuente ?? ''),
      createdAt: Value(DateTime.now()),
    ));

    for (final t in detalle.tracks) {
      await _contenido.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(detalle.id), // placeholder
        albumId: Value(detalle.id),
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? fuente ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }
  }

  /// Guarda el detalle de playlist obtenido por extensión en drift local.
  Future<void> sincronizarDetallePlaylist(DetallePlaylist detalle, {String? fuente}) async {
    // Upsert de la colección con su id real para que getDetallePlaylistLocal la encuentre.
    await _colecciones.upsert(CollectionsCompanion(
      id: Value(detalle.id),
      name: Value(detalle.name),
      coverPath: Value(detalle.coverPath ?? ''),
      type: const Value('playlist'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));

    // Upsert de tracks y alta como items de la colección.
    for (int i = 0; i < detalle.tracks.length; i++) {
      final t = detalle.tracks[i];
      await _contenido.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(t.trackId), // placeholder
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? fuente ?? ''),
        createdAt: Value(DateTime.now()),
      ));
      await _colecciones.addTrack(detalle.id, t.trackId);
    }
  }

  /// Guarda el detalle de artista obtenido por extensión en drift local.
  Future<void> sincronizarDetalleArtista(DetalleArtista detalle, {String? fuente}) async {
    await _contenido.upsertArtist(ArtistsCompanion(
      id: Value(detalle.id),
      name: Value(detalle.name),
      normalizedName: Value(detalle.name.trim().toLowerCase()),
      imageUrl: Value(detalle.imageUrl ?? ''),
      imagePath: Value(detalle.imagePath ?? ''),
      provider: Value(fuente ?? ''),
      createdAt: Value(DateTime.now()),
    ));

    for (final t in detalle.topTracks) {
      await _contenido.upsertTrack(TracksCompanion(
        id: Value(t.trackId),
        name: Value(t.name),
        artistId: Value(detalle.id),
        isrc: Value(t.isrc),
        durationMs: Value(t.durationMs),
        trackNumber: Value(t.trackNumber),
        coverUrl: Value(t.coverUrl ?? ''),
        coverPath: Value(t.coverPath ?? ''),
        source: Value(t.provider ?? fuente ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }

    for (final a in detalle.topAlbums) {
      await _contenido.upsertAlbum(AlbumsCompanion(
        id: Value(a.albumId),
        name: Value(a.name),
        normalizedName: Value(a.name.trim().toLowerCase()),
        artistId: Value(detalle.id),
        coverUrl: Value(a.coverUrl ?? ''),
        coverPath: Value(a.coverPath ?? ''),
        releaseDate: Value(a.releaseDate ?? ''),
        totalTracks: Value(a.totalTracks),
        provider: Value(fuente ?? ''),
        createdAt: Value(DateTime.now()),
      ));
    }
  }
}