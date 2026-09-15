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

import '../../../utilidades/plataforma/deteccion_plataforma.dart';
import 'panel_verificacion_web.dart';

part 'dialogo_verificacion_piezas.dart';

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
  Widget build(BuildContext context) => _construirDialogo(context, nombreMostrado, urlAuth, alObtenerGrant, alCancelar, alUsarNavegador);
}
