// info_cancion_traduccion_test.dart — Prueba la hoja de información de
// canción: que muestre los datos con sus ETIQUETAS (canción, artista, álbum,
// duración, lanzamiento, ISRC, origen) y que el botón de traducir los datos
// pase por el servicio y repinte los valores con la traducción.
//
// El traductor es de mentira y se inyecta por el service locator: así el test
// no toca la red y queda fijo lo que sí importa — que las etiquetas salen de
// l10n, que los datos del proveedor NO se traducen solos (solo si el usuario
// lo pide) y que la fecha y el ISRC nunca se traducen.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/core/servicios/traduccion/servicio_traduccion_texto.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/widgets/modales/info_cancion/modal_info_cancion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Traductor de mentira: marca cada texto con EN(...).
Future<({String texto, String idiomaOrigen})> _traductorFalso(
  String texto,
  String destino,
) async => (
  texto: texto.split('\n').map((l) => 'EN($l)').join('\n'),
  idiomaOrigen: 'Spanish',
);

void main() {
  const item = ItemFeed(
    id: 'tr-1',
    type: 'track',
    name: 'BbY WOW',
    artists: 'KAROL G',
    albumName: 'Tropico',
    source: 'qobuz',
    isrc: 'USUG12607940',
    releaseDate: '2026-05-30',
    durationMs: 214000,
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
    di.sl.registerSingleton<ServicioTraduccionTexto>(
      ServicioTraduccionTexto(traductor: _traductorFalso),
    );
  });

  Widget app() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => mostrarInfoCancion(context, item),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los datos con sus etiquetas', (tester) async {
    await abrir(tester);

    expect(find.text('Información'), findsOneWidget);
    expect(find.text('Canción'), findsOneWidget);
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Álbum'), findsOneWidget);
    expect(find.text('Duración'), findsOneWidget);
    expect(find.text('Lanzamiento'), findsOneWidget);
    expect(find.text('ISRC'), findsOneWidget);
    expect(find.text('Origen'), findsOneWidget);
    // La duración va formateada, no en milisegundos.
    expect(find.text('03:34'), findsOneWidget);
    expect(find.text('USUG12607940'), findsOneWidget);
    expect(find.text('2026-05-30'), findsOneWidget);
    // Los datos del proveedor se muestran tal cual hasta que se pida traducir.
    expect(find.text('BbY WOW'), findsWidgets);
    expect(find.text('EN(BbY WOW)'), findsNothing);
  });

  testWidgets('el botón traduce los datos y se puede volver al original', (
    tester,
  ) async {
    await abrir(tester);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();

    // Selector de idioma destino (la misma lista que usa la letra).
    expect(find.text('Traducir datos'), findsWidgets);
    await tester.tap(find.text('Inglés'));
    await tester.pumpAndSettle();

    // Los textos de idioma se traducen...
    expect(find.text('EN(BbY WOW)'), findsWidgets);
    expect(find.text('EN(KAROL G)'), findsWidgets);
    expect(find.text('EN(Tropico)'), findsWidgets);
    // ...y la fecha y el ISRC NO (no son lenguaje).
    expect(find.text('2026-05-30'), findsOneWidget);
    expect(find.text('USUG12607940'), findsOneWidget);
    expect(find.text('03:34'), findsOneWidget);

    // Volver al original.
    await tester.tap(find.text('Ver original'));
    await tester.pumpAndSettle();
    expect(find.text('EN(BbY WOW)'), findsNothing);
    expect(find.text('BbY WOW'), findsWidgets);
  });
}
