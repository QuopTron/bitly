// tarjeta_grilla_tinte_test.dart — Lo mismo que el test de la tarjeta de
// canción, pero para la grilla (álbum/playlist/artista): la portada de fondo
// SIGUE ESTANDO con cualquier intensidad y el color del cover entra como capa
// de tinte con la opacidad EXACTA de la intensidad.
//
// Antes, al primer punto del control, la tarjeta de grilla cambiaba su arte
// por un fondo sólido del color mezclado (gris): acá queda fijado que no.
//
// También fija que las LETRAS y el VELO de la card se mueven juntos: el velo
// existe para que el texto se lea sobre la portada, así que cuando el tinte
// deja la card clara las letras pasan a oscuras y el velo se aclara con ellas.
// Si el velo se quedara negro, taparía justo lo que tiene que mostrar.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/fondos/ambiente/atenuado_por_nivel.dart';
import 'package:bitly/shared/utilidades/portada/paleta/paleta_portada.dart'
    show luminanciaRelativa, relacionContraste;
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

  Widget app({
    bool lineaDerecha = false,
    Brightness brillo = Brightness.light,
    Color dominante = acento,
  }) => MaterialApp(
    theme: ThemeData(brightness: brillo),
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
          colorDominante: dominante,
          mostrarAcciones: false,
          lineaDerecha: lineaDerecha,
        ),
      ),
    ),
  );

  AtenuadoPorNivel tinte(WidgetTester tester) =>
      tester.widget<AtenuadoPorNivel>(find.byType(AtenuadoPorNivel));

  /// El color con el que se pinta el título: donde se ve si las letras se
  /// adaptaron al fondo de la card.
  Color colorTitulo(WidgetTester tester) =>
      tester.widget<Text>(find.text('Un álbum')).style!.color!;

  /// La parada de ABAJO del degradado de legibilidad —la que queda detrás del
  /// bloque de info—: es la que tiene que acompañar al color de las letras. El
  /// del fondo de la card es el único degradado con las cuatro paradas
  /// cruzadas por la intensidad.
  Color veloInferior(WidgetTester tester) {
    final degradados =
        tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<LinearGradient>();
    return degradados.firstWhere((g) => g.colors.length == 4).colors.first;
  }

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

  testWidgets('de fábrica la letra va blanca y el velo queda oscuro', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(colorTitulo(tester), Colors.white);
    expect(luminanciaRelativa(veloInferior(tester)), lessThan(0.5));
  });

  testWidgets(
    'portada BLANCA al 100% en tema claro: letra oscura y velo claro',
    (tester) async {
      prefs.value = const PreferenciasEstilo().conNivel(
        ComponenteEstilo.cardsGrilla,
        1,
      );
      await tester.pumpWidget(app(dominante: const Color(0xFFFFFFFF)));
      await tester.pump();

      final letra = colorTitulo(tester);
      final velo = veloInferior(tester);
      expect(
        luminanciaRelativa(letra),
        lessThan(0.5),
        reason: 'sobre una card clara la letra va oscura',
      );
      expect(
        luminanciaRelativa(velo),
        greaterThan(0.5),
        reason: 'el velo tiene que aclararse CON las letras, no quedarse negro',
      );
      expect(relacionContraste(letra, velo), greaterThanOrEqualTo(4.5));
    },
  );

  testWidgets(
    'portada BLANCA al 100% en tema oscuro: la letra y el velo quedan oscuros',
    (tester) async {
      prefs.value = const PreferenciasEstilo().conNivel(
        ComponenteEstilo.cardsGrilla,
        1,
      );
      await tester.pumpWidget(
        app(brillo: Brightness.dark, dominante: const Color(0xFFFFFFFF)),
      );
      await tester.pump();

      expect(colorTitulo(tester), Colors.white);
      expect(luminanciaRelativa(veloInferior(tester)), lessThan(0.5));
    },
  );

  testWidgets(
    'con cualquier portada y nivel, las letras se leen sobre el velo',
    (tester) async {
      for (final dominante in const [
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        acento,
        Color(0xFF1DB954),
      ]) {
        for (final nivel in const [0.0, 0.5, 1.0]) {
          prefs.value = const PreferenciasEstilo().conNivel(
            ComponenteEstilo.cardsGrilla,
            nivel,
          );
          await tester.pumpWidget(app(dominante: dominante));
          await tester.pump();
          expect(
            relacionContraste(colorTitulo(tester), veloInferior(tester)),
            greaterThanOrEqualTo(4.5),
            reason: 'portada $dominante al ${nivel * 100}%',
          );
        }
      }
    },
  );

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
