// Tests del formato del detalle de estadísticas.
//
// Lo que importa: que "cuándo escuché esto" se entienda de un vistazo y que
// ninguna fecha rara (nula, futura, de hace años) rompa la fila.

import 'package:bitly/core/servicios/estadisticas/formato_escucha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hoy = DateTime(2026, 9, 16, 12);

  test('hoy, ayer y esta semana', () {
    expect(textoUltimaVez(DateTime(2026, 9, 16, 8), ahora: hoy), 'hoy');
    expect(textoUltimaVez(DateTime(2026, 9, 15), ahora: hoy), 'ayer');
    expect(textoUltimaVez(DateTime(2026, 9, 13), ahora: hoy), 'hace 3 días');
  });

  test('semanas, meses y años', () {
    expect(textoUltimaVez(DateTime(2026, 9, 8), ahora: hoy), 'hace 1 semana');
    expect(textoUltimaVez(DateTime(2026, 9, 1), ahora: hoy), 'hace 2 semanas');
    expect(textoUltimaVez(DateTime(2026, 8, 10), ahora: hoy), 'hace 1 mes');
    expect(textoUltimaVez(DateTime(2026, 4, 10), ahora: hoy), 'hace 5 meses');
    expect(textoUltimaVez(DateTime(2025, 5, 10), ahora: hoy), 'hace 1 año');
  });

  test('más de dos años muestra la fecha exacta', () {
    expect(textoUltimaVez(DateTime(2023, 3, 4), ahora: hoy), '4 mar 2023');
  });

  test('sin fecha usa el texto de desconocido', () {
    expect(textoUltimaVez(null), 'sin fecha');
    expect(textoUltimaVez(null, desconocido: '—'), '—');
  });

  test('una fecha futura no muestra días negativos', () {
    expect(textoUltimaVez(DateTime(2026, 12, 1), ahora: hoy), 'hoy');
  });

  test('minutos y horas', () {
    expect(textoMinutos(0), '');
    expect(textoMinutos(45), '45 min');
    expect(textoMinutos(60), '1 h');
    expect(textoMinutos(185), '3 h 5 min');
  });

  test('contador de reproducciones en singular y plural', () {
    expect(textoReproducciones(1), '1 vez');
    expect(textoReproducciones(0), '0 veces');
    expect(textoReproducciones(12), '12 veces');
  });
}
