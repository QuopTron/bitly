// ─────────────────────────────────────────────────────────────
// grilla_vista_columnas_test.dart — La cuenta de columnas de las grillas.
//
// Dos cosas se están cubriendo, y las dos importan:
//   1. que los UMBRALES sigan siendo los de siempre (2/3/4/6), porque la cuenta
//      estaba copiada en tres archivos y al unificarla el riesgo es mover un
//      número sin querer y cambiar el tamaño de las portadas en todas las
//      vistas a la vez;
//   2. que el TOPE de la vista se aplique, porque es lo que le da sentido al
//      control de Ajustes → Apariencia → Vistas: sin consumidor sería un
//      deslizador que no hace nada.
//
// Se monta `AmbitoVista` directo (no `DisenoDeVista`): lo que se prueba acá es
// "leer el ámbito y aplicar el tope", no la cascada — esa ya la cubre
// apariencia_vistas_ambito_test.dart. Así este test no necesita DI.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/grilla_vista.dart';
import 'package:bitly/shared/widgets/vista/base/ambito_vista.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Lo que la sonda midió.
  late int columnas;

  /// Sonda: pide las columnas EXACTAMENTE como lo hace una grilla.
  Widget sonda(double ancho) => Builder(
    builder: (context) {
      columnas = columnasDeGrilla(context, ancho);
      return const SizedBox();
    },
  );

  /// Monta la sonda dentro de una vista que tiene [tope] columnas (0 = sin tope).
  Future<void> montar(
    WidgetTester tester,
    double ancho, {
    int? tope,
  }) => tester.pumpWidget(
    MaterialApp(
      home:
          tope == null
              ? sonda(ancho)
              : AmbitoVista(
                vista: VistaApp.feed,
                declarado: DisenoVista(columnasMax: tope),
                resuelto: _resuelto(columnasMax: tope),
                child: sonda(ancho),
              ),
    ),
  );

  group('sin vista: los umbrales de SIEMPRE', () {
    testWidgets('340 px o menos: 2 columnas', (tester) async {
      await montar(tester, 340);
      expect(columnas, 2);
    });

    testWidgets('más de 340: 3 columnas', (tester) async {
      await montar(tester, 341);
      expect(columnas, 3);
    });

    testWidgets('más de 700: 4 columnas', (tester) async {
      await montar(tester, 701);
      expect(columnas, 4);
    });

    testWidgets('más de 1000: 6 columnas', (tester) async {
      await montar(tester, 1001);
      expect(columnas, 6);
    });

    testWidgets('no hay tope que aplicar', (tester) async {
      // Un ancho enorme sin ninguna vista alrededor sigue dando 6.
      await montar(tester, 4000);
      expect(columnas, 6);
    });
  });

  group('con tope de la vista', () {
    testWidgets('el tope manda sobre el ancho', (tester) async {
      await montar(tester, 1200, tope: 2);
      expect(columnas, 2);
    });

    testWidgets('un tope intermedio se respeta', (tester) async {
      await montar(tester, 1200, tope: 5);
      expect(columnas, 5);
    });

    testWidgets('un tope mayor que el ancho NO inventa columnas', (tester) async {
      // Pedirle 6 a un cajón de 400 px daría portadas del tamaño de un sello:
      // el tope sólo puede REDUCIR.
      await montar(tester, 400, tope: 6);
      expect(columnas, 3);
    });

    testWidgets('tope igual a las del ancho no cambia nada', (tester) async {
      await montar(tester, 1200, tope: 6);
      expect(columnas, 6);
    });

    testWidgets('tope 0 es automático', (tester) async {
      await montar(tester, 1200, tope: 0);
      expect(columnas, 6);
    });
  });
}

/// Un `DisenoResuelto` mínimo con el tope puesto (el resto heredado).
DisenoResuelto _resuelto({required int columnasMax}) => DisenoResuelto(
  disenoId: '',
  tipografiaId: '',
  estiloCardId: '',
  fondoId: '',
  radioTarjeta: 14,
  densidad: 1,
  columnasMax: columnasMax,
);
