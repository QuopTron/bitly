// ─────────────────────────────────────────────────────────────
// dialogo_verificacion_piezas.dart — PART de dialogo_verificacion.dart:
// el `build` del dialog que hospeda el challenge Cloudflare — header
// con el nombre de la fuente, área del WebView y footer con el texto
// explicativo y el botón de abrir en el navegador. Recibe el widget y
// arma el layout responsive (móvil a pantalla completa, escritorio
// acotado y centrado).
// Se conecta con: dialogo_verificacion.dart (misma library) +
// panel_verificacion_web + deteccion_plataforma.
// Parte del flujo: verificación de sesiones (dialog Cloudflare).
// ─────────────────────────────────────────────────────────────

part of 'dialogo_verificacion.dart';

Widget _construirDialogo(BuildContext context, String nombreMostrado, String urlAuth, void Function(String grant) alObtenerGrant, VoidCallback alCancelar, VoidCallback alUsarNavegador) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorTexto = esOscuro ? Colors.white : Colors.black;
    final primario = Theme.of(context).colorScheme.primary;
    // Móvil: dialog a ancho de pantalla (como siempre). Escritorio:
    // acotado y centrado para no estirarse por toda la ventana.
    final escritorio = usarLayoutEscritorio(context);
    final anchoWeb = escritorio ? 520.0 : double.infinity;
    final altoWeb = escritorio ? 440.0 : 320.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: escritorio
          ? const EdgeInsets.symmetric(horizontal: 32, vertical: 48)
          : const EdgeInsets.all(16),
      child: Container(
        width: anchoWeb,
        decoration: BoxDecoration(
          color: esOscuro ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: escritorio
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: colorTexto.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verificar $nombreMostrado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorTexto,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: colorTexto.withValues(alpha: 0.5)),
                    onPressed: alCancelar,
                  ),
                ],
              ),
            ),
            // WebView (panel con su propio state)
            SizedBox(
              height: altoWeb,
              child: PanelVerificacionWeb(
                urlAuth: urlAuth,
                alObtenerGrant: alObtenerGrant,
                colorCarga: primario,
                esOscuro: esOscuro,
              ),
            ),
            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Completa la verificación para poder reproducir y descargar '
                    'música de $nombreMostrado. Es un control del propio servicio '
                    'de música (no nuestro): al resolverlo, la app continúa sola '
                    'y no te lo volverá a pedir hasta que la sesión expire.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorTexto.withValues(alpha: 0.6),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Si el captcha no carga aquí, ábrelo en el navegador:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorTexto.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: alUsarNavegador,
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('Abrir en el navegador'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primario,
                        side: BorderSide(color: primario.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}
