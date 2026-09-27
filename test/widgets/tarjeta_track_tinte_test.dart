// tarjeta_track_tinte_test.dart — Fija lo que el control de intensidad hace
// con la tarjeta de canción: la carátula de fondo SIGUE ESTANDO con cualquier
// intensidad (antes, al primer punto del slider, la foto desaparecía y la
// tarjeta quedaba de un gris plano) y el color del cover entra como capa de
// tinte con la opacidad EXACTA de la intensidad.
//
// Es el test que evita que vuelva el bug visual: si alguien decide pintar el
// tinte de una sola vez (o saltear la foto cuando hay color), acá salta.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/fondos/ambiente/atenuado_por_nivel.dart';
import 'package:bitly/shared/utilidades/portada/paleta/paleta_portada.dart'
    show luminanciaRelativa, relacionContraste;
import 'package:bitly/shared/widgets/tarjetas/track/base/tarjeta_track.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';
  const acento = Color(0xFF1DB954);
  late ValueNotifier<PreferenciasEstilo> prefs;

  setUpAll(() {
    prefs = ValueNotifier(PreferenciasEstilo.normal);
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(prefs);
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
    // La tarjeta lee el margen/la línea de Ajustes → Apariencia → Diseño.
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
  });

  setUp(() => prefs.value = PreferenciasEstilo.normal);

  /// Una tarjeta con carátula y color dominante ya resuelto (sin paleta
  /// asíncrona), dentro de una app con l10n.
  Widget app({
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
        height: 120,
        child: TarjetaTrack(
          titulo: 'Una canción',
          subtitulo: 'Un artista',
          coverUrl: cover,
          colorDominante: dominante,
          estadoDescarga: EstadoDescarga.ninguno,
          mostrarAcciones: false,
        ),
      ),
    ),
  );

  /// El color con el que se pinta el título: es donde se ve si las letras se
  /// adaptaron al fondo de la card.
  Color colorTitulo(WidgetTester tester) =>
      tester.widget<Text>(find.text('Una canción')).style!.color!;

  /// La parada de ABAJO del degradado de legibilidad —la que queda detrás del
  /// texto—: es la que tiene que acompañar al color de las letras. Es el único
  /// degradado de la tarjeta con TRES paradas.
  Color veloInferior(WidgetTester tester) {
    final degradados =
        tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<LinearGradient>();
    return degradados.firstWhere((g) => g.colors.length == 3).colors.last;
  }

  /// La capa de tinte (la única `AtenuadoPorNivel` del fondo de la tarjeta).
  AtenuadoPorNivel tinte(WidgetTester tester) =>
      tester.widget<AtenuadoPorNivel>(find.byType(AtenuadoPorNivel));

  /// Las dos carátulas de la tarjeta: la de fondo y la miniatura. Si el fondo
  /// desapareciera quedaría una sola, que es justo lo que queremos detectar.
  void esperarLasDosCaratulas() =>
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));

  testWidgets('con el diseño de fábrica se ve la carátula y NO hay tinte', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    esperarLasDosCaratulas();
    expect(find.byType(AtenuadoPorNivel), findsNothing);
  });

  testWidgets(
    'al 1% la carátula sigue ahí y el tinte entra con la intensidad',
    (tester) async {
      prefs.value = const PreferenciasEstilo().conNivel(
        ComponenteEstilo.cardsCancion,
        0.01,
      );
      await tester.pumpWidget(app());
      await tester.pump();

      // El fondo de la tarjeta no puede quedarse sin carátula al mover el
      // control: si desaparece, el tinte la deja de un gris plano.
      esperarLasDosCaratulas();
      expect(tinte(tester).opacidad, moreOrLessEquals(0.01, epsilon: 0.001));
    },
  );

  testWidgets('al 100% el tinte queda opaco y la carátula sigue debajo', (
    tester,
  ) async {
    prefs.value = PreferenciasEstilo.completo;
    await tester.pumpWidget(app());
    await tester.pump();

    expect(tinte(tester).opacidad, 1);
    esperarLasDosCaratulas();
  });

  testWidgets('de fábrica el título va blanco, también en tema claro', (
    tester,
  ) async {
    // El fondo de la card es la carátula con un velo OSCURO y un degradado
    // inferior, en los dos temas: el blanco de fábrica es el que corresponde.
    // (Con la superficie del tema como base del cálculo, en tema claro el texto
    // pasaba a negro sobre ese velo y desaparecía.)
    await tester.pumpWidget(app());
    await tester.pump();
    expect(colorTitulo(tester), Colors.white);
  });

  testWidgets('portada BLANCA al 100% en tema claro → letra oscura', (
    tester,
  ) async {
    prefs.value = PreferenciasEstilo.completo;
    await tester.pumpWidget(app(dominante: const Color(0xFFFFFFFF)));
    await tester.pump();

    final letra = colorTitulo(tester);
    expect(
      luminanciaRelativa(letra),
      lessThan(0.5),
      reason: 'sobre una card clara la letra tiene que ir oscura',
    );
  });

  testWidgets('portada BLANCA al 100% en tema oscuro → la letra sigue blanca', (
    tester,
  ) async {
    // El velo y el degradado de la card pesan más que el tinte acá: la zona
    // del título termina oscura igual.
    prefs.value = PreferenciasEstilo.completo;
    await tester.pumpWidget(
      app(brillo: Brightness.dark, dominante: const Color(0xFFFFFFFF)),
    );
    await tester.pump();
    expect(colorTitulo(tester), Colors.white);
  });

  testWidgets('el velo acompaña a las letras: nunca se tapan entre ellos', (
    tester,
  ) async {
    prefs.value = PreferenciasEstilo.completo;
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
      reason: 'el degradado tiene que aclararse CON las letras',
    );
    expect(relacionContraste(letra, velo), greaterThanOrEqualTo(4.5));
  });

  testWidgets('con cualquier portada, tema y nivel, las letras se leen', (
    tester,
  ) async {
    for (final brillo in const [Brightness.light, Brightness.dark]) {
      for (final dominante in const [
        Color(0xFFFFFFFF),
        Color(0xFF000000),
        acento,
        Color(0xFF1DB954),
      ]) {
        for (final nivel in const [0.0, 0.5, 1.0]) {
          prefs.value = const PreferenciasEstilo().conNivel(
            ComponenteEstilo.cardsCancion,
            nivel,
          );
          await tester.pumpWidget(app(brillo: brillo, dominante: dominante));
          await tester.pump();
          expect(
            relacionContraste(colorTitulo(tester), veloInferior(tester)),
            greaterThanOrEqualTo(4.5),
            reason: '$brillo, portada $dominante al ${nivel * 100}%',
          );
        }
      }
    }
  });
}
