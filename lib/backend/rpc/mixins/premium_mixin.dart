import 'dart:convert';

import '../backend_service.dart';

/// Premium validation lives in the Go backend (`internal/premium`).
///
/// El secreto y el flujo completo de validación (estructura + registro de
/// GitHub + marcar usado) corren en Go — antes vivían hardcodeados en
/// `premium_service.dart` dentro del APK. Acá solo se serializa el RPC.
mixin PremiumMixin on BackendService {
  /// Validates a premium code in the Go backend (formato legacy JWT).
  /// Returns `null` if valid, or the error message string if invalid.
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

  /// Sends the GitHub token so the Go backend can check the codes registry.
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