// ajustes_variantes_test.dart — El armado de la hoja de Ajustes, partido por
// plataforma (regla de vistas: celular, PC y TV, cada uno en su archivo).
//
// Lo que protege:
//   · el selector pregunta TV ANTES que PC (una tele ancha también entra en el
//     layout de escritorio: al revés, la tele recibiría el diseño de PC);
//   · el celular pone el navegador ARRIBA del contenido y muestra el tirador;
//   · la PC pone el navegador AL COSTADO y limita el ancho del conjunto;
//   · la tele va PLANA: navegador al costado, sin tirador (no se arrastra) ni
//     vidrio/desenfoque, y con el panel ocupando el lienzo.
//
// Antes de partirse, la hoja tenía los tres diseños dentro de un mismo archivo
// con ternarios, así que no había forma de verificar ninguno.
//
// Se conecta con: features/ajustes/sheet/vistas/** (las tres variantes y el
// selector).
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/features/ajustes/sheet/vistas/base/ajustes_marco.dart';
import 'package:bitly/features/ajustes/sheet/vistas/escritorio/ajustes_escritorio.dart';
import 'package:bitly/features/ajustes/sheet/vistas/movil/ajustes_movil.dart';
import 'package:bitly/features/ajustes/sheet/vistas/tv/ajustes_tv.dart';
import 'package:bitly/shared/utilidades/plataforma/responsive.dart';
import 'package:bitly/shared/widgets/vidrio/base/desenfoque_adaptativo.dart';

const _bg = Color(0xFF101010);
const _onBg = Color(0xFFEEEEEE);

/// Un slot reconocible: el tamaño del bloque dice dónde lo puso la variante.
Widget _slot(String id) => Container(
  key: Key(id),
  width: 60,
  height: 60,
  color: const Color(0xFF00FF00),
);

MarcoAjustes _marco(Responsive r, {bool hasTrack = false}) => MarcoAjustes(
  r: r,
  isDark: true,
  hasTrack: hasTrack,
  bg: _bg,
  onBg: _onBg,
  cabecera: _slot('cabecera'),
  navegacion: _slot('navegacion'),
  contenido: _slot('contenido'),
);

/// Monta [construir] con un `Responsive` real y el tamaño pedido.
Future<void> _montar(
  WidgetTester tester,
  Widget Function(Responsive r) construir, {
  Size tamano = const Size(800, 600),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: tamano),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) => construir(Responsive(context))),
      ),
    ),
  );
  await tester.pump();
}

