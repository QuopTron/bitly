// puntero_tv_padding_test.dart — El puntero de TV montado como en la app REAL,
// con padding del sistema.
//
// Qué bug fija: en app.dart el orden es
//
//     PunteroTv                       ← el cursor mueve píxeles REALES de pantalla
//       └ protegerLayout
//          └ vistaDisenoTv            ← lienzo lógico 1280 escalado al panel
//             └ la pantalla
//
// El test anterior (puntero_tv_test.dart) probaba el puntero SOLO, sin el
// lienzo ni el escalado. Con el árbol real, cualquier capa que desplace o
// escale el contenido (padding del sistema, FittedBox del lienzo, protección
// por densidad) podía desalinear el cursor de lo que hay debajo: se ve el
// cursor sobre una tarjeta y el clic cae en otra — o en el vacío.
//
// La causa era que el `Stack` de PunteroTv usaba `StackFit.loose`, así que el
// `FittedBox` del lienzo de TV se dimensionaba a su HIJO (1280x720) en vez de a
// la pantalla y NO escalaba. En una TV de 1920x1080 el contenido quedaba
// dibujado en una esquina a 1280x720 mientras el cursor recorría los 1920x1080
// reales. El arreglo es `StackFit.expand`.
//
// Se verifica lo que el usuario reporta: que el clic caiga SOBRE EL WIDGET QUE
// SE VE EN EL CURSOR, con padding del sistema presente y sin importar el DPI.
//
// Se conecta con: lib/app.dart (orden de montaje) + shared/widgets/tv/puntero_tv
// + shared/utilidades/plataforma/vista_tv.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/shared/utilidades/plataforma/escala_texto.dart';
import 'package:bitly/shared/utilidades/plataforma/vista_tv.dart';
import 'package:bitly/shared/widgets/tv/puntero_tv.dart';

/// Botón de prueba con etiqueta: guarda CUÁL recibió el clic (y dónde, para
/// poder medir un desalineo si falla).
class _Blanco extends StatelessWidget {
  const _Blanco({
    required this.etiqueta,
    required this.clics,
    required this.puntos,
  });

  final String etiqueta;
  final List<String> clics;
  final List<Offset> puntos;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        clics.add(etiqueta);
        puntos.add(d.globalPosition);
      },
      child: Container(
        alignment: Alignment.center,
        color: Colors.blueGrey,
        child: Text(etiqueta),
      ),
    );
  }
}

/// Reproduce el montaje de app.dart para TV: lienzo de diseño + protección de
/// layout + puntero POR ENCIMA (píxeles reales).
Widget _appTvReal({required List<String> clics, required List<Offset> puntos, required Widget cuadricula}) {
  return MaterialApp(
    builder: (context, hijo) {
      Widget contenido = hijo ?? const SizedBox.shrink();
      contenido = vistaDisenoTv(context: context, child: contenido);
      contenido = protegerLayout(context: context, child: contenido);
      return PunteroTv(child: contenido);
    },
    home: cuadricula,
  );
}

void main() {
  group('puntero de TV en el árbol real', () {
    testWidgets('el clic cae en el widget que está debajo del cursor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final clics = <String>[];
      final puntos = <Offset>[];
      await tester.pumpWidget(
        _appTvReal(
          clics: clics,
          puntos: puntos,
          cuadricula: Row(
            children: [
              Expanded(
                child: _Blanco(
                  etiqueta: 'IZQUIERDA',
                  clics: clics,
                  puntos: puntos,
                ),
              ),
              Expanded(
                child: _Blanco(
                  etiqueta: 'DERECHA',
                  clics: clics,
                  puntos: puntos,
                ),
              ),
            ],
          ),
        ),
      );

      // Moverse a la mitad izquierda del panel: el cursor arranca en el centro
      // (960) y tres flechas a la izquierda lo meten bien adentro del bloque
      // izquierdo.
      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
      }
      final cursor = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      debugPrint('CURSOR=$cursor');
      debugPrint('IZQ=${tester.getRect(find.text('IZQUIERDA'))}');
      debugPrint('DER=${tester.getRect(find.text('DERECHA'))}');
      expect(
        cursor.dx,
        lessThan(960.0),
        reason: 'el cursor tiene que haberse movido a la izquierda (quedó en '
            '$cursor sobre una pantalla de 1920x1080)',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        clics,
        ['IZQUIERDA'],
        reason: 'con el cursor sobre el bloque izquierdo, el clic tiene que '
            'activar ESE bloque (era el "clic falso" reportado)',
      );
      // Y exactamente donde se ve el cursor: no "cerca", ahí.
      expect((puntos.single - cursor).distance, lessThan(0.5));
    });

    testWidgets('con padding del sistema el clic sigue cayendo en el cursor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Una TV puede reportar recortes/insets (overscan, barras laterales).
      // El lienzo los reescala, así que el contenido se dibuja más adentro:
      // si el cursor no acompaña, el clic cae en el vecino.
      tester.view.viewPadding = const FakeViewPadding(left: 48, top: 24);

      final clics = <String>[];
      final puntos = <Offset>[];
      await tester.pumpWidget(
        _appTvReal(
          clics: clics,
          puntos: puntos,
          cuadricula: Row(
            children: [
              Expanded(
                child: _Blanco(
                  etiqueta: 'IZQUIERDA',
                  clics: clics,
                  puntos: puntos,
                ),
              ),
              Expanded(
                child: _Blanco(
                  etiqueta: 'DERECHA',
                  clics: clics,
                  puntos: puntos,
                ),
              ),
            ],
          ),
        ),
      );

      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      final cursor = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      debugPrint('CURSOR_CON_PADDING=$cursor');
      expect(cursor.dx, greaterThan(960.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        clics,
        ['DERECHA'],
        reason: 'el padding del sistema no puede desalinear el clic del cursor',
      );
      expect((puntos.single - cursor).distance, lessThan(0.5));
    });

    testWidgets('el cursor no se sale del área visible', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final clics = <String>[];
      final puntos = <Offset>[];
      await tester.pumpWidget(
        _appTvReal(
          clics: clics,
          puntos: puntos,
          cuadricula: _Blanco(
            etiqueta: 'UNICO',
            clics: clics,
            puntos: puntos,
          ),
        ),
      );

      // Muchas flechas hacia abajo-derecha: el cursor tiene que quedar dentro
      // de la pantalla (si se va afuera, el clic no cae en nada).
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.pump();

      final cursor = tester.getCenter(find.byKey(PunteroTv.claveCursor));
      expect(cursor.dx, lessThanOrEqualTo(1280.0));
      expect(cursor.dy, lessThanOrEqualTo(720.0));
      expect(cursor.dx, greaterThanOrEqualTo(0.0));
      expect(cursor.dy, greaterThanOrEqualTo(0.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 120));
      expect(clics, ['UNICO'],
          reason: 'en la esquina el clic tiene que seguir sirviendo');
      expect((puntos.single - cursor).distance, lessThan(0.5));
    });
  });
}
