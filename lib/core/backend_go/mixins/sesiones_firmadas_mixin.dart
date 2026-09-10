// ─────────────────────────────────────────────────────────────
// sesiones_firmadas_mixin.dart — Mixin de sesiones firmadas
// (verificación Cloudflare de extensiones): URL de verificación
// pendiente, estado de la sesión (con caché), completar el grant,
// provisionamiento al arrancar y keepalive en segundo plano.
// Se conecta con: backend_go (getPendingVerificationUrl,
// getSignedSessionStatus, completeSignedSessionGrant,
// provisionSignedSessions, keepAliveSignedSessions).
// Parte del flujo: verificación de sesiones (Cloudflare).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:logger/logger.dart';

import '../contrato_backend.dart';
import '../estado_sesion_firmada.dart';

final _logSesiones = Logger();

/// Caché del estado de sesión firmada para no golpear el backend a cada rato.
/// Clave: extensionId, Valor: (estado, timestamp).
final Map<String, (EstadoSesionFirmada, DateTime)> _cacheEstadoFirmado = {};
const _ttlCacheEstadoFirmado = Duration(seconds: 30);

/// Sesiones firmadas: URL de verificación, estado (con caché) y grant.
mixin SesionesFirmadasMixin on BackendService {
  @override
  Future<String> getPendingVerificationUrl(String extensionId) async {
    try {
      final resultado = await rpcCall('getPendingVerificationUrl', {'extension_id': extensionId});
      return _extraerUrlAuth(resultado);
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String> triggerExtensionVerification(String extensionId) async {
    try {
      final resultado = await rpcCall('triggerExtensionVerification', {'extension_id': extensionId});
      return _extraerUrlAuth(resultado);
    } catch (_) {
      return '';
    }
  }

  /// Extrae auth_url de la respuesta de sesión firmada de Go. Devuelve ''
  /// cuando la extensión no necesita verificación (no cargada, sin
  /// signedSession configurado, sesión sana). Lanza cuando la extensión la
  /// necesita pero la URL no se pudo obtener (p.ej. fallo de red en bootstrap).
  String _extraerUrlAuth(dynamic resultado) {
    Map<String, dynamic>? mapa;
    if (resultado is Map) {
      mapa = resultado.cast<String, dynamic>();
    } else if (resultado is String && resultado.isNotEmpty) {
      final decodificado = jsonDecode(resultado);
      if (decodificado is Map) mapa = decodificado.cast<String, dynamic>();
    }
    if (mapa == null) return '';
    // Errores que significan "no se necesita verificación" → devolver ''.
    final error = mapa['error'] as String?;
    if (error != null) {
      final lower = error.toLowerCase();
      if (lower.contains('not configured') || lower.contains('no cargada')) {
        return ''; // la extensión no tiene soporte de sesión firmada
      }
      // Otros errores (bootstrap, red, etc.) → lanzar para que el llamador
      // muestre la verificación como "fallida" y pueda reintentar.
      throw Exception(error);
    }
    return mapa['auth_url'] as String? ?? '';
  }

  @override
  Future<EstadoSesionFirmada> getSignedSessionStatus(String extensionId) async {
    // Devuelve el caché si sigue fresco (evita golpear el backend).
    final cacheado = _cacheEstadoFirmado[extensionId];
    if (cacheado != null && DateTime.now().difference(cacheado.$2) < _ttlCacheEstadoFirmado) {
      return cacheado.$1;
    }
    try {
      final resultado = await rpcCall('getSignedSessionStatus', {'extension_id': extensionId}, const Duration(seconds: 10));
      EstadoSesionFirmada estado;
      if (resultado is Map) {
        estado = EstadoSesionFirmada.desdeJson(Map<String, dynamic>.from(resultado));
      } else if (resultado is String && resultado.isNotEmpty) {
        final decodificado = jsonDecode(resultado);
        estado = (decodificado is Map)
            ? EstadoSesionFirmada.desdeJson(Map<String, dynamic>.from(decodificado))
            : const EstadoSesionFirmada();
      } else {
        estado = const EstadoSesionFirmada();
      }
      _cacheEstadoFirmado[extensionId] = (estado, DateTime.now());
      return estado;
    } catch (e) {
      _logSesiones.w('[sesiones] getSignedSessionStatus error para $extensionId: $e');
      return const EstadoSesionFirmada();
    }
  }

  // ── Acciones de extensión + grant (sesiones_acciones_mixin.dart) ──
  // ── Provisionamiento y keepalive (sesiones_keepalive_mixin.dart) ──
}