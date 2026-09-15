// ─────────────────────────────────────────────────────────────
// verificacion_silenciosa.dart — PART de servicio_verificacion.dart:
// intentos SILENCIOSOS de firmar la sesión de una fuente. Levanta el
// challenge de Cloudflare en un WebView fuera de pantalla (los
// Turnstile en modo managed se auto-resuelven) y, si obtiene el
// grant, firma la sesión contra Go sin mostrar nada al usuario.
// Se conecta con: servicio_verificacion.dart (misma library) +
// contrato_backend + panel_verificacion_web.
// Parte del flujo: verificación de sesiones (auto-firmado en 2º plano).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';

/// Auto-firmado silencioso de sesiones. Mixin aplicado en ServicioVerificacion.
mixin VerificacionSilenciosa on VerificacionKeepalive {
  /// Intenta auto-completar el challenge en un WebView FUERA de pantalla. Los
  /// Turnstile en modo managed/no-interactivo se auto-resuelven solos: el
  /// puente JS `SpotiflacGrant` entrega el grant sin interacción humana.
  /// Devuelve el grant, o null si el challenge pide interacción o no completa
  /// a tiempo (ahí el flujo sigue sin molestar al usuario).
  ///
  /// Se intenta 3 veces: el primer pase suele correr sin cookies de Turnstile
  /// (cf_clearance) y puede que no auto-pase; si el widget corrió, deja la
  /// cookie en el store compartido (Android/WebView2) y los pases siguientes
  /// con la MISMA URL suelen auto-pasar. Estos pases extra son los que
  /// convierten muchos "interactivos por defecto" en silenciosos.
  Future<String?> _intentarSilencioso(String urlAuth, BuildContext ctx) async {
    for (var intento = 0; intento < 3; intento++) {
      final grant = await _intentoSilenciosoUnico(
        urlAuth,
        ctx,
        const Duration(seconds: 12),
      );
      if (grant != null && grant.isNotEmpty) return grant;
    }
    return null;
  }

  /// Un pase único del intento silencioso: carga la URL del challenge en un
  /// WebView oculto y espera el grant por el puente JS (o timeout).
  Future<String?> _intentoSilenciosoUnico(
    String urlAuth,
    BuildContext ctx,
    Duration tiempo,
  ) async {
    final completador = Completer<String?>();
    late OverlayEntry entrada;
    var cerrado = false;
    void terminar(String? grant) {
      if (cerrado) return;
      cerrado = true;
      if (!completador.isCompleted) completador.complete(grant);
    }

    // El WebView silencioso debe estar FUERA de la pantalla, no "oculto" con
    // Opacity(0): en Android los platform views se dibujan en una capa aparte
    // e IGNORAN la opacidad de Flutter — un Opacity(0) con SizedBox 1x1 se
    // renderiza igualmente visible a su tamaño real (p.ej. 656x640) y el
    // usuario ve un "modal" fantasma. Posicionarlo con left/top muy negativos
    // lo saca del viewport visible (clipBehavior: none) manteniéndolo vivo
    // para que Turnstile managed se auto-resuelva sin mostrar nada.
    entrada = OverlayEntry(
      builder: (_) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -10000,
            top: -10000,
            width: 656,
            height: 640,
            child: IgnorePointer(
              child: PanelVerificacionWeb(
                urlAuth: urlAuth,
                alObtenerGrant: terminar,
                colorCarga: Colors.transparent,
                esOscuro: true,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(ctx, rootOverlay: true).insert(entrada);

    final timer = Timer(tiempo, () => terminar(null));
    final grant = await completador.future;
    timer.cancel();
    entrada.remove();
    if (grant == null || grant.isEmpty) return null;
    return grant;
  }

  /// Reintenta SILENCIOSAMENTE las fuentes que quedaron pendientes de
  /// verificar. Ideal tras obtener un grant (el usuario resolvió un checkbox o
  /// una managed auto-pasó): el store de cookies ya tiene cf_clearance y las
  /// demás fuentes (mismo gateway zarz, mismo sitekey de Turnstile) pueden
  /// auto-pasar SIN modal. Nunca abre UI. Llamado tras cada éxito del lote y
  /// al volver la app al primer plano.
  Future<void> reintentarPendientesSilencioso() async {
    if (!estaListo || _necesitaVerificacion.isEmpty || _deshabilitado) return;
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final backend = di.sl<BackendService>();
    final fuentes = List<String>.from(_necesitaVerificacion);
    for (final extId in fuentes) {
      if (_deshabilitado || _dialogoAbierto || _pendiente != null) break;
      if (!ctx.mounted) return;
      try {
        var url = await backend.getPendingVerificationUrl(extId);
        if (url.isEmpty) {
          url = await backend.triggerExtensionVerification(extId);
        }
        if (url.isEmpty) continue;
        if (!ctx.mounted) return;
        final grant = await _intentarSilencioso(url, ctx);
        if (grant == null || grant.isEmpty) continue;
        final ok = await backend.completeSignedSessionGrant(extId, grant);
        _logVerificacion.i(
            '[Verificacion] re-intento silencioso $extId → $ok');
        if (ok) _necesitaVerificacion.remove(extId);
      } catch (e) {
        _logVerificacion.w(
            '[Verificacion] re-intento silencioso $extId error: $e');
      }
    }
  }
}
