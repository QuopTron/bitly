// ─────────────────────────────────────────────────────────────
// dialogo_verificacion.dart — Shell del dialog in-app que hospeda
// el challenge de Cloudflare (Turnstile): header con nombre de la
// fuente, área del WebView (delegada a panel_verificacion_web.dart)
// y footer con el botón de abrir en el navegador externo. El grant
// se devuelve al ServicioVerificacion por callbacks.
//
// Responsive: en MÓVIL usa el diseño compacto actual (ocupa el
// ancho de la pantalla menos 16px, WebView de 320px de alto). En
// ESCRITORIO/ventanas anchas el dialog se acota a un ancho máximo
// de 520px centrado con WebView de 440px — nunca se estira a toda
// la ventana y el contenido del challenge siempre carga completo.
// Se conecta con: servicio_verificacion + panel_verificacion_web +
// deteccion_plataforma.
// Parte del flujo: verificación de sesiones (dialog Cloudflare).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../utilidades/deteccion_plataforma.dart';
import 'panel_verificacion_web.dart';

/// Popup in-app con el challenge Cloudflare (WebView embebido).
class DialogoVerificacion extends StatelessWidget {
  final String nombreMostrado;
  final String urlAuth;
  final void Function(String grant) alObtenerGrant;
  final VoidCallback alCancelar;
  final VoidCallback alUsarNavegador;

  const DialogoVerificacion({
    super.key,
    required this.nombreMostrado,
    required this.urlAuth,
    required this.alObtenerGrant,
    required this.alCancelar,
    required this.alUsarNavegador,
  });

  @override
  Widget build(BuildContext context) {
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
}