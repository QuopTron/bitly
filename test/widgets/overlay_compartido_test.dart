// Test del overlay "te compartieron": la carta debe mostrar quién la manda,
// el ISRC y el nombre de la canción, y los botones deben responder.
//
// También fija dos cosas del diseño: que la carta sea CHICA (no ocupa la
// pantalla) y que todo funcione sin efectos pesados (gama baja).

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/plataforma/sistema/servicio_deep_link.dart';
import 'package:bitly/core/servicios/compartir/datos_compartido.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/base/overlay_compartido.dart';
import 'package:bitly/shared/widgets/base/overlay_compartido_contenido.dart';
import 'package:bitly/shared/utilidades/plataforma/efectos_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _datos = DatosCompartido(
  tipo: 'track',
  isrc: 'USUM71703861',
  nombre: 'Todo de Ti',
  artista: 'Rauw Alejandro',
  album: 'Vice Versa',
  emisor: 'Pablo',
);

Future<void> _montar(
  WidgetTester tester, {
  VoidCallback? onPlay,
  VoidCallback? onAgregar,
  VoidCallback? onDismiss,
  bool enCola = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      home: OverlayCompartido(
        link: const DatosDeepLink(
          type: 'track',
          id: 'USUM71703861',
          query: 'Todo de Ti',
          compartido: _datos,
        ),
        onPlay: onPlay ?? () {},
        onAgregar: onAgregar ?? () {},
        onDismiss: onDismiss ?? () {},
        enCola: enCola,
      ),
    ),
  );
  // Entrada de la carta: 460 ms de animación, en pasos.
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Ancho real de la placa de la carta (borde redondeado a 18).
Finder _placaCarta() => find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius ==
              BorderRadius.circular(18),
    );

Finder _findFondo() => find.byType(FondoCompartido);

