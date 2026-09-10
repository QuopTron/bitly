// ─────────────────────────────────────────────────────────────
// contenido_feed_estado.dart — PART de contenido_feed.dart:
// estado vacío del feed — icono de conexión apagada y mensaje
// localizado cuando el backend no devolvió contenido.
// Se conecta con: contenido_feed.dart (misma library) + l10n.
// Parte del flujo: feed de inicio (sin contenido).
// ─────────────────────────────────────────────────────────────

part of 'contenido_feed.dart';

/// Estado vacío centrado (icono + mensaje localizado).
Widget _estadoVacio(BuildContext context, Responsive r, Color onBg) {
  return Center(
    child: Padding(
      padding: EdgeInsets.all(r.spacingXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_tethering_off,
            size: 48,
            color: onBg.withValues(alpha: 0.15),
          ),
          SizedBox(height: r.spacingM),
          Text(
            AppLocalizations.of(context).setup.feedNoContent,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    ),
  );
}