// ─────────────────────────────────────────────────────────────
// settings_estadisticas_chip_filtro.dart — PART de settings_sheet
// _new.dart: chip de filtro (tipo, rango u orden) del detalle de
// estadísticas y la fila que lo contiene. Activo = resaltado con el
// color de acento.
//
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle_filtros.dart (los usa).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Chip de filtro (tipo, rango u orden).
class _ChipFiltro extends StatelessWidget {
  final String texto;
  final bool activo;
  final Color glowColor;
  final Color onBg;
  final Responsive r;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.texto,
    required this.activo,
    required this.glowColor,
    required this.onBg,
    required this.r,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: r.spacingXS),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.spacingM,
            vertical: r.spacingXS,
          ),
          decoration: BoxDecoration(
            color: activo
                ? glowColor.withValues(alpha: 0.18)
                : onBg.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: activo
                  ? glowColor.withValues(alpha: 0.5)
                  : onBg.withValues(alpha: 0.08),
            ),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: r.footerSize - 1,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? onBg : onBg.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una fila de filtro: etiqueta fija a la izquierda y chips deslizables.
class _FilaFiltro extends StatelessWidget {
  final String etiqueta;
  final List<Widget> chips;
  final Color glowColor;
  final Color onBg;
  final Responsive r;

  const _FilaFiltro({
    required this.etiqueta,
    required this.chips,
    required this.glowColor,
    required this.onBg,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: r.footerSize * 2.1,
      child: Row(
        children: [
          SizedBox(
            width: r.footerSize * 3.9,
            child: Padding(
              padding: EdgeInsets.only(left: r.spacingXS),
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.footerSize - 1,
                  fontWeight: FontWeight.w600,
                  color: onBg.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: chips,
            ),
          ),
        ],
      ),
    );
  }
}
