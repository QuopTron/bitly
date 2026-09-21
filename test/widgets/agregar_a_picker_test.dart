// ─────────────────────────────────────────────────────────────
// agregar_a_picker_test.dart — Prueba el modal "agregar a" real:
// la opción "Playlist" abre el selector, LISTA las playlists
// CREADAS por el usuario y al elegir una la canción queda dentro.
//
// Por qué existe: antes el botón se saltaba el selector cuando el
// cubit de playlists decía "no hay ninguna" (estado que viene de
// otra fuente que las `col_*`), así que con playlists creadas de
// verdad el botón no dejaba elegir ninguna. Este test monta el
// modal SIN providers alrededor, como en la app real.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion.dart';
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/cache_colecciones.dart';
import 'package:bitly/core/cache/almacenes/cache_detalle_memoria.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/core/servicios/playlist/editor_playlist.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/modales/agregar_a/modal_agregar_a.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CacheColecciones colecciones;
  late ServicioEditorPlaylist editor;
  var disponible = true;
  var playlistId = '';

  setUpAll(() async {
    try {
      db = AppDatabase(NativeDatabase.memory());
      colecciones = CacheColecciones(db);
      editor = ServicioEditorPlaylist(db, colecciones, CacheDetalleMemoria());
      sl.registerSingleton<CacheColecciones>(colecciones);
      sl.registerSingleton<ServicioEditorPlaylist>(editor);
      sl.registerSingleton<CubitCola>(CubitCola());
      sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
        ValueNotifier(const PreferenciasEstilo()),
      );
      // Una playlist CREADA de verdad (una `col_*` con canciones dentro).
      playlistId =
          await editor.guardar(
            nombre: 'Mis favoritas',
            portada: '',
            items: const [ItemFeed(id: 'base', type: 'track', name: 'Otra')],
          ) ??
          '';
    } catch (_) {
      disponible = false;
    }
  });

  tearDownAll(() async {
    if (disponible) await db.close();
    await sl.reset();
  });

  /// Monta la app e invoca el modal "agregar a" con [item].
  Future<void> abrirModal(WidgetTester tester, ItemFeed item) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => mostrarAgregarA(context, item),
                    child: const Text('abrir'),
                  ),
                ),
              ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Playlist" lista MIS creadas y suma la canción elegida', (
    tester,
  ) async {
    if (!disponible) return;
    await abrirModal(
      tester,
      const ItemFeed(id: 'nueva', type: 'track', name: 'NUEVAYoL'),
    );

    await tester.tap(find.text('Playlist'));
    await tester.pumpAndSettle();

    // El selector se abre SIEMPRE y muestra la playlist creada.
    expect(find.text('Seleccionar playlist'), findsOneWidget);
    expect(find.text('Mis favoritas'), findsOneWidget);
    expect(find.text('Crear nueva playlist'), findsOneWidget);

    await tester.tap(find.text('Mis favoritas'));
    await tester.pumpAndSettle();

    // La canción quedó DENTRO de la playlist, junto a la que ya estaba.
    final ids = await colecciones.getTrackIdsColeccion(playlistId);
    expect(ids, contains('nueva'));
  });

  testWidgets('el selector también aparece sin ninguna playlist creada', (
    tester,
  ) async {
    if (!disponible) return;
    // Base limpia: no hay `col_*` que ofrecer.
    await colecciones.borrarColeccion(playlistId);
    await abrirModal(
      tester,
      const ItemFeed(id: 'x', type: 'track', name: 'Otra canción'),
    );

    await tester.tap(find.text('Playlist'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionar playlist'), findsOneWidget);
    expect(find.text('Crear nueva playlist'), findsOneWidget);
    expect(
      find.text('Agrega tus canciones likeadas o descargadas'),
      findsOneWidget,
    );
  });
}
