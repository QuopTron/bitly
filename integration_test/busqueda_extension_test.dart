// Test en EMULADOR de la búsqueda por extensión, contra el backend Go real que
// va dentro del APK y contra las extensiones reales.
//
// QUÉ FIJA ESTE TEST
//
//  1. El selector de fuentes NO ofrece "Todas" ni proveedores de respaldo.
//     Buscar en todas a la vez metía en la lista resultados de Internet Archive
//     y Soulseek, que no son catálogos navegables: existen para que el pipeline
//     consiga el FLAC exacto detrás de un ISRC (ver
//     go_backend/internal/gobackend/search_fuentes.go). El backend ya no los
//     evalúa como fuentes y la UI ya no los ofrece.
//
//  2. Buscar en UNA extensión devuelve resultados de ESA extensión. Antes,
//     buscar en "Todas" mandaba el id canónico "tracks" y cada extensión lo
//     descartaba en silencio (Deezer declara "track", en singular) y devolvía
//     vacío; ahora el backend traduce al id del manifest de cada extensión.
//
//  3. La búsqueda espera a que el usuario TERMINE de escribir. Con el debounce
//     de 150ms, quien escribe despacio veía resultados de medio título. Ahora
//     la consulta sale recién tras la pausa de escritura, y este test lo mide
//     con el contador de generación del backend (un número que solo cambia
//     cuando sale una búsqueda nueva).
//
// Necesita internet para el punto 2 (Deezer busca sin cuenta ni sesión).
//
// Correr:
//   flutter test integration_test/busqueda_extension_test.dart -d emulator-5554

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:bitly/app/inyeccion.dart' as inj;
import 'package:bitly/core/backend_go/plataformas/backend_android.dart';
import 'package:bitly/core/cache/almacenes/cache_ajustes.dart';
import 'package:bitly/core/cache/almacenes/cache_busqueda.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:bitly/estado/descargas/cubit_descargas.dart';
import 'package:bitly/estado/like/cubit_like.dart';
import 'package:bitly/estado/playlists/cubit_playlists.dart';
import 'package:bitly/estado/reproductor/cubit_reproductor.dart';
import 'package:bitly/features/busqueda/bloc/busqueda_bloc.dart';
import 'package:bitly/features/busqueda/bloc/busqueda_evento.dart';
import 'package:bitly/features/busqueda/pagina/pagina_busqueda.dart';
import 'package:bitly/features/tutorial_interactivo/motor/tutorial_pasos.dart';
import 'package:bitly/l10n/app_localizations.dart';

/// Pausa de escritura del producto. Si cambia en pagina_busqueda.dart, este
/// test deja de medir lo que cree medir: por eso está escrito acá, explícito.
const _pausaEscritura = Duration(milliseconds: 650);

/// Host mínimo que monta la página de búsqueda con los MISMOS providers que el
/// ensamblador de la app (ensamblador_home.dart), sin el resto del shell.
class _HostBusqueda extends StatelessWidget {
  const _HostBusqueda();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CubitCola>.value(value: inj.sl<CubitCola>()),
        BlocProvider<CubitLikes>.value(value: inj.sl<CubitLikes>()),
        BlocProvider<CubitDescargas>.value(value: inj.sl<CubitDescargas>()),
        BlocProvider<CubitPlaylists>.value(value: inj.sl<CubitPlaylists>()),
        BlocProvider<CubitReproductor>.value(value: inj.sl<CubitReproductor>()),
        BlocProvider<BlocBusqueda>(
          create: (_) => BlocBusqueda(BackendAndroid(), inj.sl<CacheBusqueda>())
            ..add(const FuenteBusquedaCambiada('deezer')),
        ),
      ],
      child: const Scaffold(body: PaginaBusqueda()),
    );
  }
}

Widget _appDePrueba() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const _HostBusqueda(),
  );
}

