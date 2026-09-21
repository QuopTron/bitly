// tarjeta_grilla_tinte_test.dart — Lo mismo que el test de la tarjeta de
// canción, pero para la grilla (álbum/playlist/artista): la portada de fondo
// SIGUE ESTANDO con cualquier intensidad y el color del cover entra como capa
// de tinte con la opacidad EXACTA de la intensidad.
//
// Antes, al primer punto del control, la tarjeta de grilla cambiaba su arte
// por un fondo sólido del color mezclado (gris): acá queda fijado que no.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/fondos/ambiente/atenuado_por_nivel.dart';
import 'package:bitly/shared/widgets/tarjetas/grilla/base/tarjeta_grilla.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/album.jpg';
  const acento = Color(0xFFFF6B6B);
  late ValueNotifier<PreferenciasEstilo> prefs;

  setUpAll(() {
    prefs = ValueNotifier(PreferenciasEstilo.normal);
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(prefs);
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
    // El redondeo de las cards sale de acá (Ajustes → Apariencia → Diseño).
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
  });

  setUp(() => prefs.value = PreferenciasEstilo.normal);

  Widget app({bool lineaDerecha = false}) => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Scaffold(
      body: SizedBox(
        width: 220,
        height: 240,
        child: TarjetaGrilla(
          tipo: 'album',
          titulo: 'Un álbum',
          subtitulo: 'Un artista',
          coverUrl: cover,
          colorDominante: acento,
          mostrarAcciones: false,
          lineaDerecha: lineaDerecha,
        ),
      ),
    ),
  );

  AtenuadoPorNivel tinte(WidgetTester tester) =>
      tester.widget<AtenuadoPorNivel>(find.byType(AtenuadoPorNivel));

  // Las líneas del modo "unido" se buscan por su Key (son Containers planos,
  // sin borde), así no se confunden con los bordes de las portadas.
  bool hayLinea(WidgetTester tester) =>
      find.byKey(const ValueKey('linea-separacion-y')).evaluate().isNotEmpty ||
      find.byKey(const ValueKey('linea-separacion-x')).evaluate().isNotEmpty;

  bool hayBordeDerecho(WidgetTester tester) =>
      find.byKey(const ValueKey('linea-separacion-x')).evaluate().isNotEmpty;

  testWidgets('de fábrica se ve la portada y no hay tinte', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // Fondo + portada nítida.
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(find.byType(AtenuadoPorNivel), findsNothing);
  });

  testWidgets('de fábrica la grilla no dibuja línea divisoria', (tester) async {
    await tester.pumpWidget(app(lineaDerecha: true));
    await tester.pump();
    expect(hayLinea(tester), isFalse);
  });

  testWidgets(
    'al juntar (0) la grilla dibuja su línea (y la derecha si toca)',
    (tester) async {
      di.sl<ValueNotifier<PreferenciasApariencia>>().value =
          PreferenciasApariencia.deFabrica.copiarCon(espacioX: 0, espacioY: 0);
      await tester.pumpWidget(app(lineaDerecha: true));
      await tester.pump();
      expect(hayLinea(tester), isTrue);
      // Con lineaDerecha en false no debe haber borde derecho.
      await tester.pumpWidget(app());
      await tester.pump();
      expect(hayBordeDerecho(tester), isFalse);
      // Se restablece para no ensuciar las demás pruebas.
      di.sl<ValueNotifier<PreferenciasApariencia>>().value =
          PreferenciasApariencia.deFabrica;
    },
  );

  // Radios de todos los contenedores que declaran borderRadius.
  List<double> radios(WidgetTester tester) =>
      tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.borderRadius)
          .whereType<BorderRadius>()
          .map((b) => b.topLeft.x)
          .toList();

  testWidgets('el redondeo llega a 0 en la tarjeta de grilla', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    // De fábrica: el contenedor son 16 y la portada 14, como siempre.
    expect(radios(tester).any((v) => (v - 16).abs() < 0.1), isTrue);
    expect(radios(tester).any((v) => (v - 14).abs() < 0.1), isTrue);

    di
        .sl<ValueNotifier<PreferenciasApariencia>>()
        .value = PreferenciasApariencia.deFabrica.copiarCon(radioCards: 0);
    await tester.pumpWidget(app());
    await tester.pump();
    // Con Redondeo 0 la grilla entera queda cuadrada.
    expect(radios(tester).any((v) => (v - 16).abs() < 0.1), isFalse);
    expect(radios(tester).any((v) => (v - 14).abs() < 0.1), isFalse);
    expect(radios(tester).any((v) => v.abs() < 0.1), isTrue);

    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica;
  });

  testWidgets('al 1% la portada sigue y el tinte entra con la intensidad', (
    tester,
  ) async {
    prefs.value = const PreferenciasEstilo().conNivel(
      ComponenteEstilo.cardsGrilla,
      0.01,
    );
    await tester.pumpWidget(app());
    await tester.pump();

    expect(
      find.byType(CachedNetworkImage),
      findsNWidgets(2),
      reason: 'el fondo no puede perder la portada al mover el control',
    );
    expect(tinte(tester).opacidad, moreOrLessEquals(0.01, epsilon: 0.001));
  });
}
