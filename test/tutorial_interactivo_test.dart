// tutorial_interactivo_test.dart — Verifica el tutorial interactivo de la
// primera vez: que se muestre una sola vez, que avance/retroceda/salte, que
// lleve al usuario por las secciones de la Home y que entre a Ajustes a
// explicar cada pestaña.
//
// También cubre lo que se rompía antes: un paso cuyo objetivo NO está montado
// se explica igual (centrado) y la tarjeta nunca queda fuera de pantalla.
//
// Se conecta con: features/tutorial_interactivo (controller + overlay + pasos)
// y l10n (los textos).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitly/features/tutorial_interactivo/modelo_tutorial.dart';
import 'package:bitly/features/tutorial_interactivo/tutorial_controller.dart';
import 'package:bitly/features/tutorial_interactivo/tutorial_overlay.dart';
import 'package:bitly/features/tutorial_interactivo/tutorial_pasos.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/l10n/strings/strings_tutorial_interactivo.dart';

/// Textos reconocibles para poder buscarlos en pantalla.
List<TextoTutorial> textosDePrueba() => [
      for (var i = 1; i <= 13; i++) TextoTutorial('Titulo $i', 'Desc $i'),
    ];

/// Pasos con textos de prueba.
List<TutorialPaso> pasosDePrueba() => crearPasosTutorial(textosDePrueba());

