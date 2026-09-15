// ─────────────────────────────────────────────────────────────
// sonda_red.dart — Sonda de red reutilizable: lee el tipo de conexión
// con connectivity_plus y mide la latencia real con un HTTP HEAD
// liviano sobre una conexión keep-alive, clasificándola en niveles.
// Se conecta con: modelo_calidad_red (TipoRed/NivelRed) +
// connectivity_plus + dart:io HttpClient.
// Parte del flujo: Home → barra superior (monitoreo de conexión).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'modelo_calidad_red.dart';

/// Sonda de red: tipo de conexión + latencia real de internet.
class SondaRed {
  /// Tope de la sonda: por encima de esto la red se considera inutilizable.
  static const _timeout = Duration(seconds: 5);

  /// URL neutra y liviana para medir internet real (HEAD, sin rate limit
  /// y sin depender de la infraestructura propia).
  static const _url = 'https://github.com/';

  /// Cliente HTTP propio y reutilizado: la sonda aprovecha la conexión
  /// keep-alive en vez de abrir un socket nuevo cada 15 s.
  HttpClient? _cliente;

  /// Abre el cliente de la sonda (idempotente).
  void iniciar() {
    _cliente ??= HttpClient()..idleTimeout = const Duration(seconds: 20);
  }

  /// Cierra el cliente de la sonda.
  void cerrar() {
    _cliente?.close(force: true);
    _cliente = null;
  }

  /// Lee el tipo de red con connectivity_plus y lo normaliza.
  Future<TipoRed> tipoDeRed() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (res.contains(ConnectivityResult.ethernet)) return TipoRed.ethernet;
      if (res.contains(ConnectivityResult.wifi)) return TipoRed.wifi;
      if (res.contains(ConnectivityResult.mobile)) return TipoRed.movil;
      if (res.contains(ConnectivityResult.vpn)) return TipoRed.otra;
      if (res.any((r) => r != ConnectivityResult.none)) return TipoRed.otra;
      return TipoRed.ninguna;
    } catch (e) {
      // Ante error, asumir que hay red (default seguro).
      return TipoRed.otra;
    }
  }

  /// Sonda HTTP HEAD y devuelve la latencia en ms (-1 si falla o expira).
  Future<int> medirLatencia() async {
    final cliente = _cliente;
    if (cliente == null) return -1;
    final reloj = Stopwatch()..start();
    try {
      final req =
          await cliente.headUrl(Uri.parse(_url)).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      await res.drain<void>();
      reloj.stop();
      return reloj.elapsedMilliseconds;
    } catch (e) {
      reloj.stop();
      return -1;
    }
  }

  /// Traduce la latencia medida a un nivel de calidad.
  static NivelRed clasificar(int latenciaMs) {
    if (latenciaMs < 0) return NivelRed.mala; // Sin respuesta: tratamos lenta.
    if (latenciaMs < 150) return NivelRed.excelente;
    if (latenciaMs < 400) return NivelRed.buena;
    if (latenciaMs < 900) return NivelRed.regular;
    return NivelRed.mala;
  }
}
