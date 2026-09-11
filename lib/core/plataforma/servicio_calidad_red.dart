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
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Tipo de conexión activa, ya normalizado para la UI.
enum TipoRed { wifi, movil, ethernet, otra, ninguna }

/// Nivel de calidad medido. El orden importa: se comparan con `index`.
enum NivelRed { desconocido, mala, regular, buena, excelente }

/// Estado inmutable que expone el servicio (para ValueNotifier).
class EstadoCalidadRed {
  /// Nivel de calidad medido.
  final NivelRed nivel;

  /// Tipo de conexión detectado.
  final TipoRed tipo;

  /// Latencia de la sonda en ms (-1 = todavía sin dato).
  final int latenciaMs;

  /// True mientras hay una medición en curso y aún no hay dato previo.
  final bool midiendo;

  const EstadoCalidadRed({
    required this.nivel,
    required this.tipo,
    required this.latenciaMs,
    this.midiendo = false,
  });

  /// Estado inicial: aún sin medir.
  static const inicial = EstadoCalidadRed(
    nivel: NivelRed.desconocido,
    tipo: TipoRed.ninguna,
    latenciaMs: -1,
    midiendo: true,
  );

  /// True cuando hay conexión (cualquier nivel por encima de "sin red").
  bool get hayConexion => nivel != NivelRed.desconocido || tipo != TipoRed.ninguna;

  /// Copia con los campos indicados reemplazados.
  EstadoCalidadRed copiarCon({NivelRed? nivel, TipoRed? tipo, int? latenciaMs, bool? midiendo}) {
    return EstadoCalidadRed(
      nivel: nivel ?? this.nivel,
      tipo: tipo ?? this.tipo,
      latenciaMs: latenciaMs ?? this.latenciaMs,
      midiendo: midiendo ?? this.midiendo,
    );
  }
}

/// Medidor de calidad de red (singleton, sin dependencias del backend).
class ServicioCalidadRed {
  ServicioCalidadRed._();

  /// Instancia única (no depende de GetIt para poder arrancar temprano).
  static final ServicioCalidadRed instancia = ServicioCalidadRed._();

  /// Cada cuánto se vuelve a medir mientras la app está en primer plano.
  static const _intervalo = Duration(seconds: 15);

  /// Tope de la sonda: por encima de esto la red se considera inutilizable.
  static const _timeoutSonda = Duration(seconds: 5);

  /// URL neutra y liviana para medir internet real (HEAD, sin rate limit
  /// y sin depender de la infraestructura propia).
  static const _urlSonda = 'https://github.com/';

  /// Estado observable por la UI y por las precargas.
  final ValueNotifier<EstadoCalidadRed> estado =
      ValueNotifier<EstadoCalidadRed>(EstadoCalidadRed.inicial);

  /// Cliente HTTP propio y reutilizado: la sonda aprovecha la conexión
  /// keep-alive en vez de abrir un socket nuevo cada 15 s.
  HttpClient? _cliente;
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
    _cliente = HttpClient()..idleTimeout = const Duration(seconds: 20);
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
    _cliente?.close(force: true);
    _cliente = null;
  }

  /// Fuerza una medición inmediata (p. ej. al abrir la hoja de detalle).
  Future<void> medirAhora() async {
    if (_midiendo) return;
    _midiendo = true;
    try {
      final tipo = await _tipoDeRed();
      if (tipo == TipoRed.ninguna) {
        estado.value = estado.value.copiarCon(
          nivel: NivelRed.mala,
          tipo: TipoRed.ninguna,
          latenciaMs: -1,
          midiendo: false,
        );
        return;
      }
      final latencia = await _medirLatencia();
      estado.value = EstadoCalidadRed(
        nivel: _clasificar(latencia),
        tipo: tipo,
        latenciaMs: latencia,
        midiendo: false,
      );
    } finally {
      _midiendo = false;
    }
  }

  /// Lee el tipo de red con connectivity_plus y lo normaliza.
  Future<TipoRed> _tipoDeRed() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (res.contains(ConnectivityResult.ethernet)) return TipoRed.ethernet;
      if (res.contains(ConnectivityResult.wifi)) return TipoRed.wifi;
      if (res.contains(ConnectivityResult.mobile)) return TipoRed.movil;
      if (res.contains(ConnectivityResult.vpn)) return TipoRed.otra;
      if (res.any((r) => r != ConnectivityResult.none)) return TipoRed.otra;
      return TipoRed.ninguna;
    } catch (_) {
      return TipoRed.otra; // Ante error, asumir que hay red (default seguro).
    }
  }

  /// Sonda HTTP HEAD y devuelve la latencia en ms (-1 si falla o expira).
  Future<int> _medirLatencia() async {
    final cliente = _cliente;
    if (cliente == null) return -1;
    final reloj = Stopwatch()..start();
    try {
      final req = await cliente
          .headUrl(Uri.parse(_urlSonda))
          .timeout(_timeoutSonda);
      final res = await req.close().timeout(_timeoutSonda);
      await res.drain<void>();
      reloj.stop();
      return reloj.elapsedMilliseconds;
    } catch (_) {
      reloj.stop();
      return -1;
    }
  }

  /// Traduce la latencia medida a un nivel de calidad.
  static NivelRed _clasificar(int latenciaMs) {
    if (latenciaMs < 0) return NivelRed.mala; // Sin respuesta: tratamos lenta.
    if (latenciaMs < 150) return NivelRed.excelente;
    if (latenciaMs < 400) return NivelRed.buena;
    if (latenciaMs < 900) return NivelRed.regular;
    return NivelRed.mala;
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
