// ─────────────────────────────────────────────────────────────
// monitor_frames_test.dart — Fija la lógica del monitor adaptativo:
// que decide por MEDIANA (no por un frame malo), que exige superar el
// presupuesto con tolerancia, y que los dos niveles de degradación
// apagan lo que prometen en EfectosApp.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/plataforma/sistema/base/monitor_frames.dart';
import 'package:bitly/shared/utilidades/plataforma/pantalla/efectos_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    EfectosApp.reiniciar();
    MonitorFrames.instancia.reiniciarNivel();
  });

  tearDown(() {
    EfectosApp.reiniciar();
    MonitorFrames.instancia.reiniciarNivel();
  });

  test('la mediana no la mueve un frame malo suelto', () {
    // 49 frames perfectos y 1 de 400 ms: la mediana sigue siendo ~16 ms.
    final muestras = <double>[
      ...List<double>.filled(49, 16.0),
      400.0,
    ];
    expect(MonitorFrames.medianaDe(muestras), 16.0);
  });

  test('la mediana de una lista par e impar es estable', () {
    expect(MonitorFrames.medianaDe(const [1, 2, 3]), 2);
    expect(MonitorFrames.medianaDe(const [1, 2, 3, 4]), 3);
    expect(MonitorFrames.medianaDe(const []), 0);
  });

  test('el presupuesto sale de la tasa de refresco real', () {
    final monitor = MonitorFrames.instancia;
    // En el entorno de test la tasa puede ser 60 o la del host; el rango
    // válido es 30..240 Hz, así que el presupuesto cae entre 4 y 33 ms.
    expect(monitor.presupuestoMs, greaterThan(3));
    expect(monitor.presupuestoMs, lessThanOrEqualTo(1000 / 30));
  });

  test('superaPresupuesto exige la tolerancia, no un pico puntual', () {
    final monitor = MonitorFrames.instancia;
    final presupuesto = monitor.presupuestoMs;
    // Al límite: no degrada.
    expect(monitor.superaPresupuesto(presupuesto), isFalse);
    // Muy por encima: degrada.
    expect(monitor.superaPresupuesto(presupuesto * 3), isTrue);
  });

  test('reiniciarNivel deja los efectos en su estado permisivo', () {
    final monitor = MonitorFrames.instancia;
    expect(monitor.nivel, 0);
    // El nivel 0 no toca los interruptores: siguen permisivos.
    expect(EfectosApp.permitirDesenfoque.value, isTrue);
    expect(EfectosApp.colorPorTarjetaActivo, isTrue);
  });

  test('efectosMinimos apaga el color por tarjeta y reiniciar lo repone', () {
    expect(EfectosApp.colorPorTarjetaActivo, isTrue);
    EfectosApp.efectosMinimos.value = true;
    expect(EfectosApp.colorPorTarjetaActivo, isFalse);
    // El desenfoque es un interruptor distinto: no se toca solo.
    expect(EfectosApp.permitirDesenfoque.value, isTrue);
    EfectosApp.reiniciar();
    expect(EfectosApp.colorPorTarjetaActivo, isTrue);
  });

  test('aplicar() respeta el perfil y desenfoqueActivo combina las dos señales', () {
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
    expect(EfectosApp.desenfoqueActivo, isFalse);
    EfectosApp.aplicar(efectosPesados: true, sigmaMax: 26);
    expect(EfectosApp.desenfoqueActivo, isTrue);
    // Perfil permite, pero el monitor bajó el sigma a 0: no hay desenfoque.
    EfectosApp.aplicar(efectosPesados: true, sigmaMax: 0);
    expect(EfectosApp.desenfoqueActivo, isFalse);
  });

  testWidgets('iniciar() y detener() son idempotentes', (tester) async {
    final monitor = MonitorFrames.instancia;
    monitor.iniciar();
    monitor.iniciar();
    monitor.detener();
    monitor.detener();
    // Sin excepciones: el listener no quedó duplicado ni tiró al quitarse.
    await tester.pump(const Duration(milliseconds: 16));
  });
}
