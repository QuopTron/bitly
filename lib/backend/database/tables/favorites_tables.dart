import 'package:drift/drift.dart';

@TableIndex(name: 'idx_loved_added_at', columns: {#addedAt})
class LovedTracks extends Table {
  TextColumn get trackId => text()();
  TextColumn get trackName => text()();
  TextColumn get artistName => text()();
  TextColumn? get albumName => text().nullable()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  TextColumn? get isrc => text().nullable()();
  IntColumn? get durationMs => integer().nullable()();
  TextColumn? get provider => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {trackId};
}

@TableIndex(name: 'idx_fav_album_added_at', columns: {#addedAt})
class FavoriteAlbums extends Table {
  TextColumn get albumId => text()();
  TextColumn get name => text()();
  TextColumn get artistId => text()();
  TextColumn get artistName => text()();
  TextColumn get coverUrl => text()();
  TextColumn? get coverPath => text().nullable()();
  TextColumn? get provider => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {albumId};
}

@TableIndex(name: 'idx_fav_artist_added_at', columns: {#addedAt})
class FavoriteArtists extends Table {
  TextColumn get artistId => text()();
  TextColumn get name => text()();
  TextColumn get imageUrl => text()();
  TextColumn? get imagePath => text().nullable()();
  TextColumn? get provider => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {artistId};
}

@TableIndex(name: 'idx_fav_playlist_added_at', columns: {#addedAt})
class FavoritePlaylists extends Table {
  TextColumn get playlistId => text()();
  TextColumn get name => text()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  TextColumn? get description => text().nullable()();
  TextColumn? get provider => text().nullable()();
  TextColumn? get externalUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {playlistId};
}

