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
  /// Fuentes que el último provision encontró necesitando challenge humano
  /// (sesión faltante/vencida y el gateway pidió verificación). Solo los
  /// flujos de acción explícita las muestran, nunca se auto-abren.
  Set<String> get fuentesQueNecesitanVerificacion =>
      Set.unmodifiable(_necesitaVerificacion);

  /// Verifica por lote TODOS los sandboxes que necesitan confirmación
  /// Cloudflare en un pase secuencial. Se llama desde el home tras el
  /// provision para que el usuario vea todos los challenges de una vez en vez
  /// de descubrirlos uno por uno durante search/download/play.
  Future<void> verificarTodoEnLote() async {
    if (!estaListo || _necesitaVerificacion.isEmpty) return;
    final backend = di.sl<BackendService>();
    final fuentes = List<String>.from(_necesitaVerificacion);
    _logVerificacion.i('[Verificacion] lote: ${fuentes.length} fuentes: $fuentes');
    for (final extId in fuentes) {
      if (_deshabilitado) break;
      // Un re-intento silencioso (tras otro grant) pudo firmarla ya — no abrir
      // su modal innecesariamente.
      if (!_necesitaVerificacion.contains(extId)) continue;
      try {
        var url = await backend.getPendingVerificationUrl(extId);
        if (url.isEmpty) {
          url = await backend.triggerExtensionVerification(extId);
        }
        if (url.isEmpty) {
          _logVerificacion.i('[$extId] sin URL auth pendiente, skip lote');
          continue;
        }
        final nombreMostrado = nombreFuente(extId);
        final grant = await mostrarVerificacion(
          extId: extId,
          nombreMostrado: nombreMostrado,
          urlAuth: url,
        );
        if (grant == null || grant.isEmpty) {
          _logVerificacion.w('[$extId] lote: sin grant obtenido');
          continue;
        }
        final ok = await backend.completeSignedSessionGrant(extId, grant);
        _logVerificacion.i('[$extId] lote: grant result: $ok');
        if (ok) {
          _necesitaVerificacion.remove(extId);
          // Nota: no disparar aquí reintentarPendientesSilencioso() en paralelo —
          // cargaría el MISMO challenge pendiente que el loop está por mostrar
          // (carrera en un challenge de un solo uso). El siguiente mostrarVerificacion
          // ya corre su intento silencioso CON cf_clearance fresco en el store de
          // cookies (compartido entre WebViews) y auto-pasa sin modal.
        }
      } catch (e) {
        _logVerificacion.w('[$extId] lote error: $e');
      }
    }
    _logVerificacion.i('[Verificacion] lote: listo, restan: $_necesitaVerificacion');
  }

  /// Nombre legible de una fuente (para la UI del dialog).
  String nombreFuente(String s) {
    switch (s) {
      case 'qobuz-web': return 'Qobuz';
      case 'amazon': return 'Amazon Music';
      case 'deezer': return 'Deezer';
      case 'pandora': return 'Pandora';
      case 'tidal-web': return 'TIDAL';
      default: return s;
    }
  }
}