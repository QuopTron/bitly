// ─────────────────────────────────────────────────────────────
// tarjeta_grilla_descarga.dart — PART de tarjeta_grilla.dart:
// helpers del estado de descarga de la tarjeta de grilla —
// tooltip contextual (reintentar/pausar/borrar/descargar), acción
// según estado e icono/color según estado. Reciben la tarjeta para
// acceder a sus campos (estadoDescarga, onPausar, onBorrar,
// onReintentar, onDescargar).
// Se conecta con: tarjeta_grilla.dart (misma library) + colores_app.
// Parte del flujo: feed, búsqueda, mi espacio (badge de descarga).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_grilla.dart';

String _tooltipDescarga(TarjetaGrilla t, AppLocalizations loc) {
  switch (t.estadoDescarga) {
    case EstadoDescarga.interrumpido:
      return loc.setup.downloadTooltipRetry;
    case EstadoDescarga.enProgreso:
      return loc.setup.downloadTooltipPause;
    case EstadoDescarga.completado:
      return loc.setup.downloadTooltipDelete;
    default:
      return loc.setup.downloadTooltipDownload;
  }
}

VoidCallback? _accionDescargaDe(TarjetaGrilla t) {
  switch (t.estadoDescarga) {
    case EstadoDescarga.enProgreso:
      return t.onPausar ?? t.onBorrar;
    case EstadoDescarga.completado:
      return t.onBorrar ?? t.onDescargar;
    case EstadoDescarga.interrumpido:
      return t.onReintentar ?? t.onDescargar;
    default:
      return t.onDescargar;
  }
}

IconData _iconoDescargaDe(TarjetaGrilla t) {
  switch (t.estadoDescarga) {
    case EstadoDescarga.enProgreso:
      return Icons.pause_circle_filled;
    case EstadoDescarga.completado:
      return Icons.delete_outline;
    case EstadoDescarga.interrumpido:
      return Icons.refresh;
    default:
      return Icons.download;
  }
}

Color _colorIconoDescargaDe(TarjetaGrilla t, bool esOscuro) {
  final fg = ColoresApp.enSuperficie(esOscuro);
  switch (t.estadoDescarga) {
    case EstadoDescarga.enProgreso:
      return ColoresApp.advertencia;
    case EstadoDescarga.completado:
      return ColoresApp.error.withValues(alpha: 0.6);
    case EstadoDescarga.interrumpido:
      return ColoresApp.error;
    default:
      return fg.withValues(alpha: 0.6);
  }
}