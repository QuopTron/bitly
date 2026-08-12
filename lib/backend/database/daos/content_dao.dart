import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/content_tables.dart';
import '../tables/sources_table.dart';
import '../tables/artists_tables.dart';

part 'content_dao.g.dart';

@DriftAccessor(tables: [Artists, Albums, Tracks, Sources, Files, SimilarArtists])
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
          ..where((t) =>
              t.name.like(pattern) | t.isrc.equals(query))
          ..limit(20))
        .get();
  }

  // ── Sources ──

  Future<List<Source>> getSources(String trackId) =>
      (select(sources)..where((t) => t.trackId.equals(trackId))).get();

  Future<void> upsertSource(SourcesCompanion entry) =>
      into(sources).insertOnConflictUpdate(entry);

  // ── Files ──

  Future<List<File>> getFilesByTrack(String trackId) =>
      (select(files)..where((t) => t.trackId.equals(trackId))).get();

  Future<File?> getFileByPath(String path) =>
      (select(files)..where((t) => t.filePath.equals(path))).getSingleOrNull();

  Future<void> upsertFile(FilesCompanion entry) =>
      into(files).insertOnConflictUpdate(entry);

  Future<int> getArtistCount() => select(artists).get().then((r) => r.length);
  Future<int> getAlbumCount() => select(albums).get().then((r) => r.length);
  Future<int> getTrackCount() => select(tracks).get().then((r) => r.length);

  // ── Similar Artists ──

  Future<List<SimilarArtist>> getSimilarArtists(String artistId) =>
      (select(similarArtists)
            ..where((t) => t.artistId.equals(artistId))
            ..orderBy([(t) => OrderingTerm.desc(t.similarityScore)]))
          .get();

  Future<void> upsertSimilarArtist({
    required String artistId,
    required String similarArtistId,
    double score = 0.0,
  }) => into(similarArtists).insert(SimilarArtistsCompanion(
    artistId: Value(artistId),
    similarArtistId: Value(similarArtistId),
    similarityScore: Value(score),
    createdAt: Value(DateTime.now()),
  ), mode: InsertMode.insertOrReplace);

  Future<void> clearSimilarArtists(String artistId) =>
      (delete(similarArtists)..where((t) => t.artistId.equals(artistId))).go();
}

