// Test de la migración de esquema v4 → v5: las tablas "secretas"
// (secret_counters / secret_unlocks) deben desaparecer de una base que las
// tenía, la base tiene que quedar usable, y la migración no puede fallar si
// las tablas ya no estaban (upgrade desde una base parcial).
//
// Usa una base de archivo real porque hay que reabrirla dos veces: la primera
// para simular el estado viejo (v4 con las tablas), la segunda para dejar que
// drift corra el onUpgrade.

// Prefijado: `app_database.dart` exporta una tabla generada llamada `File`,
// que chocaría con la de dart:io.
import 'dart:io' as io;

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/base_datos/daos/settings_dao.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  /// Nombres de las tablas "secretas" que quedan en la base de [db].
  Future<List<String>> tablasSecretas(AppDatabase db) async {
    final filas =
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('secret_counters', 'secret_unlocks')",
            )
            .get();
    return filas.map((f) => f.read<String>('name')).toList();
  }

  Future<int> versionDe(AppDatabase db) async {
    final fila = await db.customSelect('PRAGMA user_version').getSingle();
    return fila.read<int>('user_version');
  }

  /// Deja una base en el estado de la v4: con las tablas secretas creadas.
  Future<void> sembrarV4(String archivo, {required bool conTablas}) async {
    final db = AppDatabase(NativeDatabase(io.File(archivo)));
    await db.customSelect('SELECT 1').get(); // fuerza la apertura
    if (conTablas) {
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS secret_counters '
        '(key TEXT NOT NULL PRIMARY KEY, value INTEGER)',
      );
      await db.customStatement(
        'CREATE TABLE IF NOT EXISTS secret_unlocks '
        '(key TEXT NOT NULL PRIMARY KEY, unlocked_at INTEGER NOT NULL)',
      );
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
      await tablasSecretas(db),
      conTablas ? hasLength(2) : isEmpty,
      reason: 'el archivo de prueba no quedó como una v4 real',
    );
    await db.close();
  }

  test('una base v4 pierde las tablas secretas y queda usable', () async {
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
    expect(await versionDe(db), 5, reason: 'debe quedar en la versión nueva');
    expect(
      await tablasSecretas(db),
      isEmpty,
      reason: 'las tablas secretas deben quedar dropeadas',
    );

    // La base sigue funcionando: un ciclo de escritura/lectura normal.
    final ajustes = SettingsDao(db);
    await ajustes.set('clave_de_prueba', 'valor');
    expect(await ajustes.get('clave_de_prueba'), 'valor');
  });

  test('la migración no falla si las tablas secretas ya no estaban', () async {
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

    expect(await versionDe(db), 5);
    final fila = await db.customSelect('SELECT 1 AS uno').getSingle();
    expect(fila.read<int>('uno'), 1);
  });

  test('una base nueva (v5) ya no crea las tablas secretas', () async {
    expect(
      disponible,
      isTrue,
      reason: 'SQLite nativo no disponible en el test',
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
    expect(await versionDe(db), 5);
    expect(await tablasSecretas(db), isEmpty);
  });
}
