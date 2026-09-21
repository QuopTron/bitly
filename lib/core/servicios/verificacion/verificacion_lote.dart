// ─────────────────────────────────────────────────────────────
// verificacion_lote.dart — PART de servicio_verificacion.dart:
// verificación por lote de las fuentes que necesitan challenge
// humano (Cloudflare) tras el provision del arranque, más el
// getter de fuentes pendientes y el nombre legible de cada fuente.
// Separado del archivo principal para mantener el límite de líneas.
// Se conecta con: servicio_verificacion.dart (misma library).
// Parte del flujo: verificación de sesiones (lote post-provision).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Verificación en lote. Mixin aplicado en ServicioVerificacion.
mixin VerificacionLote on VerificacionMostrar {
  /// Verifica UNA sola fuente con el flujo completo (URL pendiente →
  /// challenge → grant → registro) y devuelve true si quedó autenticada.
  ///
  /// Es la acción de la tarjeta "Sesiones" de Ajustes: permite renovar o
  /// migrar las fuentes de a una sin abrir los challenges de las demás.
  /// Al ser una acción EXPLÍCITA del usuario, rehabilita el flujo modal
  /// aunque antes se haya tocado "omitir".
  Future<bool> verificarFuente(String extId, {bool intentarAuto = true}) async {
    final backend = di.sl<BackendService>();
    _deshabilitado = false;
    try {
      var url = await backend.getPendingVerificationUrl(extId);
      if (url.isEmpty) {
        url = await backend.triggerExtensionVerification(extId);
      }
      if (url.isEmpty) {
        _logVerificacion.i('[$extId] verificarFuente: sin URL auth pendiente');
        return false;
      }
      final grant = await mostrarVerificacion(
        extId: extId,
        nombreMostrado: nombreFuente(extId),
        urlAuth: url,
        intentarAuto: intentarAuto,
      );
      if (grant == null || grant.isEmpty) return false;
      final ok = await backend.completeSignedSessionGrant(extId, grant);
      if (ok) _necesitaVerificacion.remove(extId);
      return ok;
    } catch (e) {
      _logVerificacion.w('[$extId] verificarFuente error: $e');
      return false;
    }
  }

  /// Nombre legible de una fuente (para la UI del dialog).
  String nombreFuente(String s) {
    switch (s) {
      case 'qobuz-web':
        return 'Qobuz';
      case 'amazon':
        return 'Amazon Music';
      case 'deezer':
        return 'Deezer';
      case 'pandora':
        return 'Pandora';
      case 'tidal-web':
        return 'TIDAL';
      default:
        return s;
    }
  }
}
