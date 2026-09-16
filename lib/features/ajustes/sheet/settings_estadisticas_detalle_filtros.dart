// ─────────────────────────────────────────────────────────────
// settings_estadisticas_detalle_filtros.dart — PART de settings_sheet
// _new.dart: barra de filtros del sub-modal de estadísticas.
//
// Los filtros son de STATS, no de catálogo, y cada fila dice qué filtra
// ("Qué", "Cuándo", "Orden") para que no se confundan con los filtros de
// canciones. Se aplican al instante sobre lo ya cargado y todos los
// nombres salen localizados (settings_estadisticas_etiquetas.dart).
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle.dart (la usa) + filtro_escucha.
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Barra de filtros: tres filas etiquetadas (qué / cuándo / orden), cada una
/// deslizable en horizontal y compacta — tres filas no pueden comerse la hoja.
class _BarraFiltrosDetalle extends StatelessWidget {
  final TipoEscucha tipo;
  final RangoEscucha rango;
  final OrdenEscucha orden;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final ValueChanged<TipoEscucha> onTipo;
  final ValueChanged<RangoEscucha> onRango;
  final ValueChanged<OrdenEscucha> onOrden;

  const _BarraFiltrosDetalle({
    required this.tipo,
    required this.rango,
    required this.orden,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTipo,
    required this.onRango,
    required this.onOrden,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final s = loc.estadisticas;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilaFiltro(
            etiqueta: s.filtroQue,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            chips: [
              for (final t in TipoEscucha.values)
                _ChipFiltro(
                  texto: _etiquetaTipo(loc, t),
                  activo: t == tipo,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () => onTipo(t),
                ),
            ],
          ),
          _FilaFiltro(
            etiqueta: s.filtroCuando,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            chips: [
              for (final rg in RangoEscucha.values)
                _ChipFiltro(
                  texto: _etiquetaRango(loc, rg),
                  activo: rg == rango,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () => onRango(rg),
                ),
            ],
          ),
          _FilaFiltro(
            etiqueta: s.filtroOrden,
            glowColor: glowColor,
            onBg: onBg,
            r: r,
            chips: [
              for (final o in OrdenEscucha.values)
                _ChipFiltro(
                  texto: _etiquetaOrden(loc, o),
                  activo: o == orden,
                  glowColor: glowColor,
                  onBg: onBg,
                  r: r,
                  onTap: () => onOrden(o),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
