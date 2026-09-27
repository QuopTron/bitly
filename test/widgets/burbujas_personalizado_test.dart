// burbujas_personalizado_test.dart — El selector de burbujitas de los bloques
// "Personalizado" de Ajustes → Apariencia.
//
// Por qué existe: los bloques personalizados apilaban un deslizador por cosa,
// y con cinco juntos no se sabía cuál se estaba moviendo. Ahora hay una
// burbujita por cosa y el deslizador de abajo muestra SOLO la elegida, así que
// lo que protege este test es que el toque cambie la selección, que tocar la
// que ya está no dispare nada, y que la fila no se desborde en pantalla chica.
//
// Se conecta con: features/ajustes/sheet/apariencia/general/piezas/
// burbujas_personalizado.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/features/ajustes/sheet/apariencia/general/piezas/burbujas_personalizado.dart';
import 'package:bitly/shared/utilidades/plataforma/responsive.dart';

/// App mínima con la fila de burbujas y la selección viva, como en la app.
Widget _app({required List<int> elegidas, Size tamano = const Size(400, 800)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: tamano),
      child: Scaffold(
        body: StatefulBuilder(
          builder:
              (context, setState) => Center(
                child: BurbujasPersonalizado(
                  opciones: const [
                    OpcionBurbuja(
                      icono: Icons.music_note_rounded,
                      etiqueta: 'Cards de canción',
                    ),
                    OpcionBurbuja(
                      icono: Icons.grid_view_rounded,
                      etiqueta: 'Cards de grilla',
                    ),
                    OpcionBurbuja(
                      icono: Icons.wallpaper_rounded,
                      etiqueta: 'Fondo principal',
                    ),
                  ],
                  seleccionada: elegidas.isEmpty ? 0 : elegidas.last,
                  onSeleccion: (i) => setState(() => elegidas.add(i)),
                  glowColor: const Color(0xFF1DB954),
                  onBg: const Color(0xFFEEEEEE),
                  r: Responsive(context),
                ),
              ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('dibuja una burbujita por cosa', (tester) async {
    await tester.pumpWidget(_app(elegidas: []));

    expect(find.text('Cards de canción'), findsOneWidget);
    expect(find.text('Cards de grilla'), findsOneWidget);
    expect(find.text('Fondo principal'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'nada se desborda');
  });

  testWidgets('tocar otra burbuja la elige', (tester) async {
    final elegidas = <int>[];
    await tester.pumpWidget(_app(elegidas: elegidas));

    await tester.tap(find.text('Fondo principal'));
    await tester.pumpAndSettle();

    expect(elegidas, [2], reason: 'avisa con el índice de la burbuja tocada');
    final fila = tester.widget<BurbujasPersonalizado>(
      find.byType(BurbujasPersonalizado),
    );
    expect(fila.seleccionada, 2, reason: 'y queda marcada como la elegida');
  });

  testWidgets('tocar la burbuja que ya está no hace nada', (tester) async {
    final elegidas = <int>[];
    await tester.pumpWidget(_app(elegidas: elegidas));

    await tester.tap(find.text('Cards de canción'));
    await tester.pump();

    expect(elegidas, isEmpty, reason: 'no hay cambio: no se avisa de nuevo');
  });

  testWidgets('en pantalla chica las burbujas bajan de renglón', (
    tester,
  ) async {
    // Un celular angosto con letras grandes: la fila se acomoda sola (Wrap) en
    // vez de desbordar, que es lo que rompía el diseño anterior.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(elegidas: [], tamano: const Size(320, 640)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Fondo principal'), findsOneWidget);
  });
}
