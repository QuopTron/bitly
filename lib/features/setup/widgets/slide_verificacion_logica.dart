// ─────────────────────────────────────────────────────────────
// slide_verificacion_logica.dart — PART de slide_verificacion.dart:
// lógica de verificación de proveedores — recorre cada extensión,
// obtiene su URL de challenge (getPendingVerificationUrl o
// triggerExtensionVerification), abre el WebView compartido y
// completa el grant contra Go. No reutiliza grants entre
// proveedores (un grant está ligado al challenge que lo emitió).
// Recibe el State del slide para usar _aplicar (setState) y campos.
// Se conecta con: slide_verificacion.dart (misma library) +
// backend_go + ServicioVerificacion (WebView) + logger.
// Parte del flujo: setup (paso 6: verificación de fuentes).
// ─────────────────────────────────────────────────────────────

part of 'slide_verificacion.dart';

/// Recorre los proveedores e intenta firmar cada uno. El flujo es VISIBLE
/// como en Android: primero intenta el auto-pase de Turnstile (managed, que
/// Cloudflare resuelve solo en un WebView real), y si el challenge exige
/// interacción humana abre el sandbox in-app (WebView) para que el usuario
/// lo resuelva; al completarlo rescata el token, cierra el sandbox y sigue
/// con el siguiente proveedor. El usuario puede continuar/omitir al terminar.
Future<void> _iniciarVerificacionSt(_SlideVerificacionState st) async {
  if (st._verificacionIniciada) return;
  st._aplicar(() => st._verificacionIniciada = true);

  final backend = di.sl<BackendService>();

  for (final (extId, nombre) in _SlideVerificacionState._proveedores) {
    if (!st.mounted) return;
    st._aplicar(() => st._estados[extId] = _EstadoProveedor.verificando);

    try {
      _log.i('Verificando $extId...');
      var url = await backend.getPendingVerificationUrl(extId);
      if (url.isEmpty) {
        url = await backend.triggerExtensionVerification(extId);
      }
      if (url.isEmpty) {
        _log.i('$extId: sin URL de auth, marcado verificado');
        st._aplicar(() => st._estados[extId] = _EstadoProveedor.verificado);
        continue;
      }

      if (!st.mounted) return;

      // El setup muestra el sandbox DIRECTAMENTE (sin esperar el intento
      // silencioso de 36s): el usuario toca Verificar y ve el WebView al
      // instante, lo resuelve, se rescata el token y el sandbox se cierra.
      final ok = await ServicioVerificacion().verificarFuenteNoIntrusiva(
        extId,
        nombre,
        url,
        intentarAuto: false,
      );
      _log.i('$extId: verificación → $ok');
      if (st.mounted) {
        st._aplicar(() {
          st._estados[extId] =
              ok ? _EstadoProveedor.verificado : _EstadoProveedor.fallo;
        });
      }
    } catch (e) {
      _log.e('Verificación falló para $extId: $e');
      if (st.mounted) {
        st._aplicar(() => st._estados[extId] = _EstadoProveedor.fallo);
      }
    }
  }
}