// Igual que lib/app.dart: sin los delegates de Material/Cupertino el locale
// 'es' no está soportado y el framework tira error en el test.
Widget _app(Widget hijo) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: Scaffold(body: hijo),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('controller', () {
    test('la primera vez se muestra y queda pendiente', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      expect(ctrl.visible, isTrue);
      expect(ctrl.completado, isFalse);
      expect(ctrl.indiceActual, 0);
      expect(ctrl.totalPasos, 13);
    });

    test('avanzar hasta el final lo marca completado y lo persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      for (var i = 0; i < 13; i++) {
        ctrl.siguiente();
      }
      expect(ctrl.completado, isTrue, reason: 'el último paso completa');
      expect(ctrl.visible, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tutorial_interactivo_completado'), isTrue);
    });

    test('un tutorial ya completado no vuelve a mostrarse', () async {
      SharedPreferences.setMockInitialValues({
        'tutorial_interactivo_completado': true,
      });
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      expect(ctrl.visible, isFalse);
    });

    test('saltar todo lo cierra y lo persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      await ctrl.saltarTodo();
      expect(ctrl.visible, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tutorial_interactivo_completado'), isTrue);
    });

    test('retroceder no baja de cero', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      ctrl.anterior();
      expect(ctrl.indiceActual, 0);
      ctrl.siguiente();
      ctrl.anterior();
      expect(ctrl.indiceActual, 0);
    });

    test('oculto no pide pestañas (ni de Home ni de Ajustes)', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());
      await ctrl.saltarTodo();

      expect(ctrl.pestanaActual, isNull,
          reason: 'escondido no debe mover la Home');
      expect(ctrl.pestanaAjustesActual, isNull,
          reason: 'escondido no debe abrir Ajustes');
      expect(ctrl.enAjustesActual, isFalse);
    });
  });

  group('overlay', () {
    testWidgets('apunta al primer paso, avanza y se salta entero',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(
        Stack(
          children: [
            // Objetivo del primer paso, montado (como el feed en la Home).
            KeyedSubtree(
              key: keyTutorialFeed,
              child: const SizedBox(width: 320, height: 120),
            ),
            TutorialOverlay(controller: ctrl),
          ],
        ),
      ));

      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 1'), findsOneWidget);
      expect(find.text('1/13'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 2'), findsOneWidget);
      expect(find.text('2/13'), findsOneWidget);

      await tester.tap(find.text('Saltar tutorial'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 2'), findsNothing);
      expect(ctrl.completado, isTrue);
    });

    testWidgets('un paso sin objetivo montado se explica centrado',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      // Sólo el paso de controles: vive en el reproductor, acá no existe.
      final soloControles = [
        pasosDePrueba().firstWhere((p) => p.id == 'controles'),
      ];

      await tester.pumpWidget(_app(TutorialOverlay(controller: ctrl)));
      await ctrl.inicializar(soloControles);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 8'), findsOneWidget,
          reason: 'sin objetivo igual se explica, no queda invisible');
      // Y avisa que la función se ve al abrirla, para que no la busque acá.
      expect(find.text('Lo verás al abrirlo'), findsOneWidget);
      expect(find.text('¡Entendido!'), findsOneWidget,
          reason: 'si es el último paso, cierra el tutorial');
    });

    testWidgets('saltar un paso avanza sin cerrar el tutorial',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(TutorialOverlay(controller: ctrl)));
      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Saltar paso'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 2'), findsOneWidget);
      expect(ctrl.completado, isFalse);
    });

    testWidgets('la flecha de atrás vuelve al paso anterior', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(TutorialOverlay(controller: ctrl)));
      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      // En el primer paso no hay a dónde volver: la flecha no está.
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Titulo 1'), findsOneWidget);
      expect(ctrl.indiceActual, 0);
    });
  });

  group('pasos de la Home', () {
    test('cada paso declara la pestaña donde se ve lo que explica', () {
      final pasos = pasosDePrueba();
      int? pestana(String id) => pasos.firstWhere((p) => p.id == id).pestana;

      // El recorrido lleva al usuario por las tres secciones de la Home.
      expect(pestana('feed'), PestanaHome.inicio);
      expect(pestana('fuente'), PestanaHome.buscar);
      expect(pestana('busqueda'), PestanaHome.buscar);
      expect(pestana('reproducir'), PestanaHome.inicio);
      expect(pestana('ajustes'), PestanaHome.miEspacio);

      // El miniplayer está al pie en todas las secciones: no mueve a nadie.
      expect(pestana('miniplayer'), isNull);
    });

    test('los pasos de otra pantalla no apuntan a ningún widget', () {
      final pasos = pasosDePrueba();

      for (final id in ['controles']) {
        final paso = pasos.firstWhere((p) => p.id == id);
        expect(paso.targetKey, isNull,
            reason: '$id vive en otra vista: si apuntara a un key ajeno '
                'el agujero quedaría mal puesto');
        expect(paso.pestana, isNull,
            reason: '$id no está en la Home, no debe mover de pestaña');
      }
    });

    test('el controller expone la pestaña del paso actual', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      expect(ctrl.pestanaActual, PestanaHome.inicio);
      ctrl.siguiente();
      expect(ctrl.pestanaActual, PestanaHome.buscar,
          reason: 'el paso de la fuente vive en Buscar');
      ctrl.siguiente();
      ctrl.siguiente();
      expect(ctrl.pestanaActual, PestanaHome.inicio,
          reason: 'reproducir/like/descargar se explican sobre el feed');
    });
  });

  group('pasos de Ajustes', () {
    test('los pasos de ajustes entran a la hoja y eligen pestaña', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());

      // Hasta el paso 9 inclusive la hoja de ajustes está cerrada.
      for (var i = 0; i < 9; i++) {
        expect(ctrl.enAjustesActual, isFalse,
            reason: 'el paso $i no vive en Ajustes');
        ctrl.siguiente();
      }

      // Paso 10: apariencia, con el objetivo en la fila de pestañas.
      final paso10 = ctrl.pasoActual!;
      expect(paso10.targetKey, keyTutorialAjustesTabs);
      expect(ctrl.pestanaAjustesActual, PestanaAjustes.apariencia);
      expect(ctrl.enAjustesActual, isTrue);

      // Los tres siguientes explican el contenido de cada pestaña.
      final esperados = {
        'ajustesDescargas': PestanaAjustes.descargas,
        'ajustesRendimiento': PestanaAjustes.rendimiento,
        'ajustesMas': PestanaAjustes.mas,
      };
      ctrl.siguiente();
      // Se recorre hasta que el último paso cierre el tutorial.
      while (!ctrl.completado) {
        final paso = ctrl.pasoActual!;
        expect(paso.targetKey, keyTutorialAjustesContenido,
            reason: '${paso.id} debe señalar el contenido de la hoja');
        expect(ctrl.pestanaAjustesActual, esperados[paso.id],
            reason: '${paso.id} debe pararse en su pestaña');
        ctrl.siguiente();
      }
      expect(ctrl.completado, isTrue);
    });

    test('retroceder desde Ajustes vuelve a la Home', () async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();
      await ctrl.inicializar(pasosDePrueba());
      for (var i = 0; i < 9; i++) {
        ctrl.siguiente();
      }
      expect(ctrl.enAjustesActual, isTrue);

      ctrl.anterior();
      expect(ctrl.enAjustesActual, isFalse,
          reason: 'al volver atrás la hoja de ajustes se debe cerrar');
      expect(ctrl.pestanaActual, PestanaHome.miEspacio);
    });
  });

  group('textos', () {
    test('español e inglés tienen un texto por paso y en el mismo orden', () {
      final pasos = pasosDePrueba();

      for (final lista in [StringsTutorialInteractivo.es, StringsTutorialInteractivo.en]) {
        expect(lista.pasos.length, pasos.length,
            reason: 'si falta un texto, ese paso sale con el título vacío');
      }
      // Y los textos siguen el mismo orden en los dos idiomas: el paso 1 es
      // el mismo en ES y en EN.
      expect(StringsTutorialInteractivo.es.pasos.first.titulo,
          isNot(StringsTutorialInteractivo.en.pasos.first.titulo));
      expect(StringsTutorialInteractivo.es.pasos[9].titulo, 'Apariencia');
      expect(StringsTutorialInteractivo.en.pasos[9].titulo, 'Look and feel');
    });
  });

  group('la tarjeta siempre se ve', () {
    /// Comprueba que el paso actual quede entero dentro de la pantalla.
    void esperarEntera(WidgetTester tester, String titulo) {
      final pantalla = tester.view.physicalSize / tester.view.devicePixelRatio;
      final visible = Rect.fromLTWH(0, 0, pantalla.width, pantalla.height);
      final rect = tester.getRect(find.text(titulo));
      expect(visible.contains(rect.topLeft), isTrue,
          reason: 'el título del paso quedó fuera de pantalla (arriba/izq)');
      expect(rect.right <= visible.right, isTrue,
          reason: 'el título se sale por la derecha');
      // Los botones son lo que el usuario necesita tocar: si ellos no
      // entran, el paso queda trabado aunque el texto se lea.
      final boton = tester.getRect(find.text('Siguiente'));
      expect(boton.bottom <= visible.bottom, isTrue,
          reason: 'la tarjeta se sale por abajo: los botones no se alcanzan');
      expect(boton.top >= visible.top, isTrue,
          reason: 'la tarjeta se sale por arriba');
    }

    testWidgets('con un objetivo que ocupa toda la pantalla (el feed)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(
        Stack(
          children: [
            // Alto como el feed real: no entra ni arriba ni abajo.
            KeyedSubtree(
              key: keyTutorialFeed,
              child: const SizedBox.expand(),
            ),
            TutorialOverlay(controller: ctrl),
          ],
        ),
      ));
      // El objetivo tiene que estar montado ANTES de que el overlay lo mida,
      // si no el paso sale centrado y el caso que se quiere probar nunca se
      // ejecuta.
      await tester.pump();
      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      esperarEntera(tester, 'Titulo 1');
    });

    testWidgets('con un objetivo chico, debajo y sin salirse', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(
        Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: KeyedSubtree(
                key: keyTutorialFeed,
                child: const SizedBox(width: 200, height: 60),
              ),
            ),
            TutorialOverlay(controller: ctrl),
          ],
        ),
      ));
      await tester.pump();
      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      esperarEntera(tester, 'Titulo 1');
      // Y queda debajo del objetivo, no encima tapándolo.
      final objetivo = tester.getRect(find.byKey(keyTutorialFeed));
      expect(tester.getRect(find.text('Titulo 1')).top,
          greaterThan(objetivo.bottom));
    });
  });

  group('ubicación de la tarjeta', () {
    // Pantalla típica de celular y de PC.
    const celu = Size(360, 740);
    const pc = Size(1280, 800);
    const sinInset = EdgeInsets.zero;

    /// La tarjeta nunca puede quedar fuera de pantalla ni sin alto.
    void exigirDentroDePantalla(UbicacionTarjeta u, Size pantalla) {
      expect(u.izquierda >= 0, isTrue, reason: 'se sale por la izquierda');
      expect(u.izquierda + u.ancho <= pantalla.width, isTrue,
          reason: 'se sale por la derecha');
      expect(u.banda >= bandaMinimaTarjeta, isTrue,
          reason: 'le queda tan poco alto que la tarjeta no se lee');
      final total = pantalla.height - u.arriba - u.abajo;
      expect(total >= u.banda - 0.01, isTrue,
          reason: 'el alto disponible no alcanza para la banda calculada');
    }

    test('sin objetivo (otra vista) va centrada', () {
      final u = ubicarTarjeta(
        objetivo: null,
        pantalla: celu,
        inset: sinInset,
        ancho: 320,
      );
      expect(u.lado, LadoTarjeta.centrada);
      expect(u.conFlecha, isFalse);
      exigirDentroDePantalla(u, celu);
    });

    test('objetivo chico arriba: la tarjeta va abajo', () {
      final u = ubicarTarjeta(
        objetivo: const Rect.fromLTWH(60, 90, 240, 56),
        pantalla: celu,
        inset: sinInset,
        ancho: 320,
      );
      expect(u.lado, LadoTarjeta.abajo);
      expect(u.flechaArriba, isTrue, reason: 'la flecha apunta al objetivo');
      expect(u.arriba, 90 + 56 + 14);
      exigirDentroDePantalla(u, celu);
    });

    test('objetivo al pie: la tarjeta va arriba', () {
      final u = ubicarTarjeta(
        objetivo: const Rect.fromLTWH(0, 420, 360, 320),
        pantalla: celu,
        inset: sinInset,
        ancho: 320,
      );
      expect(u.lado, LadoTarjeta.arriba);
      expect(u.flechaArriba, isFalse, reason: 'acá la flecha apunta hacia abajo');
      expect(u.arriba + u.banda, 420 - 14);
      exigirDentroDePantalla(u, celu);
    });

    test('objetivo que ocupa la pantalla (el feed): centrada y sin flecha', () {
      final u = ubicarTarjeta(
        objetivo: const Rect.fromLTWH(0, 120, 360, 620),
        pantalla: celu,
        inset: sinInset,
        ancho: 320,
      );
      expect(u.lado, LadoTarjeta.centrada,
          reason: 'si no hay banda libre, mejor centrar que dibujar fuera');
      expect(u.conFlecha, isFalse);
      exigirDentroDePantalla(u, celu);
    });

    test('en PC la tarjeta también entra, con y sin objetivo', () {
      final casos = <Rect?>[
        null,
        const Rect.fromLTWH(200, 80, 800, 60),
        const Rect.fromLTWH(0, 60, 1280, 700),
        const Rect.fromLTWH(0, 600, 1280, 200),
      ];
      for (final objetivo in casos) {
        final u = ubicarTarjeta(
          objetivo: objetivo,
          pantalla: pc,
          inset: const EdgeInsets.only(top: 8, bottom: 8),
          ancho: 400,
        );
        exigirDentroDePantalla(u, pc);
      }
    });

    test('la barra de estado se respeta (no se dibuja debajo del reloj)', () {
      final u = ubicarTarjeta(
        objetivo: const Rect.fromLTWH(20, 300, 320, 40),
        pantalla: celu,
        inset: const EdgeInsets.only(top: 44, bottom: 24),
        ancho: 320,
      );
      expect(u.arriba >= 44, isTrue);
      final abajoDeLaTarjeta = u.arriba + u.banda;
      expect(abajoDeLaTarjeta <= celu.height - 24, isTrue,
          reason: 'no debe tapar la barra de navegación');
    });
  });

  group('medición del objetivo', () {
    testWidgets('sin objetivo montado devuelve null y con él su rect',
        (tester) async {
      final key = GlobalKey();
      // Nunca se montó: no hay nada que apuntar.
      expect(rectDeObjetivo(key), isNull);
      // Un paso de otra vista no tiene key: tampoco hay agujero.
      expect(rectDeObjetivo(null), isNull);

      await tester.pumpWidget(_app(
        Center(
          child: SizedBox(key: key, width: 120, height: 60),
        ),
      ));
      // Segundo frame: las localizaciones se resuelven en un Future, así que
      // el primer frame todavía no monta el hijo.
      await tester.pump();

      final rect = rectDeObjetivo(key);
      expect(rect, isNotNull, reason: 'el objetivo montado sí se mide');
      expect(rect!.width, 120);
      expect(rect.height, 60);
    });
  });

  group('en PC', () {
    testWidgets('la tarjeta se ve entera en 1280x800 y sin desbordar',
        (tester) async {
      // Pantalla de escritorio: si algo no entra, Flutter reporta overflow
      // como excepción y el test falla (no es un "se veía bien" a ojo).
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final ctrl = TutorialController();

      await tester.pumpWidget(_app(
        Stack(
          children: [
            KeyedSubtree(
              key: keyTutorialFeed,
              child: const SizedBox.expand(),
            ),
            TutorialOverlay(controller: ctrl),
          ],
        ),
      ));
      await tester.pump();
      await ctrl.inicializar(pasosDePrueba());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Titulo 1'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Saltar tutorial'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'en PC la tarjeta no debe desbordar el ancho de la pantalla');
    });
  });
}
