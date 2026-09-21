// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites_dao.dart';

// ignore_for_file: type=lint
mixin _$FavoritesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LovedTracksTable get lovedTracks => attachedDatabase.lovedTracks;
  $FavoriteAlbumsTable get favoriteAlbums => attachedDatabase.favoriteAlbums;
  $FavoriteArtistsTable get favoriteArtists => attachedDatabase.favoriteArtists;
  $FavoritePlaylistsTable get favoritePlaylists =>
      attachedDatabase.favoritePlaylists;
  FavoritesDaoManager get managers => FavoritesDaoManager(this);
}

class FavoritesDaoManager {
  final _$FavoritesDaoMixin _db;
  FavoritesDaoManager(this._db);
  $$LovedTracksTableTableManager get lovedTracks =>
      $$LovedTracksTableTableManager(_db.attachedDatabase, _db.lovedTracks);
  $$FavoriteAlbumsTableTableManager get favoriteAlbums =>
      $$FavoriteAlbumsTableTableManager(
        _db.attachedDatabase,
        _db.favoriteAlbums,
      );
  $$FavoriteArtistsTableTableManager get favoriteArtists =>
      $$FavoriteArtistsTableTableManager(
        _db.attachedDatabase,
        _db.favoriteArtists,
      );
  $$FavoritePlaylistsTableTableManager get favoritePlaylists =>
      $$FavoritePlaylistsTableTableManager(
        _db.attachedDatabase,
        _db.favoritePlaylists,
      );
}