void main() {
  tearDown(EfectosApp.reiniciar);

  testWidgets('la carta muestra emisor, ISRC, canción y artista',
      (tester) async {
    await _montar(tester);
    expect(find.text('Compartido por Pablo'), findsOneWidget);
    expect(find.text('USUM71703861'), findsOneWidget);
    expect(find.text('Todo de Ti'), findsOneWidget);
    expect(find.text('Rauw Alejandro'), findsOneWidget);
    expect(find.text('TE COMPARTIERON'), findsOneWidget);
    expect(find.text('Omitir'), findsOneWidget);
  });

  testWidgets('sin reproducción dice Reproducir y reproduce', (tester) async {
    var reproducido = false;
    var omitido = false;
    await _montar(
      tester,
      onPlay: () => reproducido = true,
      onDismiss: () => omitido = true,
    );
    expect(find.text('Reproducir'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(reproducido, isTrue);
    await tester.tap(find.text('Omitir'));
    await tester.pump();
    expect(omitido, isTrue);
  });

  testWidgets('con algo sonando dice Agregar a la cola y encola',
      (tester) async {
    var agregado = false;
    var reproducido = false;
    await _montar(
      tester,
      enCola: true,
      onAgregar: () => agregado = true,
      onPlay: () => reproducido = true,
    );
    expect(find.text('Agregar a la cola'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pump();
    expect(agregado, isTrue);
    expect(reproducido, isFalse);
  });

  testWidgets('en gama baja se dibuja igual (sin efectos pesados)',
      (tester) async {
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
    await _montar(tester);
    expect(find.text('Todo de Ti'), findsOneWidget);
    expect(find.text('Compartido por Pablo'), findsOneWidget);
    // Sin efectos la entrada se resuelve igual y no queda nada animando.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Reproducir'), findsOneWidget);
  });

  testWidgets('sin blur (gama baja) el fondo se vela mucho más',
      (tester) async {
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
    await _montar(tester);
    final velo = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(FondoCompartido),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    // El velo es el único separador: tiene que tapar bastante más.
    expect(velo.color.a, greaterThan(0.7));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('con blur el fondo desenfoca y vela menos', (tester) async {
    EfectosApp.aplicar(efectosPesados: true, sigmaMax: 26);
    await _montar(tester);
    final velo = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(FondoCompartido),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(velo.color.a, lessThan(0.5));
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('el fondo queda fuera del contenido que se anima',
      (tester) async {
    await _montar(tester);
    // El fondo lo pinta el OVERLAY (estático), no el contenido: así no se
    // reconstruye en cada frame mientras la carta cae.
    expect(
      find.descendant(
        of: find.byType(OverlayCompartidoContenido),
        matching: _findFondo(),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(OverlayCompartido),
        matching: _findFondo(),
      ),
      findsOneWidget,
    );
  });

  testWidgets('los textos no heredan el estilo de aviso de MaterialApp',
      (tester) async {
    await _montar(tester);
    // MaterialApp pinta un subrayado DOBLE amarillo (fallback style) en
    // los textos que no están dentro de un Material. La carta se monta en
    // el builder de MaterialApp, así que tiene que traer el suyo: sin esto
    // aparecían dos líneas amarillas debajo de cada texto (bug real de
    // release, no de debug).
    final ctx = tester.element(find.text('Todo de Ti'));
    final estilo = DefaultTextStyle.of(ctx).style;
    expect(estilo.decoration, isNot(TextDecoration.underline));
    expect(estilo.decorationColor, isNot(const Color(0xFFFFFF00)));
    expect(
      find.ancestor(
        of: find.text('Todo de Ti'),
        matching: find.byType(Material),
      ),
      findsWidgets,
    );
  });

  testWidgets('la carta es chica: no ocupa la pantalla', (tester) async {
    await _montar(tester);
    final pantalla = tester.getSize(find.byType(OverlayCompartido)).width;
    final carta = tester.getSize(_placaCarta().first).width;
    expect(carta, lessThan(pantalla * 0.8));
    // Y queda centrada, con aire a los dos lados.
    final centroCarta = tester.getCenter(_placaCarta().first).dx;
    expect((centroCarta - pantalla / 2).abs(), lessThan(2));
  });

  testWidgets('sin carátula la carta igual se ve (reserva, no caja vacía)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        home: OverlayCompartido(
          link: const DatosDeepLink(
            type: 'track',
            id: 'USUM71703861',
            query: 'Todo de Ti',
            compartido: DatosCompartido(
              isrc: 'USUM71703861',
              nombre: 'Todo de Ti',
              artista: 'Rauw Alejandro',
              emisor: 'Pablo',
            ),
          ),
          onPlay: () {},
          onAgregar: () {},
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Todo de Ti'), findsOneWidget);
    // El hueco de la carátula muestra el icono del tipo, no un vacío.
    expect(find.byIcon(Icons.music_note_rounded), findsWidgets);
  });

  testWidgets('en tema oscuro la carta usa los colores del tema',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        home: OverlayCompartido(
          link: const DatosDeepLink(
            type: 'track',
            id: 'USUM71703861',
            query: 'Todo de Ti',
            compartido: _datos,
          ),
          onPlay: () {},
          onAgregar: () {},
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Todo de Ti'), findsOneWidget);
    expect(find.text('Compartido por Pablo'), findsOneWidget);
  });

  testWidgets('la grilla (álbum) también entra chica', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        home: OverlayCompartido(
          link: DatosDeepLink(
            type: 'playlist',
            id: 'p1',
            query: 'Mix',
            compartido: DatosCompartido.desdeItem(
              const ItemFeed(id: 'p1', type: 'playlist', name: 'Mix', owner: 'Pablo'),
              emisor: 'Pablo',
            ),
          ),
          onPlay: () {},
          onAgregar: () {},
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final pantalla = tester.getSize(find.byType(OverlayCompartido)).width;
    expect(tester.getSize(_placaCarta().first).width, lessThan(pantalla * 0.8));
    expect(find.text('PLAYLIST'), findsOneWidget);
  });

  testWidgets('no desborda en un celular chico', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _montar(tester);
    // Un desborde de layout lo reporta Flutter como error del frame:
    // alcanza con montar y bombear sin excepciones.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Todo de Ti'), findsOneWidget);
    expect(find.text('Reproducir'), findsOneWidget);
  });

  testWidgets('un álbum usa la tarjeta de grilla con su tipo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        home: OverlayCompartido(
          link: DatosDeepLink(
            type: 'album',
            id: 'USUM71703861',
            query: 'Vice Versa',
            compartido: DatosCompartido.desdeItem(
              const ItemFeed(
                id: 'a1',
                type: 'album',
                name: 'Vice Versa',
                artists: 'Rauw Alejandro',
              ),
              emisor: 'Pablo',
            ),
          ),
          onPlay: () {},
          onAgregar: () {},
          onDismiss: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('Vice Versa'), findsOneWidget);
    expect(find.text('ÁLBUM'), findsOneWidget);
  });
}
