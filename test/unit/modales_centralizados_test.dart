// ─────────────────────────────────────────────────────────────
// modales_centralizados_test.dart — Vigila la regla "ningún modal
// sobre otro": TODA hoja y TODO diálogo de lib/ tiene que abrirse con
// mostrarHoja/mostrarDialogo (los únicos que saben si hay otro modal
// abajo y opacan el velo). Si alguien vuelve a llamar a
// showModalBottomSheet/showDialog de forma directa, este test falla.
// Parte del flujo: cualquier modal de la app.
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El helper es la ÚNICA excepción: adentro sí llama a los de Flutter.
const _helper = 'lib/shared/utilidades/modales/mostrar_modal.dart';

/// Aperturas que se saltarían el velo opaco.
const _crudas = ['showModalBottomSheet', 'showDialog', 'showGeneralDialog'];

void main() {
  test('ningún archivo abre hojas/diálogos sin pasar por el helper', () {
    final archivos =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => f.path.replaceAll(r'\', '/') != _helper)
            .toList();

    // Si el escaneo viera cero archivos, el test pasaría sin comprobar nada.
    expect(
      archivos.length,
      greaterThan(300),
      reason: 'el escaneo tiene que recorrer todo lib/',
    );

    final infractores = <String>[];
    for (final archivo in archivos) {
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i].trim();
        if (linea.startsWith('//')) continue; // comentario, no código
        if (_crudas.any(linea.contains)) {
          infractores.add('${archivo.path}:${i + 1}: $linea');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'estas aperturas se saltan mostrarHoja/mostrarDialogo '
          '(el velo que tapa el modal de abajo):\n${infractores.join('\n')}',
    );
  });
}
