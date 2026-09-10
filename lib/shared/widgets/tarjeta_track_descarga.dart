// ─────────────────────────────────────────────────────────────
// tarjeta_track_descarga.dart — PART de tarjeta_track.dart:
// helpers del estado de descarga de la tarjeta de track — tooltip
// contextual (reintentar/pausar/borrar/descargar), acción según
// estado e icono/color según estado. Reciben la tarjeta para
// acceder a sus campos (estadoDescarga, mostrarAnimacionBorrar,
// onPausar, onBorrar, onDescargar).
// Se conecta con: tarjeta_track.dart (misma library) + colores_app.
// Parte del flujo: búsqueda, feed, mi espacio (badge de descarga).
// ─────────────────────────────────────────────────────────────

part of 'tarjeta_track.dart';

/// Estado efectivo: con animación de borrado se muestra completado.
EstadoDescarga _estadoEfectivoDe(TarjetaTrack t) =>
    t.mostrarAnimacionBorrar ? EstadoDescarga.completado : t.estadoDescarga;

String _tooltipDescarga(TarjetaTrack t, AppLocalizations loc) {
  switch (_estadoEfectivoDe(t)) {
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

VoidCallback? _accionDescargaDe(TarjetaTrack t) {
  switch (_estadoEfectivoDe(t)) {
    case EstadoDescarga.enProgreso:
      return t.onPausar ?? t.onBorrar;
    case EstadoDescarga.completado:
      return t.onBorrar ?? t.onDescargar;
    case EstadoDescarga.interrumpido:
      return t.onDescargar; // reintentar
    default:
      return t.onDescargar;
  }
}

IconData _iconoDescargaDe(TarjetaTrack t) {
  switch (_estadoEfectivoDe(t)) {
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

Color _colorIconoDescargaDe(TarjetaTrack t, bool esOscuro) {
  switch (_estadoEfectivoDe(t)) {
    case EstadoDescarga.enProgreso:
      return ColoresApp.advertencia;
    case EstadoDescarga.completado:
      return ColoresApp.error.withValues(alpha: 0.6);
    case EstadoDescarga.interrumpido:
      return ColoresApp.error;
    default:
      return Colors.white.withValues(alpha: 0.7);
  }
}