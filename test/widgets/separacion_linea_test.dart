// separacion_linea_test.dart — Fija el comportamiento del control de
// Separación sobre las cards de canción: el margen (hueco entre cards +
// margen contra los bordes, X; hueco entre filas, Y) escala con el
// multiplicador, y la línea divisoria del modo "unido" (tipo Spotify)
// aparece SOLA al llegar al extremo 0 y no existe de fábrica.
//
// Es lo que evita que la línea se dibuje siempre (arruinando el diseño de
// fábrica) o que el margen deje de responder al control.

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/core/modelos/usuario/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/tarjetas/track/tarjeta_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';
  late ValueNotifier<PreferenciasApariencia> apariencia;

  setUpAll(() {
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(PreferenciasEstilo.normal),
    );
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
    apariencia = ValueNotifier(PreferenciasApariencia.deFabrica);
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(apariencia);
  });

  setUp(() => apariencia.value = PreferenciasApariencia.deFabrica);

  // El app raíz escucha la apariencia y repinta todo; acá lo imitamos para
  // que mover el control se refleje sin volver a montar el árbol.
  Widget app() => ValueListenableBuilder<PreferenciasApariencia>(
    valueListenable: apariencia,
    builder:
        (_, _, _) => MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es'), Locale('en')],
          // Sin `const`: una card const no se reconstruiría al mover el control
          // (Flutter saltea subárboles const idénticos).
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: TarjetaTrack(
                titulo: 'Una canción',
                subtitulo: 'Un artista',
                coverUrl: cover,
                estadoDescarga: EstadoDescarga.ninguno,
                mostrarAcciones: false,
              ),
            ),
          ),
        ),
  );

  /// ¿Está la línea divisoria del modo "unido"? Se busca por su Key.
  bool hayLineaAbajo(WidgetTester tester) =>
      find.byKey(const ValueKey('linea-separacion')).evaluate().isNotEmpty;

  /// El margen horizontal/vertical más grande de la tarjeta (su gap propio).
  double mayorMargen(WidgetTester tester, double Function(EdgeInsets) f) =>
      tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.margin)
          .whereType<EdgeInsets>()
          .map(f)
          .fold(0.0, (a, b) => a > b ? a : b);

  testWidgets('de fábrica no hay línea divisoria', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(hayLineaAbajo(tester), isFalse);
  });

  testWidgets('al juntar (0) aparece la línea divisoria', (tester) async {
    apariencia.value = PreferenciasApariencia.deFabrica.copiarCon(espacioY: 0);
    await tester.pumpWidget(app());
    await tester.pump();
    expect(hayLineaAbajo(tester), isTrue);
  });

  testWidgets('el margen de la card escala con X e Y', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final baseH = mayorMargen(tester, (m) => m.left);
    final baseV = mayorMargen(tester, (m) => m.top);
    expect(baseH, greaterThan(0));
    expect(baseV, greaterThan(0));

    apariencia.value = PreferenciasApariencia.deFabrica.copiarCon(
      espacioX: 2,
      espacioY: 2,
    );
    await tester.pump();
    expect(mayorMargen(tester, (m) => m.left), closeTo(baseH * 2, 0.01));
    expect(mayorMargen(tester, (m) => m.top), closeTo(baseV * 2, 0.01));

    apariencia.value = PreferenciasApariencia.deFabrica.copiarCon(
      espacioX: 0,
      espacioY: 0,
    );
    await tester.pump();
    expect(mayorMargen(tester, (m) => m.left), closeTo(0, 0.01));
    expect(mayorMargen(tester, (m) => m.top), closeTo(0, 0.01));
  });

  /// El radio del contenedor de la card (el que tiene margen propio).
  double radioDeLaCard(WidgetTester tester) {
    for (final c in tester.widgetList<Container>(find.byType(Container))) {
      final m = c.margin;
      final d = c.decoration;
      if (m is EdgeInsets &&
          m.left > 0 &&
          d is BoxDecoration &&
          d.borderRadius is BorderRadius) {
        return (d.borderRadius! as BorderRadius).topLeft.x;
      }
    }
    return -1;
  }

  testWidgets('el redondeo llega a 0 en la card de canción', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(
      radioDeLaCard(tester),
      closeTo(18, 0.01),
      reason: 'de fábrica son los 18 px de siempre',
    );

    apariencia.value = PreferenciasApariencia.deFabrica.copiarCon(
      radioCards: 0,
    );
    await tester.pump();
    expect(
      radioDeLaCard(tester),
      closeTo(0, 0.01),
      reason: 'con Redondeo 0 la card queda cuadrada, no curva',
    );
  });
}
