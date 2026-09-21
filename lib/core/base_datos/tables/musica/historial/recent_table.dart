// ---------------------------------------------------------------------------
// recent_table.dart — Tabla de recientes: busquedas. Se conecta con: daos/recent_dao.dart. Parte del flujo: Busqueda (historial).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

@TableIndex(name: 'idx_recent_searches_date', columns: {#searchedAt})
class RecentSearches extends Table {
  TextColumn get query => text()();
  DateTimeColumn get searchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {query};
}
