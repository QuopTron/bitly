// ─────────────────────────────────────────────────────────────
// monitor_frames_test.dart — Fija la lógica del monitor adaptativo:
// que NO degrada por un frame malo suelto (mediana, percentil 90 y
// proporción de frames tardíos), y que los dos niveles de degradación
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

  group('ritmoInsuficiente (la regla de decisión)', () {
    // 60 Hz: el presupuesto son 16,67 ms.
    const presupuesto = 1000 / 60;

    test('una app que llega al ritmo no degrada', () {
      final muestras = List<double>.filled(90, 12.0);
      expect(MonitorFrames.ritmoInsuficiente(muestras, presupuesto), isFalse);
    });

    test('unos pocos frames malos sueltos no degradan', () {
      // 87 frames bien y 3 de 100 ms: es el hipo de una notificación.
      final muestras = <double>[
        ...List<double>.filled(87, 16.0),
        ...List<double>.filled(3, 100.0),
      ];
      expect(MonitorFrames.ritmoInsuficiente(muestras, presupuesto), isFalse);
    });

    test('lento parejo lo caza la mediana', () {
      final muestras = List<double>.filled(90, 40.0);
      expect(MonitorFrames.ritmoInsuficiente(muestras, presupuesto), isTrue);
    });

    test('caídas grandes lo caza el percentil 90', () {
      // Mediana 10 ms (parece sano) y 15% de frames de 50 ms: uno de cada
      // siete se pierde, y eso se ve en el desplazamiento.
      final muestras = <double>[
        ...List<double>.filled(85, 10.0),
        ...List<double>.filled(15, 50.0),
      ];
      expect(MonitorFrames.ritmoInsuficiente(muestras, presupuesto), isTrue);
    });

    test('la mitad de frames pasados degrada aunque la mediana llegue', () {
      // Este es el caso medido en el Unisoc con PowerVR GE8322: la mediana
      // llega (15 ms) y el p90 queda justo en el umbral (33 ms), pero el 45%
      // de los frames se pasa del presupuesto. Sin esta mirada, la app se
      // desplazaba a tirones y el monitor no bajaba nada.
      final muestras = <double>[
        ...List<double>.filled(55, 15.0),
        ...List<double>.filled(45, 33.0),
      ];
      expect(MonitorFrames.medianaDe(muestras), lessThanOrEqualTo(20.0));
      expect(
        MonitorFrames.ritmoInsuficiente(muestras, presupuesto),
        isTrue,
        reason: 'el 45% de frames tardíos debe bastar por sí solo',
      );
    });

    test('justo por debajo del umbral de proporción no degrada', () {
      // 35% de frames tardíos: por debajo del 40%, se tolera (evita el
      // parpadeo de encender y apagar efectos con cada ventana).
      final muestras = <double>[
        ...List<double>.filled(65, 15.0),
        ...List<double>.filled(35, 33.0),
      ];
      expect(MonitorFrames.ritmoInsuficiente(muestras, presupuesto), isFalse);
    });

    test('sin muestras o sin presupuesto no decide nada', () {
      expect(MonitorFrames.ritmoInsuficiente(const [], presupuesto), isFalse);
      expect(MonitorFrames.ritmoInsuficiente(const [50.0], 0), isFalse);
    });
  });

  test('la mediana no la mueve un frame malo suelto', () {
    // 49 frames perfectos y 1 de 400 ms: la mediana sigue siendo ~16 ms.
    final muestras = <double>[...List<double>.filled(49, 16.0), 400.0];
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

  test('el tercer escalón suelta las fotos a pantalla completa', () {
    // Nivel 1: sin desenfoques. Nivel 2: además, sin color por tarjeta.
    EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
    EfectosApp.efectosMinimos.value = true;
    expect(
      EfectosApp.fotoPantallaCompletaActiva,
      isTrue,
      reason: 'los dos primeros escalones no tocan las fotos',
    );

    // Nivel 3: y si todavía no llega, la textura más cara por frame.
    EfectosApp.fotosApagadasPorMonitor.value = true;
    expect(EfectosApp.fotoPantallaCompletaActiva, isFalse);

    EfectosApp.reiniciar();
    expect(EfectosApp.fotoPantallaCompletaActiva, isTrue);
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

  test(
    'aplicar() respeta el perfil y desenfoqueActivo combina las dos señales',
    () {
      EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
      expect(EfectosApp.desenfoqueActivo, isFalse);
      EfectosApp.aplicar(efectosPesados: true, sigmaMax: 26);
      expect(EfectosApp.desenfoqueActivo, isTrue);
      // Perfil permite, pero el monitor bajó el sigma a 0: no hay desenfoque.
      EfectosApp.aplicar(efectosPesados: true, sigmaMax: 0);
      expect(EfectosApp.desenfoqueActivo, isFalse);
    },
  );

  group('ventanas de degradación y recuperación', () {
    // Una ventana "mala": el doble del presupuesto, o sea por debajo de 40 fps.
    List<double> ventanaMala(double presupuesto) =>
        List<double>.filled(90, presupuesto * 2);

    // Una ventana "holgada": la mitad del presupuesto y sin picos.
    List<double> ventanaHolgada(double presupuesto) =>
        List<double>.filled(90, presupuesto * 0.5);

    // Ventana de REPOSO: la app quieta dibuja pocos frames y casi todos sin
    // trabajo. La mediana es bajísima (parecería "holgada") pero no dice nada.
    List<double> ventanaReposo() => <double>[
      ...List<double>.filled(8, 30),
      ...List<double>.filled(82, 1),
    ];

    test('framesConTrabajo ignora los frames de reposo', () {
      expect(MonitorFrames.framesConTrabajo(ventanaReposo()), 8);
      expect(MonitorFrames.framesConTrabajo(List.filled(90, 10.0)), 90);
      expect(MonitorFrames.framesConTrabajo(const []), 0);
    });

    test('ritmoHolgado exige margen, no ir raspando el umbral', () {
      const p = 16.7;
      expect(MonitorFrames.ritmoHolgado(List.filled(90, p * 0.5), p), isTrue);
      // Justo por debajo del umbral de "lento" pero sin margen: no alcanza.
      expect(MonitorFrames.ritmoHolgado(List.filled(90, p * 1.2), p), isFalse);
      // Mediana con margen, pero con picos de frame perdido: tampoco alcanza.
      expect(
        MonitorFrames.ritmoHolgado(<double>[
          ...List<double>.filled(80, p * 0.4),
          ...List<double>.filled(10, p * 3),
        ], p),
        isFalse,
      );
      expect(MonitorFrames.ritmoHolgado(const [], p), isFalse);
    });

    test('UNA ventana mala no degrada: el mal ritmo tiene que sostenerse', () {
      final monitor = MonitorFrames.instancia;
      EfectosApp.reiniciar();
      monitor.reiniciarNivel();
      final p = monitor.presupuestoMs;
      var ahora = DateTime.now();

      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      expect(
        monitor.nivel,
        0,
        reason: 'un hipo puntual no puede apagar efectos para toda la sesión',
      );

      // La segunda ventana mala seguida sí lo hace.
      ahora = ahora.add(const Duration(seconds: 8));
      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      expect(monitor.nivel, 1);
      expect(EfectosApp.permitirDesenfoque.value, isFalse);
    });

    test('una ventana de reposo no juzga nada (ni baja ni sube)', () {
      final monitor = MonitorFrames.instancia;
      EfectosApp.reiniciar();
      monitor.reiniciarNivel();
      final p = monitor.presupuestoMs;
      var ahora = DateTime.now();

      // Dos malas y baja.
      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      ahora = ahora.add(const Duration(seconds: 8));
      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      expect(monitor.nivel, 1);

      // Y ahora reposo puro: aunque la mediana sea mínima, no recupera porque
      // no hubo trabajo real que demuestre holgura.
      for (var i = 0; i < 5; i++) {
        ahora = ahora.add(const Duration(seconds: 30));
        monitor.decidirVentanaParaPruebas(ventanaReposo(), ahora);
      }
      expect(
        monitor.nivel,
        1,
        reason: 'la app en reposo no demuestra que el equipo pueda con todo',
      );
    });

    test('el nivel vuelve solo cuando la holgura se sostiene', () {
      final monitor = MonitorFrames.instancia;
      // Perfil de arranque conocido: hay que restaurar ESTOS valores.
      EfectosApp.reiniciar();
      EfectosApp.aplicar(efectosPesados: true, sigmaMax: 24);
      monitor.reiniciarNivel();
      final p = monitor.presupuestoMs;
      var ahora = DateTime.now();

      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      ahora = ahora.add(const Duration(seconds: 8));
      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      expect(monitor.nivel, 1);
      expect(EfectosApp.sigmaMaximo.value, 0);

      // Holgura sostenida, con la espera posterior a la rebaja cumplida.
      for (var i = 0; i < 4; i++) {
        ahora = ahora.add(const Duration(seconds: 30));
        monitor.decidirVentanaParaPruebas(ventanaHolgada(p), ahora);
      }
      expect(monitor.nivel, 0, reason: 'el equipo demostró holgura de sobra');
      expect(
        EfectosApp.sigmaMaximo.value,
        24,
        reason: 'se restauran los valores del perfil, no unos de fábrica',
      );
      expect(EfectosApp.permitirDesenfoque.value, isTrue);
    });

    test('no recupera antes de la espera posterior a la rebaja', () {
      final monitor = MonitorFrames.instancia;
      EfectosApp.reiniciar();
      monitor.reiniciarNivel();
      final p = monitor.presupuestoMs;
      var ahora = DateTime.now();

      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      ahora = ahora.add(const Duration(seconds: 8));
      monitor.decidirVentanaParaPruebas(ventanaMala(p), ahora);
      expect(monitor.nivel, 1);

      // Ventanas holgadas, pero pegadas a la rebaja: los efectos están
      // apagados y el equipo se ve mejor justo por eso, así que no se devuelve.
      for (var i = 0; i < 5; i++) {
        ahora = ahora.add(const Duration(seconds: 3));
        monitor.decidirVentanaParaPruebas(ventanaHolgada(p), ahora);
      }
      expect(monitor.nivel, 1);
    });
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
