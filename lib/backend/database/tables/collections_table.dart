import 'package:drift/drift.dart';
import 'content_tables.dart';

@TableIndex(name: 'idx_collections_updated_at', columns: {#updatedAt})
class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn? get type => text().nullable()();
  TextColumn? get coverPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn? get customJson => text().nullable()();
  TextColumn? get itemJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_col_items_collection_id', columns: {#collectionId})
class CollectionItems extends Table {
  TextColumn get collectionId => text().references(Collections, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemId => text()();
  TextColumn? get trackId => text().references(Tracks, #id, onDelete: KeyAction.setNull).nullable()();
  TextColumn? get itemJson => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  IntColumn get position => integer().nullable()();

  @override
  Set<Column> get primaryKey => {collectionId, itemId};
}

