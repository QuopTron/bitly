// ─────────────────────────────────────────────────────────────
// servicio_conectividad.dart — Verificador ligero de conectividad
// usando connectivity_plus. Devuelve true cuando el dispositivo
// tiene alguna red activa (WiFi, móvil, ethernet).
// Se conecta con: plugin connectivity_plus + player/descargas.
// Parte del flujo: reproducción local-first (decidir online/offline).
// ─────────────────────────────────────────────────────────────

import 'package:connectivity_plus/connectivity_plus.dart';

/// Verificador de conectividad.
class ServicioConectividad {
  static final Connectivity _conectividad = Connectivity();

  /// Devuelve true si el dispositivo parece tener acceso a internet.
  static Future<bool> estaEnLinea() async {
    try {
      final resultados = await _conectividad.checkConnectivity();
      return resultados.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Asumir online ante error (default seguro)
    }
  }
}