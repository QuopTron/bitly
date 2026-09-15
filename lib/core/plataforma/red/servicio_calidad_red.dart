// ─────────────────────────────────────────────────────────────
// servicio_calidad_red.dart — Medidor de calidad de red de la app.
// Cada 15 s (y en cada cambio de conectividad) hace una sonda HTTP
// liviana para medir la latencia REAL de internet, lee el tipo de
// conexión con connectivity_plus y clasifica el resultado en niveles
// (excelente / buena / regular / lenta / sin red). El indicador de la
// barra superior lo muestra y las precargas lo usan para decidir
// cuántos tracks resolver de fondo.
// Se conecta con: connectivity_plus (tipo de red) + dart:io HttpClient
// (sonda reutilizando la conexión) + shared/widgets/indicador_red.dart
// + estado/reproductor_preload.dart (precargas adaptativas).
// Parte del flujo: Home → barra superior (monitoreo de conexión).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'modelo_calidad_red.dart';
import 'sonda_red.dart';
export 'modelo_calidad_red.dart';

/// Medidor de calidad de red (singleton, sin dependencias del backend).
class ServicioCalidadRed {
  ServicioCalidadRed._();

  /// Instancia única (no depende de GetIt para poder arrancar temprano).
  static final ServicioCalidadRed instancia = ServicioCalidadRed._();

  /// Cada cuánto se vuelve a medir mientras la app está en primer plano.
  static const _intervalo = Duration(seconds: 15);

  /// Estado observable por la UI y por las precargas.
  final ValueNotifier<EstadoCalidadRed> estado =
      ValueNotifier<EstadoCalidadRed>(EstadoCalidadRed.inicial);

  /// Sonda de latencia y tipo de red (cliente HTTP keep-alive adentro).
  final SondaRed _sonda = SondaRed();
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _subConectividad;
  _ObservadorCiclo? _observadorCiclo;
  bool _iniciado = false;
  bool _midiendo = false;
  bool _enPrimerPlano = true;

  /// True si la red medida alcanza para precargar de forma especulativa.
  bool get redAptaParaPrecarga =>
      estado.value.nivel == NivelRed.buena || estado.value.nivel == NivelRed.excelente;

  /// True si la conexión es fija (WiFi/Ethernet) — úsese para precargas
  /// agresivas cuando además la latencia es buena.
  bool get redFija =>
      estado.value.tipo == TipoRed.wifi || estado.value.tipo == TipoRed.ethernet;

  /// Arranca el monitoreo: primera medición inmediata + timer + escucha de
  /// cambios de conectividad. Idempotente.
  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    _sonda.iniciar();
    _observadorCiclo = _ObservadorCiclo(this);
    WidgetsBinding.instance.addObserver(_observadorCiclo!);
    _timer = Timer.periodic(_intervalo, (_) => medirAhora());
    try {
      _subConectividad = Connectivity().onConnectivityChanged.listen((_) => medirAhora());
    } catch (_) {
      // Sin observador de conectividad igual se mide por timer.
    }
    unawaited(medirAhora());
  }

  /// Detiene el monitoreo y libera la conexión de la sonda.
  void detener() {
    _iniciado = false;
    _timer?.cancel();
    _timer = null;
    _subConectividad?.cancel();
    _subConectividad = null;
    if (_observadorCiclo != null) {
      WidgetsBinding.instance.removeObserver(_observadorCiclo!);
      _observadorCiclo = null;
    }
    _sonda.cerrar();
  }

  /// Fuerza una medición inmediata (p. ej. al abrir la hoja de detalle).
  Future<void> medirAhora() async {
    if (_midiendo) return;
    _midiendo = true;
    try {
      final tipo = await _sonda.tipoDeRed();
      if (tipo == TipoRed.ninguna) {
        estado.value = estado.value.copiarCon(
          nivel: NivelRed.mala,
          tipo: TipoRed.ninguna,
          latenciaMs: -1,
          midiendo: false,
        );
        return;
      }
      final latencia = await _sonda.medirLatencia();
      estado.value = EstadoCalidadRed(
        nivel: SondaRed.clasificar(latencia),
        tipo: tipo,
        latenciaMs: latencia,
        midiendo: false,
      );
    } finally {
      _midiendo = false;
    }
  }

  /// Pausa el timer cuando la app queda en segundo plano y lo retoma al
  /// volver: no tiene sentido sondear con la app cerrada (y gasta batería).
  void _alCambiarCiclo(bool enPrimerPlano) {
    if (_enPrimerPlano == enPrimerPlano) return;
    _enPrimerPlano = enPrimerPlano;
    if (enPrimerPlano) {
      _timer ??= Timer.periodic(_intervalo, (_) => medirAhora());
      unawaited(medirAhora());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Observador de ciclo de vida que pausa/reanuda el sondeo.
class _ObservadorCiclo with WidgetsBindingObserver {
  final ServicioCalidadRed servicio;
  _ObservadorCiclo(this.servicio);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    servicio._alCambiarCiclo(state == AppLifecycleState.resumed);
  }
}