/// Pregunta la variante que elige el selector con el tamaño [tamano].
Future<VarianteAjustes> _varianteEn(
  WidgetTester tester,
  Size tamano, {
  TargetPlatform? plataforma,
}) async {
  debugDefaultTargetPlatformOverride = plataforma;
  late VarianteAjustes variante;
  await _montar(tester, (r) {
    variante = varianteAjustes(r.context);
    return const SizedBox();
  }, tamano: tamano);
  debugDefaultTargetPlatformOverride = null;
  return variante;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('selector de la hoja de Ajustes', () {
    testWidgets('en celular usa la variante móvil', (tester) async {
      expect(
        await _varianteEn(tester, const Size(400, 800)),
        VarianteAjustes.movil,
      );
    });

    testWidgets('en PC usa la variante de escritorio', (tester) async {
      expect(
        await _varianteEn(
          tester,
          const Size(1400, 900),
          plataforma: TargetPlatform.windows,
        ),
        VarianteAjustes.escritorio,
      );
    });

    testWidgets('en TV (pantalla ancha de Android) gana TV, no PC', (
      tester,
    ) async {
      expect(
        await _varianteEn(tester, const Size(1280, 720)),
        VarianteAjustes.tv,
        reason:
            'una tele ancha también entraría en el layout de escritorio, así '
            'que TV se pregunta primero',
      );
    });

    testWidgets('MarcoAjustesVista monta la variante que toca', (tester) async {
      await _montar(
        tester,
        (r) => MarcoAjustesVista(marco: _marco(r)),
        tamano: const Size(400, 800),
      );
      expect(find.byType(AjustesMovil), findsOneWidget);
      expect(find.byType(AjustesEscritorio), findsNothing);

      await _montar(
        tester,
        (r) => MarcoAjustesVista(marco: _marco(r)),
        tamano: const Size(1280, 720),
      );
      expect(find.byType(AjustesTv), findsOneWidget);
    });
  });

  group('hoja de Ajustes en celular', () {
    testWidgets('el navegador va arriba del contenido y hay tirador', (
      tester,
    ) async {
      await _montar(
        tester,
        (r) => AjustesMovil(marco: _marco(r)),
        tamano: const Size(400, 800),
      );

      final nav = tester.getCenter(find.byKey(const Key('navegacion')));
      final contenido = tester.getCenter(find.byKey(const Key('contenido')));
      expect(
        nav.dy,
        lessThan(contenido.dy),
        reason: 'en celular las burbujas van arriba del contenido',
      );
      expect(nav.dx, contenido.dx, reason: 'mismo eje: no hay riel lateral');
      expect(find.byKey(claveTiradorAjustes), findsOneWidget);
    });
  });

  group('hoja de Ajustes en PC', () {
    testWidgets(
      'el navegador va al costado y el conjunto tiene tope de ancho',
      (tester) async {
        await _montar(
          tester,
          (r) => AjustesEscritorio(marco: _marco(r)),
          tamano: const Size(1600, 900),
        );

        final nav = tester.getCenter(find.byKey(const Key('navegacion')));
        final contenido = tester.getCenter(find.byKey(const Key('contenido')));
        expect(
          nav.dx,
          lessThan(contenido.dx),
          reason: 'en PC el riel va a la izquierda del contenido',
        );
        expect(nav.dy, contenido.dy, reason: 'mismo renglón');
        expect(
          find.byType(ConstrainedBox),
          findsWidgets,
          reason: 'el ancho del conjunto se limita para que no se estire',
        );
        expect(find.byKey(claveTiradorAjustes), findsOneWidget);
      },
    );
  });

  group('hoja de Ajustes en TV', () {
    testWidgets('va plana: sin tirador ni vidrio, navegador al costado', (
      tester,
    ) async {
      await _montar(
        tester,
        (r) => AjustesTv(marco: _marco(r, hasTrack: true)),
        tamano: const Size(1920, 1080),
      );

      final nav = tester.getCenter(find.byKey(const Key('navegacion')));
      final contenido = tester.getCenter(find.byKey(const Key('contenido')));
      expect(nav.dx, lessThan(contenido.dx), reason: 'riel al costado');

      expect(
        find.byKey(claveTiradorAjustes),
        findsNothing,
        reason: 'en la tele no se arrastra para cerrar: el tirador sobra',
      );
      expect(
        find.byType(DesenfoqueAdaptativo),
        findsNothing,
        reason:
            'la tele va PLANO: el desenfoque se paga en cada frame y a metros '
            'no se ve (regla de vistas de TV)',
      );

      final panel = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == _bg);
      expect(
        panel,
        isNotEmpty,
        reason: 'el panel es opaco: no deja pasar el tinte del cover',
      );
    });

    testWidgets('el panel ocupa el alto disponible, sin desbordar', (
      tester,
    ) async {
      // El lienzo real tiene que medir lo mismo que el `MediaQuery`: la
      // variante de TV se mide con lo que le deja la hoja modal.
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _montar(
        tester,
        (r) => AjustesTv(marco: _marco(r)),
        tamano: const Size(1280, 720),
      );

      expect(tester.takeException(), isNull);
      final alto = tester.getSize(find.byType(AjustesTv)).height;
      expect(
        alto,
        greaterThan(720 * 0.9),
        reason: 'en la tele el panel llega casi hasta el borde del lienzo',
      );
    });
  });
}
