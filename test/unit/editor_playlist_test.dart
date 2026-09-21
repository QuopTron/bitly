// ─────────────────────────────────────────────────────────────
// editor_playlist_test.dart — Prueba el guardado REAL de playlists
// contra una base drift en memoria: crear con sus canciones en orden,
// editar (quitar las que sobran, renombrar y cambiar portada) y que
// cada canción quede en la biblioteca local con su artista.
//
// Por qué importa: `collection_items` solo guarda ids; si la canción
// no está en `tracks`, el detalle de la playlist no puede mostrar ni
// nombre ni artista.
//
// Si el entorno no expone SQLite nativo, el test se saltea.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/base_datos/daos/biblioteca/colecciones/collections_dao.dart';
import 'package:bitly/core/base_datos/daos/contenido/content_dao.dart';
import 'package:bitly/core/cache/almacenes/biblioteca/base/cache_colecciones.dart';
import 'package:bitly/core/cache/almacenes/musica/cache_detalle_memoria.dart';
import 'package:bitly/core/cache/reproduccion/detalle/reproduccion_detalle_local.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/servicios/playlist/editor/editor_playlist.dart';
// Solo Value: `isNotNull` de drift choca con el de matcher.
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ServicioEditorPlaylist editor;
  late CollectionsDao colecciones;
  late ContentDao contenido;
  var disponible = true;

  ItemFeed track(String id, String nombre, {String artista = 'Bad Bunny'}) =>
      ItemFeed(
        id: id,
        type: 'track',
        name: nombre,
        artists: artista,
        coverUrl: 'https://cdn/$id.jpg',
        source: 'spotify-web',
        durationMs: 1000,
        isrc: 'ISRC$id',
      );

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      disponible = false;
    }
  });

  setUp(() {
    if (!disponible) return;
    editor = ServicioEditorPlaylist(
      db,
      CacheColecciones(db),
      CacheDetalleMemoria(),
    );
    colecciones = CollectionsDao(db);
    contenido = ContentDao(db);
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  test('crear deja la playlist con sus canciones, en orden', () async {
    expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
    final id = await editor.guardar(
      nombre: 'Mi mix',
      portada: '',
      items: [track('t1', 'Uno'), track('t2', 'Dos')],
    );
    expect(id, isNotNull);
    expect(id, startsWith('col_'));

    expect(await colecciones.getTrackIds(id!), ['t1', 't2']);
    final coleccion = await colecciones.get(id);
    expect(coleccion?.name, 'Mi mix');
  });

  test('cada canción queda en la biblioteca local, con su artista', () async {
    expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
    final id = await editor.guardar(
      nombre: 'Con biblioteca',
      portada: '',
      items: [track('b1', 'NUEVAYoL'), track('b2', 'VOY A LLeVARTE PA PR')],
    );

    final detalle = await ReproduccionDetalleLocal(
      db,
    ).getDetallePlaylistLocal(id!);
    expect(detalle, isNotNull);
    expect(detalle!.tracks.map((t) => t.name), [
      'NUEVAYoL',
      'VOY A LLeVARTE PA PR',
    ]);
    // Sin esto, la playlist mostraba canciones sin intérprete.
    expect(detalle.tracks.first.artistName, 'Bad Bunny');
    expect(detalle.itemCount, 2);
  });

  test(
    'dos canciones del mismo artista comparten la fila de artista',
    () async {
      expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
      final id = await editor.guardar(
        nombre: 'Mismo artista',
        portada: '',
        items: [track('m1', 'Una'), track('m2', 'Otra')],
      );
      expect(id, isNotNull);
      final una = await contenido.getTrack('m1');
      final otra = await contenido.getTrack('m2');
      expect(
        una?.artistId,
        otra?.artistId,
        reason: 'mismo artista = misma fila',
      );
      final artista = await contenido.getArtist(una!.artistId);
      expect(artista?.name, 'Bad Bunny');
    },
  );

  test('editar quita las que sobran, renombra y cambia la portada', () async {
    expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
    final id = await editor.guardar(
      nombre: 'Antes',
      portada: 'https://cdn/vieja.jpg',
      items: [track('e1', 'Uno'), track('e2', 'Dos')],
    );
    expect(id, isNotNull);

    await editor.guardar(
      playlistId: id,
      nombre: 'Después',
      portada: 'https://cdn/nueva.jpg',
      items: [track('e2', 'Dos'), track('e3', 'Tres')],
    );

    expect(await colecciones.getTrackIds(id!), ['e2', 'e3']);
    final coleccion = await colecciones.get(id);
    expect(coleccion?.name, 'Después');
    expect(coleccion?.coverPath, 'https://cdn/nueva.jpg');
  });

  test(
    'no pisa la carátula local ya descargada de una canción existente',
    () async {
      expect(disponible, isTrue, reason: 'SQLite nativo no disponible');
      final ahora = DateTime.now();
      await db
          .into(db.artists)
          .insert(
            ArtistsCompanion.insert(
              id: 'art_previo',
              name: 'Bad Bunny',
              normalizedName: 'bad bunny',
              createdAt: ahora,
            ),
          );
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              id: 'p1',
              name: 'NUEVAYoL',
              artistId: 'art_previo',
              albumId: '',
              coverUrl: const Value('https://cdn/p1.jpg'),
              coverPath: const Value('/tmp/descargada.jpg'),
              lyricsPath: const Value('/tmp/p1.lrc'),
              createdAt: ahora,
            ),
          );

      final id = await editor.guardar(
        nombre: 'Respetuosa',
        portada: '',
        items: [track('p1', 'NUEVAYoL')],
      );
      expect(id, isNotNull);

      final fila = await contenido.getTrack('p1');
      expect(fila?.coverPath, '/tmp/descargada.jpg');
      expect(fila?.lyricsPath, '/tmp/p1.lrc');
      expect(fila?.coverUrl, 'https://cdn/p1.jpg');
    },
  );
}
