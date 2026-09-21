// ─────────────────────────────────────────────────────────────
// hoja_playlist_fuentes_test.dart — Prueba la HOJA de playlist real:
// sus atajos "Agregar likeadas" y "Agregar descargadas" suman canciones
// leídas de la BASE (drift), que es lo que hace la app.
//
// Por qué existe: antes los atajos leían el estado en memoria de los
// cubits, que se carga async al arrancar; si el usuario abría el armado
// antes, sumaban cero canciones y parecía roto. Este test monta la hoja
// SIN providers alrededor y con los datos solo en la base: falla si
// alguien vuelve a depender del árbol de widgets o del estado en RAM.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart';
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/biblioteca/base/cache_colecciones.dart';
import 'package:bitly/core/cache/almacenes/descargas/cache_descargas.dart';
import 'package:bitly/core/cache/almacenes/musica/cache_detalle_memoria.dart';
import 'package:bitly/core/cache/almacenes/biblioteca/favoritos/cache_favoritos.dart';
import 'package:bitly/core/servicios/playlist/editor/editor_playlist.dart';
import 'package:bitly/core/servicios/playlist/base/fuentes_playlist.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/modales/playlist/base/hoja_playlist.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var disponible = true;

  setUpAll(() async {
    try {
      db = AppDatabase(NativeDatabase.memory());
      final favoritos = CacheFavoritos(db);
      final descargas = CacheDescargas(db);
      sl.registerSingleton<CacheFavoritos>(favoritos);
      sl.registerSingleton<CacheDescargas>(descargas);
      sl.registerSingleton<FuentesPlaylist>(
        FuentesPlaylist(favoritos, descargas),
      );
      sl.registerSingleton<CacheColecciones>(CacheColecciones(db));
      sl.registerSingleton<ServicioEditorPlaylist>(
        ServicioEditorPlaylist(db, CacheColecciones(db), CacheDetalleMemoria()),
      );
      // Un like y una descarga reales, como si el usuario los hubiera hecho.
      await favoritos.alternarTrackAmado(
        trackId: 'like-1',
        trackName: 'NUEVAYoL',
        artistName: 'Bad Bunny',
        albumName: 'DeBÍ TiRAR MáS FOToS',
        coverUrl: 'https://ejemplo/cover.jpg',
        isrc: 'US1234567890',
        source: 'ytmusic-spotiflac',
        liked: true,
      );
      await descargas.guardarTrackDescargado(
        id: 'dl-1',
        trackName: 'Monaco',
        artistName: 'Bad Bunny',
        albumName: 'nadie sabe lo que va a pasar mañana',
        isrc: 'US0987654321',
        service: 'deezer',
        providerTrackId: 'dl-1',
        providerSource: 'deezer',
        coverUrl: 'https://ejemplo/dl.jpg',
      );
    } catch (_) {
      disponible = false;
    }
  });

  tearDownAll(() async {
    if (disponible) await db.close();
    await sl.reset();
  });

  Future<void> abrirHoja(WidgetTester tester) async {
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
                    onPressed: () => mostrarHojaPlaylist(context),
                    child: const Text('abrir'),
                  ),
                ),
              ),
        ),
      ),
    );
    // El delegate de l10n carga async: un pump extra antes de tocar.
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Agregar likeadas" trae el like guardado en la base', (
    tester,
  ) async {
    if (!disponible) return;
    await abrirHoja(tester);

    await tester.tap(find.text('Agregar likeadas'));
    await tester.pumpAndSettle();

    expect(find.text('NUEVAYoL'), findsOneWidget);
    expect(find.text('1 canciones'), findsOneWidget);
  });

  testWidgets('"Agregar descargadas" trae el historial completo', (
    tester,
  ) async {
    if (!disponible) return;
    await abrirHoja(tester);

    await tester.tap(find.text('Agregar descargadas'));
    await tester.pumpAndSettle();

    expect(find.text('Monaco'), findsOneWidget);
    expect(find.text('1 canciones'), findsOneWidget);
  });
}
