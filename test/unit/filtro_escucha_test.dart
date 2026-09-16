// Tests de los filtros de estadísticas: rango temporal y orden.
//
// Lo que importa: que el rango no invente ni borre escuchas (una fila sin
// fecha no puede desaparecer por elegir "7 días") y que cada orden haga lo
// que dice su etiqueta.

import 'package:bitly/core/servicios/estadisticas/filtro_escucha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ahora = DateTime(2026, 9, 16, 12);
  final filas = <FilaEscucha>[
    FilaEscucha(
      id: 'a',
      nombre: 'Zeta',
      reproducciones: 5,
      minutos: 20,
      ultimaVez: ahora.subtract(const Duration(days: 2)),
    ),
    FilaEscucha(
      id: 'b',
      nombre: 'alfa',
      reproducciones: 30,
      minutos: 100,
      ultimaVez: ahora.subtract(const Duration(days: 200)),
    ),
    FilaEscucha(id: 'c', nombre: 'Media', reproducciones: 12, minutos: 40),
  ];

  group('Rango', () {
    test('7 días deja lo reciente y NO borra las filas sin fecha', () {
      final r = aplicarFiltroEscucha(
        filas,
        rango: RangoEscucha.sieteDias,
        ahora: ahora,
      );
      expect(r.map((f) => f.id), containsAll(['a', 'c']));
      expect(r.map((f) => f.id), isNot(contains('b')));
    });

    test('hoy solo cuenta lo de hoy', () {
      final hoy = [
        FilaEscucha(id: 'x', nombre: 'X', ultimaVez: ahora),
        FilaEscucha(
          id: 'y',
          nombre: 'Y',
          ultimaVez: ahora.subtract(const Duration(hours: 20)),
        ),
      ];
      final r = aplicarFiltroEscucha(hoy, rango: RangoEscucha.hoy, ahora: ahora);
      expect(r.map((f) => f.id), ['x']);
    });

    test('1 año conserva lo de hace 200 días', () {
      final r = aplicarFiltroEscucha(
        filas,
        rango: RangoEscucha.unAnio,
        ahora: ahora,
      );
      expect(r.map((f) => f.id), contains('b'));
    });

    test('todo no filtra nada', () {
      final r = aplicarFiltroEscucha(filas, rango: RangoEscucha.todo);
      expect(r.length, filas.length);
    });
  });

  group('Orden', () {
    test('más reproducidas primero por conteo descendente', () {
      final r = aplicarFiltroEscucha(filas, orden: OrdenEscucha.masReproducidas);
      expect(r.map((f) => f.id).toList(), ['b', 'c', 'a']);
    });

    test('menos reproducidas es el inverso', () {
      final r =
          aplicarFiltroEscucha(filas, orden: OrdenEscucha.menosReproducidas);
      expect(r.map((f) => f.id).first, 'a');
    });

    test('A→Z ignora mayúsculas y acentos de orden', () {
      final r = aplicarFiltroEscucha(filas, orden: OrdenEscucha.az);
      expect(r.map((f) => f.nombre).toList(), ['alfa', 'Media', 'Zeta']);
    });

    test('Z→A es el inverso', () {
      final r = aplicarFiltroEscucha(filas, orden: OrdenEscucha.za);
      expect(r.map((f) => f.nombre).first, 'Zeta');
    });

    test('más recientes pone primero la última escuchada', () {
      final r = aplicarFiltroEscucha(filas, orden: OrdenEscucha.recientes);
      expect(r.first.id, 'a');
    });
  });

  test('el filtro no modifica la lista original', () {
    final copia = List<FilaEscucha>.from(filas);
    aplicarFiltroEscucha(filas, orden: OrdenEscucha.az);
    expect(filas.map((f) => f.id).toList(), copia.map((f) => f.id).toList());
  });

  test('los minutos totales suman lo visible', () {
    expect(minutosDeFilas(filas), 160);
  });
}
