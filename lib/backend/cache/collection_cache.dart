import '../database/app_database.dart';
import '../database/daos/collections_dao.dart';

/// User collections (playlists) local cache — wrappers over [CollectionsDao].
class CollectionCache {
  final CollectionsDao _c;
  CollectionCache(AppDatabase db) : _c = CollectionsDao(db);

  Future<String?> createCollection(String name, String coverPath) =>
      _c.create(name, coverPath: coverPath);

  Future<void> addCollectionTrack(String collectionId, String trackId) =>
      _c.addTrack(collectionId, trackId);

  Future<void> removeCollectionTrack(String collectionId, String trackId) =>
      _c.removeTrack(collectionId, trackId);

  Future<void> updateCollectionCover(String collectionId, String coverPath) =>
      _c.updateCover(collectionId, coverPath);

  Future<void> deleteCollection(String collectionId) =>
      _c.removeCollection(collectionId);
}

