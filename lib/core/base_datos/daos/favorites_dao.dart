// ---------------------------------------------------------------------------
// favorites_dao.dart — DAO de favoritos (tracks amados, albums, artistas, playlists). Se conecta con: app_database.dart + CacheFavoritos. Parte del flujo: Mi Espacio > Favoritos.
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/favorites_tables.dart';

part 'favorites_dao.g.dart';

@DriftAccessor(tables: [LovedTracks, FavoriteAlbums, FavoriteArtists, FavoritePlaylists])
class FavoritesDao extends DatabaseAccessor<AppDatabase> with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  // ── Loved Tracks ────────────────────────────────────────────────

  Future<List<LovedTrack>> getLovedTracks() => select(lovedTracks).get();
  Future<bool> isLoved(String trackId) =>
      (select(lovedTracks)..where((t) => t.trackId.equals(trackId)))
          .getSingleOrNull()
          .then((r) => r != null);

  Future<void> addLovedTrack({
    required String trackId,
    required String trackName,
    required String artistName,
    String? albumName,
    String? coverUrl,
    String? coverPath,
    String? isrc,
    int? durationMs,
    String? source,
  }) => into(lovedTracks).insertOnConflictUpdate(LovedTracksCompanion(
    trackId: Value(trackId),
    trackName: Value(trackName),
    artistName: Value(artistName),
    albumName: Value(albumName ?? ''),
    coverUrl: Value(coverUrl ?? ''),
    coverPath: Value(coverPath ?? ''),
    isrc: Value(isrc ?? ''),
    durationMs: Value(durationMs ?? 0),
    provider: Value(source ?? ''),
    addedAt: Value(DateTime.now()),
  ));

  Future<void> removeLovedTrack(String trackId) =>
      (delete(lovedTracks)..where((t) => t.trackId.equals(trackId))).go();

  /// Updates the locally cached cover path for a loved track.
  Future<void> updateLovedTrackCoverPath(String trackId, String coverPath) =>
      (update(lovedTracks)..where((t) => t.trackId.equals(trackId)))
          .write(LovedTracksCompanion(coverPath: Value(coverPath)));

  // ── Favorite Albums ─────────────────────────────────────────────

  Future<List<FavoriteAlbum>> getFavoriteAlbums() => select(favoriteAlbums).get();

  Future<void> addFavoriteAlbum({
    required String albumId,
    required String name,
    required String artistId,
    required String artistName,
    required String coverUrl,
    String? coverPath,
    String? provider,
  }) => into(favoriteAlbums).insert(FavoriteAlbumsCompanion(
    albumId: Value(albumId),
    name: Value(name),
    artistId: Value(artistId),
    artistName: Value(artistName),
    coverUrl: Value(coverUrl),
    coverPath: Value(coverPath ?? ''),
    provider: Value(provider ?? ''),
    addedAt: Value(DateTime.now()),
  ));

  Future<void> removeFavoriteAlbum(String albumId) =>
      (delete(favoriteAlbums)..where((t) => t.albumId.equals(albumId))).go();

  /// Updates the locally cached cover path for a favorite album (keeps the
  /// cover offline after the async saveCover finishes — without this the row
  /// keeps only the remote coverUrl and the grid card shows gray offline).
  Future<void> updateFavoriteAlbumCoverPath(String albumId, String coverPath) =>
      (update(favoriteAlbums)..where((t) => t.albumId.equals(albumId)))
          .write(FavoriteAlbumsCompanion(coverPath: Value(coverPath)));

  // ── Favorite Artists ────────────────────────────────────────────

  Future<List<FavoriteArtist>> getFavoriteArtists() => select(favoriteArtists).get();

  Future<void> addFavoriteArtist({
    required String artistId,
    required String name,
    required String imageUrl,
    String? imagePath,
  }) => into(favoriteArtists).insert(FavoriteArtistsCompanion(
    artistId: Value(artistId),
    name: Value(name),
    imageUrl: Value(imageUrl),
    imagePath: Value(imagePath ?? ''),
    provider: const Value(''),
    addedAt: Value(DateTime.now()),
  ));

  Future<void> removeFavoriteArtist(String artistId) =>
      (delete(favoriteArtists)..where((t) => t.artistId.equals(artistId))).go();

  /// Updates the locally cached image path for a favorite artist so the
  /// portrait survives restart (column is imagePath, not coverPath).
  Future<void> updateFavoriteArtistImagePath(String artistId, String imagePath) =>
      (update(favoriteArtists)..where((t) => t.artistId.equals(artistId)))
          .write(FavoriteArtistsCompanion(imagePath: Value(imagePath)));

  // ── Favorite Playlists ──────────────────────────────────────────

  Future<List<FavoritePlaylist>> getFavoritePlaylists() => select(favoritePlaylists).get();

  Future<void> addFavoritePlaylist(FavoritePlaylistsCompanion entry) =>
      into(favoritePlaylists).insertOnConflictUpdate(entry);

  Future<void> removeFavoritePlaylist(String playlistId) =>
      (delete(favoritePlaylists)..where((t) => t.playlistId.equals(playlistId))).go();

  /// Updates the locally cached cover path for a favorite playlist.
  Future<void> updateFavoritePlaylistCoverPath(String playlistId, String coverPath) =>
      (update(favoritePlaylists)..where((t) => t.playlistId.equals(playlistId)))
          .write(FavoritePlaylistsCompanion(coverPath: Value(coverPath)));
}


