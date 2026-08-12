import 'package:drift/drift.dart';

@TableIndex(name: 'idx_artists_name', columns: {#normalizedName})
class Artists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  TextColumn? get imageUrl => text().nullable()();
  TextColumn? get imagePath => text().nullable()();
  TextColumn? get provider => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_albums_artist_id', columns: {#artistId})
class Albums extends Table {
  TextColumn get id => text()();
  TextColumn get artistId => text().references(Artists, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get normalizedName => text()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  TextColumn? get releaseDate => text().nullable()();
  IntColumn get totalTracks => integer().nullable()();
  TextColumn? get albumType => text().nullable()();
  TextColumn? get provider => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_tracks_artist_id', columns: {#artistId})
@TableIndex(name: 'idx_tracks_album_id', columns: {#albumId})
@TableIndex(name: 'idx_tracks_isrc', columns: {#isrc})
class Tracks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get artistId => text().references(Artists, #id, onDelete: KeyAction.cascade)();
  TextColumn? get albumId => text().references(Albums, #id, onDelete: KeyAction.setNull)();
  TextColumn? get isrc => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get totalTracks => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get totalDiscs => integer().nullable()();
  TextColumn? get releaseDate => text().nullable()();
  TextColumn? get genre => text().nullable()();
  TextColumn? get composer => text().nullable()();
  TextColumn? get label => text().nullable()();
  TextColumn? get copyright => text().nullable()();
  TextColumn? get coverUrl => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  TextColumn? get videoPath => text().nullable()();
  TextColumn? get lyricsPath => text().nullable()();
  TextColumn? get spotifyId => text().nullable()();
  TextColumn? get source => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

