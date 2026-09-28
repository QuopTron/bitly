// ─────────────────────────────────────────────────────────────
// servicio_fuentes_test.dart — La regla que hace segura esta función: una
// tipografía que no se puede bajar NUNCA deja la app sin tipografía. Se vuelve
// a la empaquetada y se informa el estado, en vez de quedar "elegida pero
// invisible" (que es peor que un error, porque no se distingue de funcionar).
// Parte del flujo: arranque y Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/fuentes/catalogo_fuentes.dart';
import 'package:bitly/core/servicios/fuentes/servicio_fuentes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `GetIt.reset()` es ASÍNCRONO: sin el `await`, el reset pendiente termina
  // después del `registerSingleton` y se lleva puesto el registro (el test
  // falla con "type ValueNotifier<String?> is not registered" apenas hay un
  // await de por medio, que es justo lo que hace este servicio).
  setUp(() async {
    await di.sl.reset();
    di.sl.registerSingleton<ValueNotifier<String?>>(
      ValueNotifier<String?>(null),
    );
  });

  tearDown(() => di.sl.reset());

  test('la tipografía de la app se publica y no toca la red', () async {
    await ServicioFuentes.instancia.activar('');

    expect(ServicioFuentes.instancia.familia.value, 'Google Sans Flex');
    expect(ServicioFuentes.estado.value, EstadoFuente.empaquetada);
  });

  test('un id que ya no existe cae a la de la app, sin romper', () async {
    // `forzar` porque el servicio recuerda la última activada y este id
    // resuelve a la MISMA tipografía (la de la app): sin forzar sería un
    // no-op y el test no probaría nada.
    await ServicioFuentes.instancia.activar(
      'fuente_que_ya_no_esta',
      forzar: true,
    );

    expect(ServicioFuentes.instancia.familia.value, fuenteEmpaquetada.familia);
    expect(ServicioFuentes.estado.value, EstadoFuente.empaquetada);
  });

  // En este entorno no hay BackendService registrado, que es EXACTAMENTE lo que
  // pasa cuando el binario nativo todavía no se recompiló con el RPC nuevo (o
  // cuando no hay red): el servicio tiene que aguantar y degradar.
  test('si la bajada falla, queda la de la app y se informa el error', () async {
    await ServicioFuentes.instancia.activar('inter', forzar: true);

    expect(ServicioFuentes.instancia.familia.value, fuenteEmpaquetada.familia);
    expect(ServicioFuentes.estado.value, EstadoFuente.error);
  });

  test('reintentar vuelve a intentar aunque ya esté elegida', () async {
    ServicioFuentes.estado.value = EstadoFuente.sinRed;

    await ServicioFuentes.instancia.reintentar('rubik');

    // Volvió a correr el intento (y falló igual, que es lo esperado acá).
    expect(ServicioFuentes.estado.value, EstadoFuente.error);
    expect(ServicioFuentes.instancia.familia.value, fuenteEmpaquetada.familia);
  });

  test('liberar sin backend no explota', () async {
    await expectLater(
      ServicioFuentes.instancia.liberarDescargadas(),
      completes,
    );
  });
}
