import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/cache_tables.dart';

part 'cache_dao.g.dart';

@DriftAccessor(tables: [JsonCache])
class CacheDao extends DatabaseAccessor<AppDatabase> with _$CacheDaoMixin {
  CacheDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(jsonCache)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.json;
  }

  Future<int?> getTimestamp(String key) async {
    final row = await (select(jsonCache)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.timestamp;
  }

  Future<void> set(String key, String json) async {
    await into(jsonCache).insertOnConflictUpdate(JsonCacheCompanion(
      key: Value(key),
      json: Value(json),
      timestamp: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> remove(String key) async {
    await (delete(jsonCache)..where((t) => t.key.equals(key))).go();
  }

  Future<void> removeByPrefix(String prefix) async {
    await (delete(jsonCache)..where((t) => t.key.like('$prefix%'))).go();
  }

  Future<void> clearAll() async {
    await delete(jsonCache).go();
  }
}

