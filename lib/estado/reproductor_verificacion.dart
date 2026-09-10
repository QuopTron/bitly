// ─────────────────────────────────────────────────────────────
// reproductor_verificacion.dart — PART de cubit_reproductor.dart:
// gate de sesión firmada (Cloudflare) antes de reproducir: si la
// fuente necesita sesión firmada y el token no es usable, abre el
// modal de verificación y solo permite playback cuando el usuario
// completa el challenge. También refresca sesiones de proveedores
// alcanzados durante fallback.
// Se conecta con: reproductor_controles.dart (misma library).
// Parte del flujo: reproducción (verificación previa al stream).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Verificación de sesiones. Mixin aplicado en CubitReproductor.
mixin ReproductorVerificacion on ReproductorControles {
  /// Gate de sesión firmada antes de reproducir [track]. Si la fuente necesita
  /// sesión firmada y NO es usable, abre el modal de verificación para
  /// refrescar el token ahí mismo. True solo si puede continuar la reproducción.
  Future<bool> _ensureSesionParaFuente(ItemFeed track) async {
    final fuente = track.source ?? '';
    if (!ServicioVerificacion.fuentesSesionFirmada.contains(fuente)) {
      return true; // la fuente no necesita sesión firmada
    }
    final servicio = ServicioVerificacion();
    if (!servicio.estaListo) return true; // sin UI — dejar que el backend intente

    final backend = di.sl<BackendService>();
    // Fast path: el token ya es usable. Acotado para que un status colgado
    // del backend no stallee un tap por 10s+ antes del streaming.
    try {
      final estado = await backend
          .getSignedSessionStatus(fuente)
          .timeout(const Duration(seconds: 3));
      if (estado.autenticado) return true;
    } catch (_) {}

    // Preguntar al backend si un challenge fresco está pendiente. Si reporta
    // NINGUNO, NO bloquear: el token puede ya estar al día y la capa de
    // streaming superficiará un error real si de verdad no puede reproducir.
    String url;
    try {
      url = await backend
          .getPendingVerificationUrl(fuente)
          .timeout(const Duration(seconds: 4));
      if (url.isEmpty) {
        url = await backend
            .triggerExtensionVerification(fuente)
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      return true; // ni siquiera pudo preguntar — no bloquear
    }
    if (url.isEmpty) return true; // sin challenge → permitir playback

    // Hay un challenge real: NUNCA abrir el modal solo. Intento silencioso
    // (managed auto-pasa sin UI) + aviso no-intrusivo con acción "Verificar"
    // por si el usuario quiere resolverlo. El playback NO se bloquea: si la
    // fuente quedó firmada (silencioso) continúa; si no, la capa de streaming
    // superficiará el error real y el aviso ya le ofreció verificar.
    try {
      return await servicio.verificarFuenteNoIntrusiva(
        fuente,
        servicio.nombreFuente(fuente),
        url,
      );
    } catch (e) {
      return true; // no bloquear playback por un fallo de verificación
    }
  }

  /// Abre el modal de verificación Cloudflare de [servicio] (un proveedor
  /// alcanzado durante fallback que necesita sesión firmada, p.ej. amazon)
  /// para refrescar su token. Fire-and-forget; el siguiente tap reintenta.
  Future<void> _verificarServicioParaPlayback(String servicio, String nombre) async {
    if (servicio.isEmpty) return;
    final svc = ServicioVerificacion();
    if (!svc.estaListo) return;
    final backend = di.sl<BackendService>();
    try {
      final estado = await backend.getSignedSessionStatus(servicio);
      if (estado.autenticado) return;
    } catch (_) {}
    String url;
    try {
      url = await backend.getPendingVerificationUrl(servicio);
      if (url.isEmpty) {
        url = await backend.triggerExtensionVerification(servicio);
      }
    } catch (_) {
      return;
    }
    if (url.isEmpty) return;
    try {
      await svc.verificarFuenteNoIntrusiva(
        servicio,
        nombre.isNotEmpty ? nombre : servicio,
        url,
      );
    } catch (e) {
      // Error ignorado — el siguiente tap reintenta
    }
  }
}