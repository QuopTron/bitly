// ---------------------------------------------------------------------------
// settings_table.dart — Tabla clave/valor de ajustes de la app. Se conecta con: daos/settings_dao.dart. Parte del flujo: persistencia de ajustes (tema, locale, descargas).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

