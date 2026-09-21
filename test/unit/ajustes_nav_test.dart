// ajustes_nav_test.dart — Prueba el navegador del menú de Ajustes: que las
// etiquetas localizadas estén en el mismo orden y cantidad que los íconos
// (un desfasaje ahí abre la pestaña equivocada) y que el riel lateral sólo
// se use en pantalla ancha, donde la fila de burbujas ya no se lee.
//
// Se conecta con: features/ajustes/sheet/settings_sheet_nav.dart (el
// navegador), settings_sheet_entry.dart (los íconos) y strings_ajustes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Las partes no se importan suelto: se entra por la library que las une.
import 'package:bitly/features/ajustes/sheet/settings_sheet_new.dart';
import 'package:bitly/features/tutorial_interactivo/motor/tutorial_claves.dart';
import 'package:bitly/l10n/app_localizations.dart';

/// Pregunta cómo se muestra el menú en un ancho dado.
Future<bool> usaRielEn(WidgetTester tester, Size tamano) async {
  var usaRiel = false;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: tamano),
      child: Builder(
        builder: (context) {
          usaRiel = ajustesUsaRiel(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return usaRiel;
}

void main() {
  test('las etiquetas y los íconos de las pestañas están alineados', () {
    expect(
      StringsAjustes.es.pestanas.length,
      cantidadPestanasAjustes,
      reason: 'una etiqueta de más o de menos corre todas las pestañas',
    );
    expect(StringsAjustes.en.pestanas.length, cantidadPestanasAjustes);
    // 8 desde que Conexión (los aparatos de la cuenta) tiene su burbuja.
    expect(cantidadPestanasAjustes, 8);
  });

  test('los índices de PestanaAjustes caen en su etiqueta', () {
    // Un índice corrido hace que el tutorial abra una pestaña y el usuario
    // vea otra: por eso se fija acá, no solo la cantidad.
    final etiquetas = StringsAjustes.es.pestanas;
    expect(etiquetas[PestanaAjustes.apariencia], 'Apariencia');
    expect(etiquetas[PestanaAjustes.descargas], 'Descargas');
    expect(etiquetas[PestanaAjustes.rendimiento], 'Rendimiento');
    expect(etiquetas[PestanaAjustes.estadisticas], 'Estadísticas');
    expect(etiquetas[PestanaAjustes.cuenta], 'Cuenta');
    expect(etiquetas[PestanaAjustes.proveedores], 'Proveedores');
    expect(etiquetas[PestanaAjustes.conexion], 'Conexión');
    expect(etiquetas[PestanaAjustes.mas], 'Más');
  });

  test('cada etiqueta tiene su texto (sin huecos)', () {
    for (final etiquetas in [
      StringsAjustes.es.pestanas,
      StringsAjustes.en.pestanas,
    ]) {
      for (final etiqueta in etiquetas) {
        expect(etiqueta.trim(), isNotEmpty);
      }
    }
  });

  testWidgets('el riel se usa sólo en pantalla ancha', (tester) async {
    // Celular vertical y tablet vertical: fila de burbujas.
    expect(await usaRielEn(tester, const Size(400, 800)), isFalse);
    expect(await usaRielEn(tester, const Size(700, 1200)), isFalse);
    // PC / TV: riel lateral.
    expect(await usaRielEn(tester, const Size(1400, 900)), isTrue);
  });
}
