// ─────────────────────────────────────────────────────────────
// panel_error_web_test.dart — Verifica el panel de error propio de
// la PWA (el que ve quien abre la web sin el servidor encendido).
//
// Por qué se prueba aparte: `kIsWeb` no se puede activar desde el VM
// de tests, así que la pantalla real no se alcanza acá. Por eso
// PanelErrorWeb es público y se monta directo, con las cadenas de
// verdad y a tamaños de celular y de escritorio.
//
// Lo que fija:
//   · que explique el motivo y ofrezca la app nativa (ES y EN),
//   · que NO se desborde ni en celular chico ni en pantalla grande,
//   · que "Reintentar" siga re-disparando el chequeo del backend,
//   · que el botón de descarga no rompa la pantalla si el link falla.
// Se conecta con: features/splash/widgets/panel_error.dart + l10n.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/backend_go/nucleo/contrato_backend.dart';
import 'package:bitly/features/splash/bloc/splash_bloc.dart';
import 'package:bitly/features/splash/bloc/splash_estado.dart';
import 'package:bitly/features/splash/widgets/panel_error.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/utilidades/plataforma/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBackend extends Mock implements BackendService {}

void main() {
  late _MockBackend backend;
  late SplashBloc bloc;

  setUp(() {
    backend = _MockBackend();
    when(() => backend.healthCheck()).thenAnswer((_) async => false);
    bloc = SplashBloc(backend);
  });

  tearDown(() async {
    await bloc.close();
  });

  /// Monta el panel con el idioma y el tamaño pedidos, dentro de un scroll
  /// como en el splash real (que envuelve el panel en SingleChildScrollView).
  Future<void> montar(
    WidgetTester tester, {
    required String idioma,
    required Size tamano,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(idioma),
        supportedLocales: const [Locale('es'), Locale('en')],
        // Los mismos delegates que app.dart: sin los globales, MaterialApp
        // avisa que el locale no está soportado por todos.
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BlocProvider<SplashBloc>.value(
          value: bloc,
          child: Builder(
            builder:
                (context) => Scaffold(
                  body: SingleChildScrollView(
                    child: PanelErrorWeb(
                      loc: AppLocalizations.of(context),
                      r: Responsive(context),
                      isDark: true,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('PanelErrorWeb', () {
    testWidgets('explica en español por qué la web necesita el servidor', (
      tester,
    ) async {
      await montar(tester, idioma: 'es', tamano: const Size(390, 844));

      expect(
        find.text('Esta versión web necesita el servidor de Bitly'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'El navegador no puede buscar la música por sí solo',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Si no instalaste el servidor'),
        findsOneWidget,
      );
      expect(find.text('Descargar la app'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('explica en inglés con las mismas piezas', (tester) async {
      await montar(tester, idioma: 'en', tamano: const Size(390, 844));

      expect(
        find.text('This web version needs the Bitly server'),
        findsOneWidget,
      );
      expect(
        find.textContaining("The browser can't fetch music on its own"),
        findsOneWidget,
      );
      expect(find.text('Download the app'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('no se desborda en celular chico (360x640)', (tester) async {
      await montar(tester, idioma: 'es', tamano: const Size(360, 640));

      expect(tester.takeException(), isNull);
      expect(
        find.text('Esta versión web necesita el servidor de Bitly'),
        findsOneWidget,
      );
    });

    testWidgets('no se desborda en pantalla grande (1440x900)', (tester) async {
      await montar(tester, idioma: 'es', tamano: const Size(1440, 900));

      expect(tester.takeException(), isNull);
      expect(find.text('Descargar la app'), findsOneWidget);
    });

    testWidgets('Reintentar vuelve a chequear el backend', (tester) async {
      await montar(tester, idioma: 'es', tamano: const Size(390, 844));

      // El bloc no chequea nada hasta que le llega el evento (el estado
      // inicial es `cargando` sin haber consultado), así que una llamada
      // después del tap prueba que el botón re-dispara el chequeo. Los
      // reintentos con backoff son asunto del bloc, no de este panel.
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      verify(() => backend.healthCheck()).called(1);
      expect(bloc.state.status, EstatusSplash.cargando);
    });

    testWidgets('el botón de descarga no rompe la pantalla si el link falla', (
      tester,
    ) async {
      await montar(tester, idioma: 'es', tamano: const Size(390, 844));

      await tester.tap(find.text('Descargar la app'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sin handler de url_launcher en tests el launch falla; el panel tiene
      // que seguir en pie y dejar la URL visible para copiarla a mano.
      expect(tester.takeException(), isNull);
      expect(
        find.text('https://github.com/QuopTron/bitly/releases/latest'),
        findsOneWidget,
      );
    });
  });
}