/// Bombea frames durante [veces] * 100 ms. El reloj del dispositivo corre de
/// verdad: un `Future` en vuelo no agenda frames y `pumpAndSettle` lo ignoraría.
Future<void> _bombear(WidgetTester tester, {int veces = 45}) async {
  for (var i = 0; i < veces; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Corre una búsqueda en streaming y junta los lotes hasta que el backend
/// termina o se agota la ventana.
Future<List<ItemFeed>> _buscar(
  WidgetTester tester,
  BackendAndroid backend, {
  required String query,
  required String type,
  required String source,
}) async {
  final gen = await backend.searchStreaming(
    query: query,
    source: source,
    type: type,
    limit: 25,
  );
  expect(gen, greaterThan(0),
      reason: 'el backend debe aceptar la búsqueda (source="$source")');

  var items = <ItemFeed>[];
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final poll = await backend.getSearchStreamResults();
    if (poll.generation != gen) continue;
    items = poll.items;
    if (poll.done) break;
  }
  return items;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // El CubitReproductor (uno de los providers del host) construye media_kit:
    // sin esto el árbol entero explota al montarse, igual que en main.dart.
    MediaKit.ensureInitialized();
    await inj.configurarDependencias();
  });

  testWidgets(
    'el selector de fuentes no ofrece "Todas" ni proveedores de respaldo',
    (tester) async {
      // Fuente persistida conocida: el test no depende de lo que haya guardado
      // una corrida anterior en el emulador.
      await inj.sl<CacheAjustes>().guardarAjuste('search_source', 'deezer');

      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();
      // La config de búsqueda llega por RPC: hay que darle tiempo a que el
      // selector se arme con las fuentes reales del backend.
      await _bombear(tester, veces: 20);

      // Abrir el selector de extensiones (vive en la barra de búsqueda).
      final trigger = find.byKey(keyTutorialFuente);
      expect(trigger, findsOneWidget, reason: 'debe estar el selector de fuente');
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      // Nada de "Todas": cada búsqueda apunta a UNA extensión.
      expect(
        find.text('Todas'),
        findsNothing,
        reason: 'el selector no debe ofrecer un modo "Todas"',
      );
      // Ni proveedores de respaldo: no son catálogos navegables.
      for (final respaldo in const [
        'Internet Archive',
        'Soulseek',
        'Flac Rescue',
        'Redacted',
        'Musicbrainz',
      ]) {
        expect(
          find.text(respaldo),
          findsNothing,
          reason: '$respaldo no debe ofrecerse como fuente de búsqueda',
        );
      }
      // Y sí un catálogo real: si el filtro borrara todo, lo de arriba pasaría
      // por vacío.
      expect(
        find.text('Deezer'),
        findsWidgets,
        reason: 'Deezer debe seguir en el selector',
      );
    },
  );

  testWidgets(
    'buscar en una extensión devuelve resultados SOLO de ESA extensión',
    (tester) async {
      final backend = BackendAndroid();
      expect(await backend.healthCheck(), isTrue,
          reason: 'el backend Go debe inicializarse dentro del APK');

      // Las fuentes salen del backend, no de una lista escrita a mano: si
      // mañana cambia cuál es la primaria, el test sigue apuntando a una real.
      final config = await backend.getSearchConfig();
      final candidatas =
          config.map((c) => c.source).where((s) => s.isNotEmpty).toList();
      expect(candidatas, isNotEmpty,
          reason: 'el backend debe exponer sus fuentes de búsqueda');

      // Y ninguna candidata puede ser un proveedor de respaldo.
      for (final s in candidatas) {
        expect(
          s.toLowerCase(),
          isNot(anyOf('internetarchive', 'soulseek', 'flac-rescue', 'redacted',
              'musicbrainz')),
          reason: '$s no debería estar en la config de búsqueda',
        );
      }

      // Internet puede fallar o limitar el ritmo de UNA extensión: se prueban
      // las fuentes hasta que una responda. Lo que se verifica no es "Deezer
      // anda" sino la AISLACIÓN: una búsqueda por extensión solo trae resultados
      // de esa extensión.
      List<ItemFeed> items = const [];
      String? fuente;
      for (final s in candidatas) {
        items = await _buscar(
          tester,
          backend,
          query: 'Daft Punk One More Time',
          type: 'tracks',
          source: s,
        );
        if (items.isNotEmpty) {
          fuente = s;
          break;
        }
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(fuente, isNotNull,
          reason: 'ninguna extensión devolvió resultados para la misma '
              'consulta; revisá la red del emulador o la traducción de filtros '
              '(extensiones probadas: $candidatas)');

      final tracks = items.where((it) => it.type == 'track').toList();
      expect(tracks, isNotEmpty, reason: 'deben llegar canciones');

      // Una sola extensión: TODOS los resultados declaran la MISMA fuente. Si
      // apareciera otra, el backend volvió a mezclar fuentes en una búsqueda
      // que pidió una sola.
      for (final t in tracks) {
        expect(
          (t.source ?? '').toLowerCase(),
          fuente!.toLowerCase(),
          reason: 'la búsqueda pidió "$fuente" y llegó "${t.source}"',
        );
      }

      // Ningún resultado puede venir de un proveedor de respaldo.
      for (final it in items) {
        expect(
          (it.source ?? '').toLowerCase(),
          isNot(anyOf('internetarchive', 'soulseek', 'flac-rescue', 'redacted')),
          reason: 'un proveedor de respaldo se coló en la búsqueda: ${it.source}',
        );
      }

      // Dedupe: el mismo ISRC no puede aparecer dos veces.
      final isrcs = tracks
          .map((t) => (t.isrc ?? '').trim().toUpperCase())
          .where((i) => i.isNotEmpty)
          .toList();
      expect(isrcs.length, isrcs.toSet().length,
          reason: 'hay ISRC repetidos: el dedupe no está funcionando');
    },
  );

  testWidgets(
    'la búsqueda espera a que el usuario termine de escribir',
    (tester) async {
      final backend = BackendAndroid();
      await inj.sl<CacheAjustes>().guardarAjuste('search_source', 'deezer');

      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();
      await _bombear(tester, veces: 20);

      final campo = find.byType(TextField);
      expect(campo, findsOneWidget, reason: 'debe estar el campo de búsqueda');

      // Generación ANTES de escribir: el número solo cambia cuando sale una
      // búsqueda nueva, así que es la forma de observar el debounce sin red.
      final antes = (await backend.getSearchStreamResults()).generation;

      // Escritura PAUSADA: cada tecla con menos de la pausa de escritura de la
      // anterior. Con el debounce viejo (150ms) ya habría salido una búsqueda
      // por cada letra.
      final pasoTecla = _pausaEscritura ~/ 2; // bien por debajo de la pausa
      for (final texto in const ['D', 'Da', 'Daf', 'Daft']) {
        await tester.enterText(campo, texto);
        await tester.pump(pasoTecla);
      }

      final durante = (await backend.getSearchStreamResults()).generation;
      expect(
        durante,
        antes,
        reason: 'no debe salir ninguna búsqueda mientras el usuario escribe '
            '(generación $antes → $durante)',
      );

      // Ahora sí: se soltó el teclado. Pasada la pausa, la búsqueda sale.
      var despues = durante;
      for (var i = 0; i < 30 && despues == durante; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        despues = (await backend.getSearchStreamResults()).generation;
      }
      expect(
        despues,
        isNot(antes),
        reason: 'pasada la pausa de escritura la búsqueda debe salir',
      );
    },
  );
}
