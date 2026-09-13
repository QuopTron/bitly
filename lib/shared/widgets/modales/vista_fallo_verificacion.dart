// ─────────────────────────────────────────────────────────────
// vista_fallo_verificacion.dart — Vista de fallo del WebView de
// verificación Cloudflare: mensaje de error + botones de reintento
// (recarga el WebView) cuando el challenge no carga a tiempo o falla
// en el frame principal. Widget de UI puro (sin estado propio).
// Se conecta con: panel_verificacion_web.dart (lo muestra).
// Parte del flujo: verificación de sesiones (fallo del captcha).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Vista de fallo del captcha con botón de reintento.
class VistaFalloVerificacion extends StatelessWidget {
  final bool esOscuro;
  final VoidCallback alReintentar;

  const VistaFalloVerificacion({
    super.key,
    required this.esOscuro,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = esOscuro ? Colors.white : Colors.black;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar la verificación',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca "Abrir en el navegador" para completar el captcha.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: esOscuro ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}