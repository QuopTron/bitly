// Tests de la decisión de fin de canción (`completed` del player).
//
// El bug que fijan: una canción terminaba y la cola se quedaba EN PAUSA aunque
// hubiera más canciones, porque la completación sin duración conocida devolvía
// "no avances" sin reabrir nada. Ahora ninguna rama deja la cola muda.

import 'package:bitly/core/servicios/reproduccion/decision_completado.dart';
import 'package:flutter_test/flutter_test.dart';

DecisionCompletado _decidir({
  bool desdeHttp = true,
  int durMs = 0,
  int posMs = 0,
  int catalogoMs = 0,
  int msDesdeOpen = 10000,
  bool previewIntentado = false,
  bool muertoIntentado = false,
}) =>
    decidirCompletado(
      desdeHttp: desdeHttp,
      durMs: durMs,
      posMs: posMs,
      duracionCatalogoMs: catalogoMs,
      msDesdeOpen: msDesdeOpen,
      yaSeIntentoPreview: previewIntentado,
      yaSeIntentoStreamMuerto: muertoIntentado,
    );

void main() {
  test('fin normal: la cola avanza', () {
    expect(_decidir(durMs: 200000, posMs: 200000, catalogoMs: 200000),
        DecisionCompletado.avanzar);
  });

  test('un archivo local siempre avanza (sin falsos positivos)', () {
    expect(_decidir(desdeHttp: false, durMs: 30000, catalogoMs: 200000),
        DecisionCompletado.avanzar);
  });

  test('clip de 30s se reabre una vez y después avanza', () {
    expect(_decidir(durMs: 30000, posMs: 30000, catalogoMs: 200000),
        DecisionCompletado.reabrirMismo);
    expect(
      _decidir(
        durMs: 30000,
        posMs: 30000,
        catalogoMs: 200000,
        previewIntentado: true,
      ),
      DecisionCompletado.avanzar,
    );
  });

  test('stream truncado se reabre una vez y después avanza', () {
    expect(_decidir(durMs: 200000, posMs: 40000, catalogoMs: 200000),
        DecisionCompletado.reabrirMismo);
    expect(
      _decidir(
        durMs: 200000,
        posMs: 40000,
        catalogoMs: 200000,
        muertoIntentado: true,
      ),
      DecisionCompletado.avanzar,
    );
  });

  test('sin duración y en la posición 0 tras open: evento espurio, se ignora',
      () {
    expect(_decidir(durMs: 0, posMs: 0, msDesdeOpen: 500),
        DecisionCompletado.ignorar);
  });

  test('sin duración y en la posición 0 mucho después: se reabre, no se traba',
      () {
    expect(_decidir(durMs: 0, posMs: 0, msDesdeOpen: 9000),
        DecisionCompletado.reabrirMismo);
    expect(
      _decidir(
        durMs: 0,
        posMs: 0,
        msDesdeOpen: 9000,
        muertoIntentado: true,
      ),
      DecisionCompletado.avanzar,
    );
  });

  test('sin duración pero con audio reproducido: avanza (radio/live)', () {
    expect(_decidir(durMs: 0, posMs: 30000), DecisionCompletado.avanzar);
  });

  test('sin duración y sin saber cuándo abrió: se reabre, nunca se ignora', () {
    expect(_decidir(durMs: 0, posMs: 0, msDesdeOpen: -1),
        DecisionCompletado.reabrirMismo);
  });

  test('ningún caso de cola con más canciones termina en pausa', () {
    // Barrido: ninguna combinación puede devolver "ignorar" cuando ya sonó
    // audio y la duración es desconocida.
    for (final pos in [0, 1, 5000, 60000]) {
      for (final desdeOpen in [0, 100, 4000, 60000]) {
        final d = _decidir(durMs: 0, posMs: pos, msDesdeOpen: desdeOpen);
        if (pos > 0) expect(d, DecisionCompletado.avanzar);
      }
    }
  });
}
