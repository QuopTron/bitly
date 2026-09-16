// ─────────────────────────────────────────────────────────────
// settings_estadisticas_tirador.dart — PART de settings_sheet_new
// .dart: tirador (pequeña barra superior) de las hojas de estadísticas.
// Es la señal visual de que la hoja se puede arrastrar para cerrar.
// Se conecta con: settings_sheet_new.dart (misma library) +
// settings_estadisticas_detalle.dart (lo usa).
// Parte del flujo: Ajustes → Estadísticas (hojas).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Tirador de hoja: barra fina centrada arriba.
class _TiradorHoja extends StatelessWidget {
  final Color onBg;
  final Responsive r;

  const _TiradorHoja({required this.onBg, required this.r});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: r.spacingS * 0.7, bottom: r.spacingXS),
      child: Container(
        width: 36,
        height: 3,
        decoration: BoxDecoration(
          color: onBg.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
