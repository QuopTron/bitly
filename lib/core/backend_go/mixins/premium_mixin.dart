// ─────────────────────────────────────────────────────────────
// premium_mixin.dart — Mixin de premium: validación de códigos,
// envío del token de GitHub y sync del estado premium a Go.
// La validación completa (estructura + registro de GitHub + marcar
// usado) corre EN GO (internal/premium) — acá solo se serializa RPC.
// Se conecta con: backend_go (validatePremiumCode,
// setPremiumGithubToken, setPremiumStatus).
// Parte del flujo: setup premium, activación de códigos, arranque.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../contrato_backend.dart';

/// Validación premium (vive en el backend Go internal/premium).
mixin PremiumMixin on BackendService {
  /// Valida un código premium en el backend Go (formato legacy JWT).
  /// Devuelve null si es válido, o el mensaje de error si no lo es.
  @override
  Future<String?> validatePremiumCode(String code) async {
    try {
      final raw = await rpcCall('validatePremiumCode', {'code': code});
      if (raw is String && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          final err = parsed['error'];
          if (err != null) return err.toString();
          return null;
        }
      }
      return 'Error de validación';
    } catch (_) {
      return 'No se pudo validar el código';
    }
  }

  /// Envía el token de GitHub para que el backend Go consulte el registro.
  @override
  Future<void> setPremiumGithubToken(String token) async {
    try {
      await rpcCall('setPremiumGithubToken', {'token': token});
    } catch (_) {}
  }

  /// Sincroniza el estado premium guardado en drift hacia el backend Go
  /// (SetPremiumStatus) para que el gate de descargas respete códigos ya
  /// activados después de un reinicio. Se llama al arrancar el backend.
  @override
  Future<void> syncPremiumStatus({
    required bool isPremium,
    required String tier,
    int? expiresAt,
  }) async {
    try {
      await rpcCall('setPremiumStatus', {
        'isPremium': isPremium,
        'tier': tier,
        if (expiresAt != null && expiresAt > 0) 'expiresAt': expiresAt,
      });
    } catch (_) {}
  }
}