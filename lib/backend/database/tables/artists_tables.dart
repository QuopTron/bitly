import 'package:drift/drift.dart';
import 'content_tables.dart';

/// Stores similar artist relationships synced from extension data.
class SimilarArtists extends Table {
  TextColumn get artistId => text().references(Artists, #id, onDelete: KeyAction.cascade)();
  TextColumn get similarArtistId => text().references(Artists, #id, onDelete: KeyAction.cascade)();
  RealColumn get similarityScore => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {artistId, similarArtistId};
}

