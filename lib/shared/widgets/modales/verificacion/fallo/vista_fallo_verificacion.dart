// ─────────────────────────────────────────────────────────────
// vista_fallo_verificacion.dart — Vista de fallo del WebView de
// verificación Cloudflare: mensaje de error + botones de reintento
// (recarga el WebView) cuando el challenge no carga a tiempo o falla
// en el frame principal. Widget de UI puro (sin estado propio).
// Se conecta con: panel_verificacion_web.dart (lo muestra).
// Parte del flujo: verificación de sesiones (fallo del captcha).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../tema/especificaciones/especificaciones_plataforma.dart';
import '../../../../utilidades/plataforma/responsive.dart';

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
    final v = AppLocalizations.of(context).verificacion;
    final colorTexto = esOscuro ? Colors.white : Colors.black;
    // El aviso crece con el aparato: mismo texto, ícono y aire que el resto.
    final r = Responsive(context);
    final e = EspecificacionesPlataforma.de(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: r.val(48, 40, 90),
              color: Colors.redAccent,
            ),
            SizedBox(height: r.spacingM),
            Text(
              v.falloTitulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.titleSize,
                fontWeight: FontWeight.bold,
                color: colorTexto,
              ),
            ),
            SizedBox(height: r.spacingS),
            Text(
              v.falloAyuda,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.subtitleSize,
                color: esOscuro ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: r.spacingM),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: Icon(Icons.refresh, size: e.iconoBoton),
              label: Text(v.reintentar),
            ),
          ],
        ),
      ),
    );
  }
}
