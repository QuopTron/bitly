// ─────────────────────────────────────────────────────────────
// sesiones_acciones_mixin.dart — Acciones de extensión y grant de
// sesión firmada (Cloudflare): invocar un export JS de la extensión
// (p.ej. youtubeOauthConnect) y completar el grant con el código
// de autorización. Separado de sesiones_firmadas_mixin.dart para
// mantener cada archivo dentro del límite de líneas.
// Se conecta con: backend_go (invokeExtensionAction,
// completeSignedSessionGrant).
// Parte del flujo: verificación de sesiones (Cloudflare).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:logger/logger.dart';

import '../contrato_backend.dart';

final _logAcciones = Logger();

/// Acciones de extensión y grant de sesión firmada.
mixin SesionesAccionesMixin on BackendService {
  @override
  Future<Map<String, dynamic>> invokeExtensionAction(
    String provider,
    String action, {
    List<dynamic> args = const [],
  }) async {
    try {
      final resultado = await rpcCall('invokeExtensionAction', {
        'provider': provider,
        'action': action,
        'args': args,
      });
      if (resultado is Map) return Map<String, dynamic>.from(resultado);
      if (resultado is String && resultado.isNotEmpty) {
        final decodificado = jsonDecode(resultado);
        if (decodificado is Map) return Map<String, dynamic>.from(decodificado);
      }
      return {'ok': false, 'error': 'Respuesta inesperada'};
    } catch (e) {
      _logAcciones.w('[sesiones] invokeExtensionAction falló para $provider/$action: $e');
      return {'ok': false, 'error': '$e'};
    }
  }

  @override
  Future<bool> completeSignedSessionGrant(String extensionId, String grantCode) async {
    try {
      final resultado = await rpcCall('completeSignedSessionGrant', {
        'extension_id': extensionId,
        'grant_code': grantCode,
      });
      bool ok = false;
      String? error;
      if (resultado is Map) {
        ok = resultado['success'] == true;
        error = resultado['error'] as String?;
      } else if (resultado is String && resultado.isNotEmpty) {
        final decodificado = jsonDecode(resultado);
        if (decodificado is Map) {
          ok = decodificado['success'] == true;
          error = decodificado['error'] as String?;
        }
      }
      if (!ok) {
        _logAcciones.w('[sesiones] completeSignedSessionGrant falló para $extensionId: $error');
      }
      return ok;
    } catch (e) {
      _logAcciones.e('[sesiones] completeSignedSessionGrant error para $extensionId: $e');
      return false;
    }
  }
}