import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/collections_table.dart';

part 'collections_dao.g.dart';

@DriftAccessor(tables: [Collections, CollectionItems])
class CollectionsDao extends DatabaseAccessor<AppDatabase> with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  Future<List<Collection>> getAll() => select(collections).get();

  Future<Collection?> get(String id) =>
      (select(collections)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(CollectionsCompanion entry) =>
      into(collections).insert(entry, mode: InsertMode.insertOrReplace);

  Future<String> create(String name, {String? coverPath, String? type}) {
    final id = 'col_${DateTime.now().millisecondsSinceEpoch}';
    return into(collections).insert(CollectionsCompanion(
      id: Value(id),
      name: Value(name),
      coverPath: Value(coverPath ?? ''),
      type: Value(type ?? 'playlist'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    )).then((_) => id);
  }

  Future<void> updateCollection(String id, String name, String coverPath) =>
      (update(collections)..where((t) => t.id.equals(id))).write(
        CollectionsCompanion(
          name: Value(name),
          coverPath: Value(coverPath),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateCover(String id, String coverPath) =>
      (update(collections)..where((t) => t.id.equals(id))).write(
        CollectionsCompanion(
          coverPath: Value(coverPath),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> removeCollection(String id) =>
      (delete(collections)..where((t) => t.id.equals(id))).go();

  Future<List<CollectionItem>> getTracks(String collectionId) =>
      (select(collectionItems)
            ..where((t) => t.collectionId.equals(collectionId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Future<void> addTrack(String collectionId, String trackId) =>
      into(collectionItems).insert(CollectionItemsCompanion(
        collectionId: Value(collectionId),
        itemId: Value(trackId),
        trackId: Value(trackId),
        addedAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrIgnore);

  Future<void> removeTrack(String collectionId, String trackId) =>
      (delete(collectionItems)
            ..where((t) =>
                t.collectionId.equals(collectionId) &
                t.itemId.equals(trackId)))
          .go();

  Future<int> getCollectionItemsCount() => select(collectionItems).get().then((r) => r.length);
}

