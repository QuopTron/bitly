// ---------------------------------------------------------------------------
// secrets_table.dart — Tablas de secretos del sistema (contadores y desbloqueos ocultos). Se conecta con: daos (premium/settings). Parte del flujo: features ocultas.
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

class SecretCounters extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class SecretUnlocks extends Table {
  TextColumn get key => text()();
  DateTimeColumn get unlockedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

