// tarjetas_tap_test.dart — Fija que las tarjetas (canción y grilla) se puedan
// tocar en TODA su superficie (carátula, título, artista y huecos) para
// reproducir, y que los iconos de acción (like) sigan con su propio gesto.
//
// Es el test que evita que vuelva el bug de "solo responde en algunos huecos":
// en la tarjeta de canción la miniatura y los `Text` absorbían el hit-test y el
// InkWell de fondo nunca recibía el toque que caía encima.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/tarjetas/grilla/base/tarjeta_grilla.dart';
import 'package:bitly/shared/widgets/tarjetas/track/base/tarjeta_track.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = 'https://ejemplo.com/tapa.jpg';

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

  Widget app({
    required VoidCallback onTap,
    VoidCallback? onLike,
    bool acciones = false,
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
      body: SizedBox(
        height: 120,
        child: TarjetaTrack(
          titulo: 'Una canción',
          subtitulo: 'Un artista',
          coverUrl: cover,
          estadoDescarga: EstadoDescarga.ninguno,
          mostrarAcciones: acciones,
          onLike: onLike,
          onTap: onTap,
        ),
      ),
    ),
  );

  testWidgets('tocar el título reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.pump();

    // `warnIfMissed: false` a propósito: el texto es transparente al hit-test
    // (así el toque llega al InkWell de la tarjeta), que es justo lo que se
    // está verificando.
    await tester.tap(find.text('Una canción'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tocar el artista reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.pump();

    await tester.tap(find.text('Un artista'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tocar la carátula reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.pump();

    // La última carátula es la miniatura de la fila (la primera es el fondo).
    await tester.tap(find.byType(CachedNetworkImage).last, warnIfMissed: false);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tocar un hueco de la tarjeta reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(onTap: () => taps++));
    await tester.pump();

    final caja = tester.getRect(find.byType(TarjetaTrack));
    // Zona a la derecha de los textos, sin acciones: antes no respondía.
    await tester.tapAt(Offset(caja.right - 30, caja.center.dy));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('el corazón sigue con su propia acción y NO reproduce', (
    tester,
  ) async {
    var taps = 0;
    var likes = 0;
    await tester.pumpWidget(
      app(onTap: () => taps++, onLike: () => likes++, acciones: true),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(likes, 1);
    expect(taps, 0);
  });

  // La tarjeta de grilla (álbum/playlist/artista) ya envuelve todo su cuerpo en
  // un GestureDetector; estos tests fijan que siga respondiendo en toda la
  // superficie y que el corazón conserve su propia acción.
  Widget appGrilla({
    required VoidCallback onTap,
    VoidCallback? onLike,
    bool acciones = false,
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
      body: SizedBox(
        width: 220,
        height: 240,
        child: TarjetaGrilla(
          tipo: 'album',
          titulo: 'Un álbum',
          subtitulo: 'Un artista',
          coverUrl: cover,
          mostrarAcciones: acciones,
          onLike: onLike,
          onTap: onTap,
        ),
      ),
    ),
  );

  testWidgets('grilla: tocar el título reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(appGrilla(onTap: () => taps++));
    await tester.pump();

    await tester.tap(find.text('Un álbum'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('grilla: tocar la portada reproduce', (tester) async {
    var taps = 0;
    await tester.pumpWidget(appGrilla(onTap: () => taps++));
    await tester.pump();

    await tester.tap(
      find.byType(CachedNetworkImage).first,
      warnIfMissed: false,
    );
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('grilla: el corazón no reproduce', (tester) async {
    var taps = 0;
    var likes = 0;
    await tester.pumpWidget(
      appGrilla(onTap: () => taps++, onLike: () => likes++, acciones: true),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(likes, 1);
    expect(taps, 0);
  });
}
