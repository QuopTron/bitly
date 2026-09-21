// ─────────────────────────────────────────────────────────────
// biblioteca_caratulas_index_test.dart — Prueba el índice REAL de
// carátulas de la biblioteca (contra una base drift en memoria):
// el álbum aporta nombre y URL de portada cuando el registro de la
// descarga los perdió, la portada local solo entra si el archivo
// existe, y una ruta MUERTA no tapa la URL remota.
//
// Si el entorno no expone SQLite nativo el test se saltea: la lógica
// pura de respaldo ya está cubierta en caratulas_mi_espacio_test.dart.
// ─────────────────────────────────────────────────────────────

// Prefijado: app_database exporta una tabla llamada `File`.
import 'dart:io' as io;

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/features/mi_espacio/datos/datos_mi_espacio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late io.Directory temp;
  var disponible = true;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    temp = io.Directory.systemTemp.createTempSync('bitly_biblioteca');
    try {
      db = AppDatabase(NativeDatabase.memory());
      di.sl.registerSingleton<AppDatabase>(db);
    } catch (_) {
      disponible = false;
      return;
    }
    final ahora = DateTime.now();
    await db
        .into(db.artists)
        .insert(
          ArtistsCompanion.insert(
            id: '5K79FLRUCSysQnVESLcTdb',
            name: 'Bad Bunny',
            normalizedName: 'bad bunny',
            createdAt: ahora,
          ),
        );
    // Álbum con portada SOLO remota (el caso que dejaba la tarjeta gris).
    await db
        .into(db.albums)
        .insert(
          AlbumsCompanion.insert(
            id: '5K79FLRUCSysQnVESLcTdb',
            artistId: '5K79FLRUCSysQnVESLcTdb',
            name: 'DeBÍ TiRAR MÁS FOToS',
            normalizedName: 'debi tirar mas fotos',
            coverUrl: const Value('https://i.scdn.co/image/ab67616d.jpg'),
            createdAt: ahora,
          ),
        );
    // Canción cuya portada local existe de verdad.
    final archivoVivo = io.File(
      '${temp.path}${io.Platform.pathSeparator}viva.jpg',
    )..writeAsBytesSync([1, 2, 3]);
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            id: '5TFD2bmFKGhoCRbX61nXY5',
            name: 'NUEVAYoL',
            artistId: '5K79FLRUCSysQnVESLcTdb',
            albumId: '5K79FLRUCSysQnVESLcTdb',
            coverUrl: const Value('https://i.scdn.co/image/remota.jpg'),
            coverPath: Value(archivoVivo.path),
            createdAt: ahora,
          ),
        );
    // Canción con portada local MUERTA: debe caer a la URL remota.
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            id: '59D4DOkspUbWyMmbAPQkxZ',
            name: 'VOY A LLeVARTE PA PR',
            artistId: '5K79FLRUCSysQnVESLcTdb',
            albumId: '5K79FLRUCSysQnVESLcTdb',
            coverUrl: const Value('https://i.scdn.co/image/otra.jpg'),
            coverPath: Value(
              '${temp.path}${io.Platform.pathSeparator}no_esta.jpg',
            ),
            createdAt: ahora,
          ),
        );
    await refrescarBibliotecaLocal();
  });

  tearDownAll(() async {
    if (disponible) await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('el índice cubre álbumes y canciones por ID normalizado', () {
    expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
    final indice = bibliotecaLocal;
    expect(indice['5k79flrucsysqnveslctdb']?.nombre, 'DeBÍ TiRAR MÁS FOToS');
    expect(indice['5tfd2bmfkghocrbx61nxy5']?.nombre, 'NUEVAYoL');
  });

  test('la portada local viva gana; la muerta cae a la URL remota', () {
    final indice = bibliotecaLocal;
    expect(indice['5tfd2bmfkghocrbx61nxy5']?.caratula, endsWith('viva.jpg'));
    expect(
      indice['59d4dokspubwymmbapqkxz']?.caratula,
      'https://i.scdn.co/image/otra.jpg',
    );
  });

  test('un álbum sin portada local igual aporta su URL remota', () {
    expect(
      bibliotecaLocal['5k79flrucsysqnveslctdb']?.caratula,
      'https://i.scdn.co/image/ab67616d.jpg',
    );
  });
}
