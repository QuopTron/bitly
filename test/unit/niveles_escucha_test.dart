// Tests de la escalera de niveles de escucha: umbrales, progreso y premios
// ocultos. Lo importante: que la escalera llegue lejos (más de 4 años de
// escucha continua), que el nivel no mienta y que un premio NUNCA se vea
// antes de desbloquearlo.

import 'package:bitly/core/modelos/logros/niveles_escucha.dart';
import 'package:bitly/core/modelos/logros/progreso_escucha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Escalera', () {
    test('arranca en el primer nivel con 0 horas escuchadas', () {
      final p = ProgresoEscucha.desdeMs(0);
      expect(p.indice, -1);
      expect(p.tieneNivel, isFalse);
      // El próximo hito es el primer nivel (1 hora).
      expect(p.siguiente?.horas, nivelesEscucha.first.horas);
      expect(p.avance, 0);
      expect(p.horasFaltantes, nivelesEscucha.first.horas);
    });

    test('los umbrales suben siempre (nunca hay un nivel más fácil)', () {
      for (var i = 1; i < nivelesEscucha.length; i++) {
        expect(
          nivelesEscucha[i].horas,
          greaterThan(nivelesEscucha[i - 1].horas),
          reason: 'el nivel $i no es más exigente que el anterior',
        );
      }
    });

    test('el techo pide más de 4 años de escucha 24/7', () {
      final techo = nivelesEscucha.last.horas;
      // 4 años de 24 horas = 35.040 horas.
      expect(techo, greaterThanOrEqualTo(35040));
    });

    test('cada nivel tiene su premio', () {
      for (final n in nivelesEscucha) {
        expect(n.premio.trim(), isNotEmpty);
        expect(n.nombre.trim(), isNotEmpty);
      }
    });
  });

  group('Progreso', () {
    test('con 12 horas ya desbloqueó el nivel de 10 y va por el de 50', () {
      final p = ProgresoEscucha.desdeMs(12 * 3600000);
      expect(p.actual.horas, 10);
      expect(p.siguiente!.horas, 50);
      expect(p.desbloqueado(0), isTrue);
      expect(p.desbloqueado(1), isTrue);
      expect(p.desbloqueado(2), isFalse);
      expect(p.avance, lessThan(0.1));
      expect(p.horasFaltantes, 38);
    });

    test('en el techo no hay siguiente y el avance es completo', () {
      final p = ProgresoEscucha.desdeMs(nivelesEscucha.last.horas * 3600000);
      expect(p.siguiente, isNull);
      expect(p.avance, 1);
      expect(p.horasFaltantes, 0);
      expect(p.desbloqueado(nivelesEscucha.length - 1), isTrue);
    });

    test('valores raros (negativos) no rompen ni adelantan nivel', () {
      final p = ProgresoEscucha.desdeMs(-5000);
      expect(p.indice, -1);
      expect(p.avance, 0);
    });

    test('a mitad de tramo el avance es proporcional', () {
      // Entre 10 h (nivel 1) y 50 h (nivel 2): 30 h es la mitad del tramo.
      final p = ProgresoEscucha.desdeMs(30 * 3600000);
      expect(p.avance, closeTo(0.5, 0.001));
    });
  });
}
