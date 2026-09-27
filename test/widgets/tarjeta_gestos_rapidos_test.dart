// tarjeta_gestos_rapidos_test.dart — Fija que los gestos de la tarjeta de
// canción respeten lo configurado en Ajustes → Apariencia → Acciones rápidas.
//
// Lo que protege:
//  · con el mapa de fábrica (solo deslizar a la derecha), la tarjeta envuelve
//    el gesto de siempre y no agrega nada más;
//  · dos toques ejecutan la acción elegida (antes no existía el gesto);
//  · deslizar hacia el lado apagado NO dispara nada;
//  · con todos los gestos en "nada" la tarjeta sigue tocándose normal;
//  · un fling sobre una lista que scrollea NO dispara la acción (era el
//    "scroll falso": la lista se movía y encima se ejecutaba el gesto), pero
//    el gesto vuelve a andar cuando la lista ya no puede moverse más.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/core/modelos/ajustes_acciones_rapidas.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/tarjetas/track/base/tarjeta_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';
  const cancion = ItemFeed(
    id: 'tr-1',
    type: 'track',
    name: 'Una canción',
    artists: 'Un artista',
    albumId: 'al-1',
    albumName: 'Un álbum',
    source: 'deezer',
  );

  setUpAll(() {
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(PreferenciasEstilo.normal),
    );
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
  });

  setUp(() {
    // Cada prueba arranca con los gestos de fábrica.
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto;
  });

  /// App con [cartas] tarjetas: con más de una, la lista SÍ scrollea.
  Widget appLarga({
    required int cartas,
    VoidCallback? onTap,
    VoidCallback? onLike,
    VoidCallback? onInfo,
  }) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Scaffold(
      body: ListView(
        children: [
          for (var i = 0; i < cartas; i++)
            SizedBox(
              height: 120,
              child: TarjetaTrack(
                titulo: 'Una canción',
                subtitulo: 'Un artista',
                coverUrl: cover,
                estadoDescarga: EstadoDescarga.ninguno,
                onTap: onTap,
                onLike: onLike,
                onInfo: onInfo,
                item: cancion,
              ),
            ),
        ],
      ),
    ),
  );

  /// App con una sola tarjeta (en un `ListView` que no tiene para dónde
  /// scrollear).
  Widget app({
    VoidCallback? onTap,
    VoidCallback? onLike,
    VoidCallback? onInfo,
  }) => appLarga(cartas: 1, onTap: onTap, onLike: onLike, onInfo: onInfo);

  /// Un tirón vertical rápido (60 px en 16 ms) sobre la tarjeta [indice].
  Future<void> flick(WidgetTester tester, double dy, {int indice = 0}) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byType(TarjetaTrack).at(indice)),
    );
    await g.moveBy(Offset(0, dy), timeStamp: const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await g.up(timeStamp: const Duration(milliseconds: 32));
    await tester.pumpAndSettle();
  }

  /// Un arrastre vertical REALISTA sobre la tarjeta [indice]: varios pasos
  /// chicos en muy poco tiempo (144 px en 48 ms = 3000 px/s, bastante más que
  /// el umbral del gesto). Es la forma en la que el dedo scrollea la lista.
  Future<void> arrastrarRapido(
    WidgetTester tester, {
    double porPaso = -12,
    int pasos = 12,
    int indice = 0,
  }) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byType(TarjetaTrack).at(indice)),
    );
    for (var i = 0; i < pasos; i++) {
      await g.moveBy(
        Offset(0, porPaso),
        timeStamp: Duration(milliseconds: 4 * (i + 1)),
      );
      await tester.pump(const Duration(milliseconds: 4));
    }
    await g.up(timeStamp: Duration(milliseconds: 4 * (pasos + 1)));
    await tester.pumpAndSettle();
  }

  testWidgets('de fábrica no hay gesto vertical ni de dos toques', (
    tester,
  ) async {
    var likes = 0;
    await tester.pumpWidget(app(onLike: () => likes++));
    await tester.pump();

    // El gesto de fábrica es sólo deslizar a la derecha (Dismissible): no hay
    // escucha vertical ni detector de dos toques.
    expect(find.byKey(const ValueKey('gesto-vertical')), findsNothing);
    final verticales = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .where((g) => g.onVerticalDragEnd != null);
    expect(verticales, isEmpty);

    await tester.tap(find.text('Una canción'), warnIfMissed: false);
    await tester.pump();
    expect(likes, 0);
  });

  testWidgets('un tirón hacia arriba ejecuta la acción elegida', (
    tester,
  ) async {
    var likes = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      arriba: AccionRapida.meGusta,
    );
    await tester.pumpWidget(app(onLike: () => likes++));
    await tester.pump();

    expect(find.byKey(const ValueKey('gesto-vertical')), findsOneWidget);
    // Y sigue siendo un Listener, no un detector de arrastre: si fuera un
    // GestureDetector vertical, ganaría la arena del gesto y el desplazamiento
    // de la lista quedaría roto sobre las tarjetas.
    final arrastresVerticales = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .where(
          (g) =>
              g.onVerticalDragStart != null || g.onVerticalDragUpdate != null,
        );
    expect(arrastresVerticales, isEmpty);

    // Un tirón corto y rápido (60 px en 16 ms): el gesto es el flick, no el
    // recorrido, así que la lista sigue desplazándose normal.
    // Los `timeStamp` van explícitos: en el entorno de test los eventos de
    // puntero no avanzan el reloj solos y sin eso la velocidad daría 0.
    final g = await tester.startGesture(
      tester.getCenter(find.text('Una canción')),
    );
    await g.moveBy(
      const Offset(0, -60),
      timeStamp: const Duration(milliseconds: 16),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await g.up(timeStamp: const Duration(milliseconds: 32));
    await tester.pumpAndSettle();

    expect(likes, 1);
  });

  testWidgets('un desplazamiento lento hacia arriba no dispara nada', (
    tester,
  ) async {
    var likes = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      arriba: AccionRapida.meGusta,
    );
    await tester.pumpWidget(app(onLike: () => likes++));
    await tester.pump();

    // Mismo recorrido, pero lento: es scroll, no gesto.
    final g = await tester.startGesture(
      tester.getCenter(find.text('Una canción')),
    );
    for (var i = 0; i < 3; i++) {
      await g.moveBy(
        const Offset(0, -20),
        timeStamp: Duration(milliseconds: 200 * (i + 1)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await g.up(timeStamp: const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(likes, 0);
  });

  testWidgets('dos toques ejecutan la acción elegida', (tester) async {
    var likes = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      dobleToque: AccionRapida.meGusta,
    );
    await tester.pumpWidget(app(onLike: () => likes++));
    await tester.pump();

    final centro = tester.getCenter(find.text('Una canción'));
    await tester.tapAt(centro);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(centro);
    await tester.pump(const Duration(milliseconds: 400));

    expect(likes, 1);
  });

  testWidgets(
    'un toque simple sigue reproduciendo con los dos toques activos',
    (tester) async {
      var taps = 0;
      accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
        dobleToque: AccionRapida.meGusta,
      );
      await tester.pumpWidget(app(onTap: () => taps++));
      await tester.pump();

      await tester.tap(find.text('Una canción'), warnIfMissed: false);
      // El doble toque retrasa el simple: hay que dejar vencer su ventana.
      await tester.pump(const Duration(milliseconds: 500));

      expect(taps, 1);
    },
  );

  /// Arrastra la tarjeta [dx] píxeles en varios pasos: el `drag` de un solo
  /// salto no alcanza el umbral que exige el Dismissible (medido: con 300 px
  /// sobre 800 de ancho no dispara, con 600 sí).
  Future<void> deslizar(WidgetTester tester, double dx) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byType(TarjetaTrack)),
    );
    for (var i = 0; i < 4; i++) {
      await g.moveBy(Offset(dx / 4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('deslizar hacia el lado apagado no hace nada', (tester) async {
    var infos = 0;
    await tester.pumpWidget(app(onInfo: () => infos++));
    await tester.pump();

    // De fábrica la izquierda está en "nada": ese lado no se envuelve, así
    // que el arrastre no dispara nada.
    await deslizar(tester, -600);

    expect(infos, 0);
  });

  testWidgets('deslizar hacia el lado configurado ejecuta la acción', (
    tester,
  ) async {
    var infos = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      izquierda: AccionRapida.info,
    );
    await tester.pumpWidget(app(onInfo: () => infos++));
    await tester.pump();

    await deslizar(tester, -600);

    expect(infos, 1);
  });

  testWidgets('con todos los gestos apagados la tarjeta no envuelve nada', (
    tester,
  ) async {
    var taps = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      derecha: AccionRapida.ninguna,
    );
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.pump();

    expect(find.byType(Dismissible), findsNothing);

    await tester.tap(find.text('Una canción'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 1);
  });

  // ── El flick vertical no puede pisar el scroll de la lista ──
  //
  // El bug: con "deslizar arriba/abajo" configurado, un fling normal (scrollear
  // rápido pasando el dedo por encima de una tarjeta) movía la lista Y además
  // ejecutaba la acción: la lista se desplazaba de más o de menos y aparecía una
  // acción que nadie pidió. El gesto ahora sólo cuenta si la lista NO se movió.
  testWidgets('un fling que scrollea la lista no dispara el gesto', (
    tester,
  ) async {
    var likes = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      arriba: AccionRapida.meGusta,
    );
    await tester.pumpWidget(appLarga(cartas: 30, onLike: () => likes++));
    await tester.pump();
    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(posicion.pixels, 0, reason: 'la lista arranca arriba de todo');

    // Arrastre rápido hacia arriba sobre una tarjeta: es scroll, no gesto
    // (la velocidad supera el umbral, así que sin el chequeo de la lista esto
    // disparaba la acción).
    await arrastrarRapido(tester, indice: 2);

    expect(
      posicion.pixels,
      greaterThan(0),
      reason: 'la lista se desplaza: es un scroll de verdad',
    );
    expect(
      likes,
      0,
      reason:
          'scrollear no puede ejecutar la acción: era el "scroll falso" '
          'reportado',
    );
  });

  testWidgets('con la lista al final el flick vuelve a ser gesto', (
    tester,
  ) async {
    var likes = 0;
    accionesRapidas.value = AjustesAccionesRapidas.porDefecto.copyWith(
      abajo: AccionRapida.meGusta,
    );
    await tester.pumpWidget(appLarga(cartas: 8, onLike: () => likes++));
    await tester.pump();

    final posicion =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    // Se deja la lista al final: ya no tiene para dónde moverse, así que el
    // gesto vuelve a ser la única lectura posible del movimiento.
    posicion.jumpTo(posicion.maxScrollExtent);
    await tester.pump();

    await flick(tester, 60, indice: 3);

    expect(
      likes,
      1,
      reason: 'en el final de la lista el tirón sí tiene que actuar',
    );
  });
}
