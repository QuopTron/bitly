// Test de la migración de esquema hacia v6: las tablas que quedaron sin un
// solo lector ni escritor (secret_counters, secret_unlocks, recent_access,
// files, download_queue, hidden_download_ids y sources) deben desaparecer de
// una base que las tenía, la base
// tiene que quedar usable, y la migración no puede fallar si ya no estaban
// (upgrade desde una base parcial).
//
// Usa una base de archivo real porque hay que reabrirla dos veces: la primera
// para simular el estado viejo (v4 con las tablas), la segunda para dejar que
// drift corra el onUpgrade.

// Se importa dart:io prefijado para que `File`/`Directory` no se confundan con
// las clases de drift.
import 'dart:io' as io;

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/base_datos/daos/sistema/ajustes/settings_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tablas que la migración debe llevarse: quedaron sin uso real.
const _tablasMuertas = <String>[
  'secret_counters',
  'secret_unlocks',
  'recent_access',
  'files',
  'download_queue',
  'hidden_download_ids',
  'sources',
];

void main() {
  late io.Directory carpeta;
  var disponible = true;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      carpeta = io.Directory.systemTemp.createTempSync('bitly_migracion_');
    } catch (_) {
      disponible = false;
    }
  });

  tearDownAll(() {
    if (disponible && carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  /// De las tablas muertas, las que siguen existiendo en la base de [db].
  Future<List<String>> tablasMuertas(AppDatabase db) async {
    final lista = _tablasMuertas.map((t) => "'$t'").join(', ');
    final filas =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ($lista)",
            )
            .get();
    return filas.map((f) => f.read<String>('name')).toList();
  }

  Future<int> versionDe(AppDatabase db) async {
    final fila = await db.customSelect('PRAGMA user_version').getSingle();
    return fila.read<int>('user_version');
  }

  /// Deja una base en el estado de la v4: con las tablas muertas creadas.
  Future<void> sembrarV4(String archivo, {required bool conTablas}) async {
    final db = AppDatabase(NativeDatabase(io.File(archivo)));
    await db.customSelect('SELECT 1').get(); // fuerza la apertura
    if (conTablas) {
      for (final crear in _crearTablasMuertas) {
        await db.customStatement(crear);
      }
      // Una fila real: aunque nadie las leía, el DROP debe llevárselas igual.
      await db.customStatement(
        "INSERT OR REPLACE INTO secret_counters (key, value) VALUES ('demo', 3)",
      );
    }
    await db.customStatement('PRAGMA user_version = 4');
    // El sembrado se valida solo: si el archivo no quedara realmente en v4 con
    // las tablas dentro, los tests de abajo pasarían en vacío (drift no
    // correría ninguna migración).
    expect(await versionDe(db), 4);
    expect(
      await tablasMuertas(db),
      conTablas ? hasLength(_tablasMuertas.length) : isEmpty,
      reason: 'el archivo de prueba no quedó como una v4 real',
    );
    await db.close();
  }

  test('una base v4 pierde las tablas muertas y queda usable', () async {
    expect(
      disponible,
      isTrue,
      reason: 'SQLite nativo no disponible en el test',
    );
    final archivo = '${carpeta.path}/v4_con_tablas.db';
    await sembrarV4(archivo, conTablas: true);

    final db = AppDatabase(NativeDatabase(io.File(archivo)));
    addTearDown(db.close);

    // Antes de tocar nada la migración ya corrió al abrir.
    expect(
      await versionDe(db),
      db.schemaVersion,
      reason: 'debe quedar en la versión nueva',
    );
    expect(
      await tablasMuertas(db),
      isEmpty,
      reason: 'las tablas sin uso deben quedar dropeadas',
    );

    // La base sigue funcionando: un ciclo de escritura/lectura normal.
    final ajustes = SettingsDao(db);
    await ajustes.set('clave_de_prueba', 'valor');
    expect(await ajustes.get('clave_de_prueba'), 'valor');
  });

  test('la migración no falla si las tablas muertas ya no estaban', () async {
    expect(
      disponible,
      isTrue,
      reason: 'SQLite nativo no disponible en el test',
    );
    final archivo = '${carpeta.path}/v4_sin_tablas.db';
    await sembrarV4(archivo, conTablas: false);

    // Sin DROP IF EXISTS esto reventaría y dejaría la app sin abrir.
    final db = AppDatabase(NativeDatabase(io.File(archivo)));
    addTearDown(db.close);

    expect(await versionDe(db), db.schemaVersion);
    final fila = await db.customSelect('SELECT 1 AS uno').getSingle();
    expect(fila.read<int>('uno'), 1);
  });

  test('una base nueva ya no crea las tablas muertas', () async {
    expect(
      disponible,
      isTrue,
      reason: 'SQLite nativo no disponible en el test',
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
    expect(await versionDe(db), db.schemaVersion);
    expect(await tablasMuertas(db), isEmpty);
  });
}

/// CREATE TABLE de cada tabla muerta, con el nombre y las columnas mínimas que
/// tenían antes de eliminarse (alcanza para probar el DROP).
const _crearTablasMuertas = <String>[
  'CREATE TABLE IF NOT EXISTS secret_counters '
      '(key TEXT NOT NULL PRIMARY KEY, value INTEGER)',
  'CREATE TABLE IF NOT EXISTS secret_unlocks '
      '(key TEXT NOT NULL PRIMARY KEY, unlocked_at INTEGER NOT NULL)',
  'CREATE TABLE IF NOT EXISTS recent_access '
      '(key TEXT NOT NULL PRIMARY KEY, item_json TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS files '
      '(id TEXT NOT NULL PRIMARY KEY, file_path TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS download_queue '
      '(id TEXT NOT NULL PRIMARY KEY, status TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS hidden_download_ids '
      '(download_id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE IF NOT EXISTS sources '
      '(id TEXT NOT NULL PRIMARY KEY, track_id TEXT NOT NULL, provider TEXT)',
];
