// ---------------------------------------------------------------------------
// content_dao.dart — DAO de contenido musical: artistas, albums, tracks, fuentes y archivos. Se conecta con: app_database.dart + caches. Parte del flujo: biblioteca local (Mi Espacio).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import '../../app_database.dart';
import '../../tables/musica/base/content_tables.dart';
import '../../tables/musica/artistas/artists_tables.dart';

part 'content_dao.g.dart';
part 'content_dao_biblioteca.dart';

@DriftAccessor(tables: [Artists, Albums, Tracks, SimilarArtists])
class ContentDao extends DatabaseAccessor<AppDatabase> with _$ContentDaoMixin {
  ContentDao(super.db);

  // ── Artists ──

  Future<Artist?> getArtist(String id) =>
      (select(artists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertArtist(ArtistsCompanion entry) =>
      into(artists).insertOnConflictUpdate(entry);

  // ── Albums ──

  Future<List<Album>> getAlbumsByArtist(String artistId) =>
      (select(albums)..where((t) => t.artistId.equals(artistId))).get();

  Future<Album?> getAlbum(String id) =>
      (select(albums)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Álbum por id sin distinguir mayúsculas.
  ///
  /// Los ids que viajan en las claves de descarga van normalizados en
  /// minúsculas, pero la tabla guarda el id tal como lo dio la fuente
  /// ("5K79FLRUCSysQnVESLcTdb"): comparar exacto perdía el álbum y con él su
  /// nombre y su carátula.
  Future<Album?> getAlbumPorIdNormalizado(String id) =>
      (select(
        albums,
      )..where((t) => t.id.lower().equals(id.toLowerCase()))).getSingleOrNull();

  /// Escribe la carátula local del álbum (no inventa la fila si no existe).
  Future<void> actualizarCaratulaAlbum(
    String albumId,
    String coverUrl,
    String coverPath,
  ) async {
    final album = await getAlbumPorIdNormalizado(albumId);
    if (album == null) return;
    await (update(albums)..where((t) => t.id.equals(album.id))).write(
      AlbumsCompanion(
        coverUrl: coverUrl.isNotEmpty ? Value(coverUrl) : const Value.absent(),
        coverPath:
            coverPath.isNotEmpty ? Value(coverPath) : const Value.absent(),
      ),
    );
  }

  /// Escribe la carátula local del track de la biblioteca, por id o por ISRC
  /// (el id del proveedor puede venir vacío y el ISRC es el que identifica).
  Future<void> actualizarCaratulaTrack(
    String trackId,
    String isrc,
    String coverUrl,
    String coverPath,
  ) async {
    if (coverUrl.isEmpty && coverPath.isEmpty) return;
    Track? fila = await getTrack(trackId);
    if (fila == null && isrc.isNotEmpty) {
      fila = await getTrackByIsrc(isrc);
    }
    if (fila == null) return;
    final id = fila.id;
    await (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
        coverUrl: coverUrl.isNotEmpty ? Value(coverUrl) : const Value.absent(),
        coverPath:
            coverPath.isNotEmpty ? Value(coverPath) : const Value.absent(),
      ),
    );
  }

  Future<void> upsertAlbum(AlbumsCompanion entry) =>
      into(albums).insertOnConflictUpdate(entry);

  // ── Tracks ──

  Future<List<Track>> getTracksByAlbum(String albumId) =>
      (select(tracks)..where((t) => t.albumId.equals(albumId))).get();

  Future<List<Track>> getTracksByArtist(String artistId) =>
      (select(tracks)..where((t) => t.artistId.equals(artistId))).get();

  Future<Track?> getTrack(String id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Track?> getTrackByIsrc(String isrc) =>
      (select(tracks)..where((t) => t.isrc.equals(isrc))).getSingleOrNull();

  Future<void> upsertTrack(TracksCompanion entry) =>
      into(tracks).insertOnConflictUpdate(entry);

  Future<List<Track>> searchTracks(String query) {
    final pattern = '%$query%';
    return (select(tracks)
          ..where((t) => t.name.like(pattern) | t.isrc.equals(query))
          ..limit(20))
        .get();
  }

  Future<int> getArtistCount() => select(artists).get().then((r) => r.length);
  Future<int> getAlbumCount() => select(albums).get().then((r) => r.length);
  Future<int> getTrackCount() => select(tracks).get().then((r) => r.length);
}
