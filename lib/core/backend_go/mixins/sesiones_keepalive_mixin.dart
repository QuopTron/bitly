// ─────────────────────────────────────────────────────────────
// sesiones_keepalive_mixin.dart — Provisionamiento al arrancar y
// keepalive en segundo plano de las sesiones firmadas (Cloudflare)
// de las extensiones. Separado de sesiones_firmadas_mixin.dart
// para mantener cada archivo dentro del límite de líneas.
// Se conecta con: backend_go (provisionSignedSessions,
// keepAliveSignedSessions).
// Parte del flujo: verificación de sesiones (Cloudflare).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:logger/logger.dart';

import '../contrato_backend.dart';

final _logKeepalive = Logger();

/// Provisiona y mantiene vivas las sesiones firmadas de las extensiones.
mixin SesionesKeepaliveMixin on BackendService {
  @override
  Future<Map<String, dynamic>> provisionSignedSessions() async {
    try {
      final resultado = await rpcCall('provisionSignedSessions');
      return _decodificarMapaEstado(resultado);
    } catch (e) {
      _logKeepalive.w('[sesiones] provisionSignedSessions error: $e');
      return const {};
    }
  }

  @override
  Future<Map<String, dynamic>> keepAliveSignedSessions() async {
    try {
      final resultado = await rpcCall('keepAliveSignedSessions', null, const Duration(seconds: 10));
      return _decodificarMapaEstado(resultado);
    } catch (e) {
      _logKeepalive.w('[sesiones] keepAliveSignedSessions error: $e');
      return const {};
    }
  }

  /// Decodifica el mapa de estado por fuente devuelto por el backend
  /// (ya sea un Map decodificado o un JSON string).
  Map<String, dynamic> _decodificarMapaEstado(dynamic resultado) {
    if (resultado is Map) {
      return Map<String, dynamic>.from(resultado);
    }
    if (resultado is String && resultado.isNotEmpty) {
      final decodificado = jsonDecode(resultado);
      if (decodificado is Map) return Map<String, dynamic>.from(decodificado);
    }
    return const {};
  }
}