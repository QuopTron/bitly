// tarjeta_track_tinte_test.dart — Fija lo que el control de intensidad hace
// con la tarjeta de canción: la carátula de fondo SIGUE ESTANDO con cualquier
// intensidad (antes, al primer punto del slider, la foto desaparecía y la
// tarjeta quedaba de un gris plano) y el color del cover entra como capa de
// tinte con la opacidad EXACTA de la intensidad.
//
// Es el test que evita que vuelva el bug visual: si alguien decide pintar el
// tinte de una sola vez (o saltear la foto cuando hay color), acá salta.

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/fondos/atenuado_por_nivel.dart';
import 'package:bitly/shared/widgets/tarjetas/track/tarjeta_track.dart';
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
  Widget app() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: const Scaffold(
      body: SizedBox(
        height: 120,
        child: TarjetaTrack(
          titulo: 'Una canción',
          subtitulo: 'Un artista',
          coverUrl: cover,
          colorDominante: acento,
          estadoDescarga: EstadoDescarga.ninguno,
          mostrarAcciones: false,
        ),
      ),
    ),
  );

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
}
