import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> remove(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  Future<Map<String, String>> getAll() async {
    final rows = await select(appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<void> setAll(Map<String, String> values) =>
      batch((b) {
        for (final e in values.entries) {
          b.insert(appSettings, AppSettingsCompanion(
            key: Value(e.key),
            value: Value(e.value),
            updatedAt: Value(DateTime.now()),
          ), mode: InsertMode.insertOrReplace);
        }
      });
}

