// ─────────────────────────────────────────────────────────────
// artista_detalle_estados.dart — PART de artista_detalle_pagina.dart:
// estado de error/vacío de la página de artista — mensaje localizado
// y botón de reintentar que relanza la carga completa.
// Se conecta con: artista_detalle_pagina.dart (misma library) + l10n.
// Parte del flujo: Detalle → artista (estados).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Estado vacío/error cuando no se pudo cargar ningún detalle.
Widget _estadoVacioArtista(
  _ArtistaDetallePaginaState st,
  BuildContext context,
) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final colorSuperficie = ColoresApp.enSuperficie(esOscuro);
  final loc = AppLocalizations.of(context);
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          loc.setup.feedEmpty,
          style: TextStyle(color: colorSuperficie.withValues(alpha: 0.4)),
        ),
        if (st._error)
          TextButton.icon(
            onPressed: () => _cargarDetalleArtista(st),
            icon: Icon(Icons.refresh,
                size: 18, color: colorSuperficie.withValues(alpha: 0.6)),
            label: Text(
              loc.setup.retry,
              style: TextStyle(color: colorSuperficie.withValues(alpha: 0.6)),
            ),
          ),
      ],
    ),
  );
}