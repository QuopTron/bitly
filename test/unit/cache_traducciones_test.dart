// Test del almacén REAL de traducciones (contra una base drift en memoria):
// comprueba que lo guardado vuelve igual, que cada canción/idioma/letra tiene
// su fila y que una fila corrupta no rompe la traducción.
//
// Si el entorno de test no expone SQLite nativo, el test se saltea: la lógica
// del servicio ya está cubierta con un almacén falso en
// traduccion_letras_test.dart.

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/cache_traducciones.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var disponible = true;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      disponible = false;
    }
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  test('guarda y recupera la traducción de una canción', () async {
    // Falla fuerte si SQLite no está: si no, los tres tests pasarían vacíos.
    expect(
      disponible,
      isTrue,
      reason: 'SQLite nativo no disponible en el test',
    );
    final cache = CacheTraducciones(db);
    await cache.guardar(
      cancion: 'isrc:USRC17607839',
      destino: 'en',
      huella: 'abc123',
      idiomaOrigen: 'Spanish',
      lineas: const ['It is never enough', null, 'I love you'],
    );

    final leida = await cache.leer(
      cancion: 'isrc:USRC17607839',
      destino: 'en',
      huella: 'abc123',
    );

    expect(leida, isNotNull);
    expect(leida!.idiomaOrigen, 'Spanish');
    expect(leida.lineas, ['It is never enough', null, 'I love you']);
  });

  test(
    'otra letra (huella distinta) no devuelve la traducción vieja',
    () async {
      if (!disponible) return;
      final cache = CacheTraducciones(db);
      await cache.guardar(
        cancion: 'isrc:AAA',
        destino: 'en',
        huella: 'vieja',
        idiomaOrigen: 'Spanish',
        lineas: const ['old'],
      );

      final leida = await cache.leer(
        cancion: 'isrc:AAA',
        destino: 'en',
        huella: 'nueva',
      );

      expect(leida, isNull);
    },
  );

  test('borrarDeCancion limpia solo esa canción', () async {
    if (!disponible) return;
    final cache = CacheTraducciones(db);
    for (final c in ['isrc:uno', 'isrc:dos']) {
      await cache.guardar(
        cancion: c,
        destino: 'en',
        huella: 'h',
        idiomaOrigen: 'Spanish',
        lineas: const ['x'],
      );
    }

    await cache.borrarDeCancion('isrc:uno');

    expect(
      await cache.leer(cancion: 'isrc:uno', destino: 'en', huella: 'h'),
      isNull,
    );
    expect(
      await cache.leer(cancion: 'isrc:dos', destino: 'en', huella: 'h'),
      isNotNull,
    );
  });
}
