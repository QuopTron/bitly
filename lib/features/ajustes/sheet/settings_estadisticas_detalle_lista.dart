// ─────────────────────────────────────────────────────────────
// settings_estadisticas_detalle_lista.dart — PART de settings_sheet
// _new.dart: la lista del detalle de estadísticas (cargando, vacía o
// las filas visibles). Cada fila vive en
// settings_estadisticas_detalle_fila.dart.
//
// Las carátulas llegan en un mapa id → ruta y se pintan cuando están:
// la lista aparece al instante y las portadas se acomodan después.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle.dart (la usa).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Lista del detalle: cargando, vacía o las filas visibles.
class _ListaDetalle extends StatelessWidget {
  final bool cargando;
  final List<FilaEscucha> visibles;
  final Map<String, String> caratulas;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _ListaDetalle({
    required this.cargando,
    required this.visibles,
    required this.caratulas,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: glowColor),
        ),
      );
    }
    if (visibles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(r.spacingL),
          child: Text(
            AppLocalizations.of(context).estadisticas.detalleVacio,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.footerSize,
              color: onBg.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(r.spacingM, 0, r.spacingM, r.spacingS),
      itemCount: visibles.length,
      separatorBuilder: (_, _) => SizedBox(height: r.spacingXS * 0.8),
      itemBuilder: (context, i) => _FilaDetalle(
        puesto: i + 1,
        fila: visibles[i],
        caratula: caratulas[visibles[i].id],
        glowColor: glowColor,
        onBg: onBg,
        r: r,
      ),
    );
  }
}
