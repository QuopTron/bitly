// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentDaoMixin on DatabaseAccessor<AppDatabase> {
  $ArtistsTable get artists => attachedDatabase.artists;
  $AlbumsTable get albums => attachedDatabase.albums;
  $TracksTable get tracks => attachedDatabase.tracks;
  $SourcesTable get sources => attachedDatabase.sources;
  $FilesTable get files => attachedDatabase.files;
  $SimilarArtistsTable get similarArtists => attachedDatabase.similarArtists;
  ContentDaoManager get managers => ContentDaoManager(this);
}

class ContentDaoManager {
  final _$ContentDaoMixin _db;
  ContentDaoManager(this._db);
  $$ArtistsTableTableManager get artists =>
      $$ArtistsTableTableManager(_db.attachedDatabase, _db.artists);
  $$AlbumsTableTableManager get albums =>
      $$AlbumsTableTableManager(_db.attachedDatabase, _db.albums);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db.attachedDatabase, _db.sources);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db.attachedDatabase, _db.files);
  $$SimilarArtistsTableTableManager get similarArtists =>
      $$SimilarArtistsTableTableManager(
        _db.attachedDatabase,
        _db.similarArtists,
      );
}
