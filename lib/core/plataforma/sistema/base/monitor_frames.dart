// ─────────────────────────────────────────────────────────────
// monitor_frames.dart — Adaptación EN VIVO al chip real.
//
// Por qué existe: el perfil de rendimiento se decide UNA vez, al arrancar, a
// partir de núcleos y RAM. Eso acierta en los extremos (un Helio G o un
// escritorio con RTX) pero se equivoca en el medio: hay equipos con muchos
// núcleos y una GPU floja, otros con poca RAM y buena GPU, emuladores,
// celulares con el gobernador térmico ya bajado, y equipos donde otra app se
// está comiendo la GPU. En todos esos casos el perfil dice "hay margen" y la
// app va a tirones sin que nadie lo note.
//
// Este monitor escucha los tiempos REALES de frame del motor
// (`addTimingsCallback`) y, si de forma SOSTENIDA no se llega al ritmo de la
// pantalla, apaga efectos por niveles:
//
//   nivel 1 → sin desenfoques (blur, partículas, pulsos, esqueletos animados)
//   nivel 2 → además, sin extracción de color por tarjeta (el trabajo que más
//             escala con la cantidad de items en pantalla)
//
// Reglas para no degradar por un hipo puntual: se exige una ventana completa de
// frames con la MEDIANA por encima del presupuesto (una mediana no la mueve un
// frame malo), un arranque ya terminado, y un enfriamiento entre rebajas.
//
// Se conecta con: efectos_app (el interruptor que leen los widgets) y main
// (arranque). Parte del flujo: rendimiento (adaptación al equipo).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../../shared/utilidades/plataforma/pantalla/efectos_app.dart';

class MonitorFrames {
  MonitorFrames._();

  static final MonitorFrames instancia = MonitorFrames._();

  /// Frames que se acumulan antes de juzgar. Con 60 Hz son ~1,5 s: suficiente
  /// para que la mediana represente la pantalla y no un cambio de vista.
  static const int _ventanaFrames = 90;

  /// Presupuesto de frame (ms) tolerado. Se calcula de la tasa de refresco;
  /// con 60 Hz son 16,7 ms y se degrada cuando la mediana pasa de ~1,6× eso
  /// (≈ 26 ms, o sea por debajo de 40 fps sostenidos).
  static const double _factorTolerancia = 1.6;

  /// Tiempo de gracia desde el arranque: el primer pintado, la apertura de
  /// base de datos y la primera carga de red siempre cuestan más.
  static const Duration _graciaArranque = Duration(seconds: 4);

  /// Enfriamiento entre rebajas: no se baja dos niveles de golpe porque una
  /// pantalla pesada (una lista enorme) coincida con otra cosa.
  static const Duration _enfriamiento = Duration(seconds: 6);

  bool _activo = false;
  int _nivel = 0;
  int _framesAcumulados = 0;
  final List<double> _muestras = <double>[];
  DateTime? _arranque;
  DateTime? _ultimaRebaja;

  /// Nivel de degradación aplicado (0 = efectos completos). Expuesto para
  /// diagnóstico y tests.
  int get nivel => _nivel;

  /// Empieza a medir. Idempotente: llamarlo dos veces no duplica el listener.
  void iniciar() {
    if (_activo) return;
    _activo = true;
    _arranque = DateTime.now();
    try {
      SchedulerBinding.instance.addTimingsCallback(_alTerminarFrame);
    } catch (e) {
      // Sin planificador no hay medición: la app sigue con el perfil estático.
      debugPrint('[MonitorFrames] no se pudo iniciar: $e');
    }
  }

  /// Detiene la medición (tests).
  @visibleForTesting
  void detener() {
    if (!_activo) return;
    _activo = false;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_alTerminarFrame);
    } catch (_) {}
  }

  @visibleForTesting
  void reiniciarNivel() {
    _nivel = 0;
    _framesAcumulados = 0;
    _muestras.clear();
    _ultimaRebaja = null;
    _arranque = DateTime.now();
  }

  void _alTerminarFrame(List<FrameTiming> tiempos) {
    if (!_activo) return;

    final ahora = DateTime.now();
    final inicio = _arranque;
    if (inicio == null || ahora.difference(inicio) < _graciaArranque) return;

    for (final t in tiempos) {
      // `totalSpan` es el tiempo de pared del frame completo (build + raster +
      // espera). Es lo que percibe el usuario, que es lo que estamos midiendo.
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      // Descartas frames absurdos (reanudar la app, cambio de orientación,
      // primer frame tras volver de segundo plano): no son coste sostenido.
      if (ms <= 0 || ms > 500) continue;
      _muestras.add(ms);
    }
    _framesAcumulados += tiempos.length;
    if (_framesAcumulados < _ventanaFrames) return;
    _framesAcumulados = 0;

    final presupuesto = _presupuestoMs();
    if (_muestras.isEmpty) return;

    // Mediana: un frame malo entre cincuenta no degrada la experiencia, así que
    // no debe decidir la rebaja.
    final ordenadas = List<double>.of(_muestras)..sort();
    final mediana = ordenadas[ordenadas.length ~/ 2];
    _muestras.clear();

    if (mediana <= presupuesto * _factorTolerancia) return;

    final ultima = _ultimaRebaja;
    if (ultima != null && ahora.difference(ultima) < _enfriamiento) return;

    _rebajar();
    _ultimaRebaja = ahora;
  }

  /// Presupuesto de frame en ms según la tasa de refresco real de la pantalla
  /// (90/120 Hz tienen menos margen por frame que 60 Hz).
  double _presupuestoMs() {
    var hz = 60.0;
    try {
      final vista = PlatformDispatcher.instance.implicitView;
      final tasa = vista?.display.refreshRate ?? 0;
      if (tasa.isFinite && tasa >= 30 && tasa <= 240) hz = tasa;
    } catch (_) {
      // Sin dato de pantalla se asume 60 Hz, el caso más común.
    }
    return 1000.0 / hz;
  }

  /// Baja un nivel de efectos. Nunca sube de vuelta: el objetivo es que la app
  /// quede fluida, y volver a encender efectos por una racha buena haría que el
  /// usuario viera el tirón dos veces.
  void _rebajar() {
    if (_nivel >= 2) return;
    _nivel++;
    debugPrint('[MonitorFrames] ritmo insuficiente → nivel $_nivel');
    switch (_nivel) {
      case 1:
        // Sin desenfoques: es el peso de GPU más caro que queda.
        EfectosApp.aplicar(efectosPesados: false, sigmaMax: 0);
      default:
        // Además, sin trabajo de color por tarjeta (paleta de cada cover),
        // que es lo que más escala con la cantidad de items en pantalla.
        EfectosApp.efectosMinimos.value = true;
    }
  }

  /// Utilidad para pruebas: mediana de una lista de muestras.
  @visibleForTesting
  static double medianaDe(List<double> muestras) {
    if (muestras.isEmpty) return 0;
    final ordenadas = List<double>.of(muestras)..sort();
    return ordenadas[ordenadas.length ~/ 2];
  }

  /// Presupuesto efectivo para diagnóstico.
  @visibleForTesting
  double get presupuestoMs => _presupuestoMs();

  /// Compara contra el presupuesto con la tolerancia aplicada.
  @visibleForTesting
  bool superaPresupuesto(double medianaMs) =>
      medianaMs > _presupuestoMs() * _factorTolerancia;

  /// Media de una lista (para tests de sanidad).
  @visibleForTesting
  static double mediaDe(List<double> muestras) =>
      muestras.isEmpty
          ? 0
          : muestras.reduce((a, b) => a + b) / math.max(1, muestras.length);
}
