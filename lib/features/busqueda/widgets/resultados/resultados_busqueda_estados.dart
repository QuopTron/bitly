// ─────────────────────────────────────────────────────────────
// resultados_busqueda_estados.dart — PART de
// resultados_busqueda.dart: estados vacíos de los resultados —
// error con icono, "sin resultados" con icono de búsqueda y el
// snapshot ligero de descargas para el BlocSelector del padre.
// Se conecta con: resultados_busqueda.dart (misma library) +
// colores_app + l10n.
// Parte del flujo: búsqueda (resultados → estados).
// ─────────────────────────────────────────────────────────────

part of 'resultados_busqueda.dart';

/// Mensaje centrado de error de búsqueda con icono.
Widget _estadoError(Responsive r, String error) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: ColoresApp.error.withValues(alpha: 0.3),
        ),
        SizedBox(height: r.spacingM),
        Text(
          error,
          style: TextStyle(color: ColoresApp.error, fontSize: r.subtitleSize),
        ),
      ],
    ),
  );
}

/// Mensaje centrado de "sin resultados" con icono de búsqueda.
Widget _estadoSinResultados(AppLocalizations loc, Responsive r, Color onBg) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 48,
          color: onBg.withValues(alpha: 0.15),
        ),
        SizedBox(height: r.spacingM),
        Text(
          loc.setup.noResults,
          style: TextStyle(
            fontSize: r.subtitleSize,
            color: onBg.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}

/// Snapshot ligero de estados de descarga para BlocSelector.
class SnapshotDescargasBusqueda {
  final Map<String, EstadoDescarga> estados;
  final Set<String> huellas;
  const SnapshotDescargasBusqueda(this.estados, this.huellas);
}