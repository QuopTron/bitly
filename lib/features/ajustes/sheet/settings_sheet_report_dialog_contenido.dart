// ─────────────────────────────────────────────────────────────
// settings_sheet_report_dialog_contenido.dart — PART de
// settings_sheet_new.dart: el contenido del diálogo de reporte — el
// selector Bug/Sugerencia y los campos de título y detalle, con los
// bordes que se iluminan con el color de la app al enfocar.
// Se conecta con: settings_sheet_new.dart (misma library).
// Parte del flujo: Ajustes → Más (diálogo de reporte).
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

/// Contenido (selector + campos) del diálogo de reporte.
Widget _contenidoDialogoReporte({
  required bool isBug,
  required Color glow,
  required Color onBg,
  required Responsive r,
  required AppLocalizations loc,
  required TextEditingController titleCtrl,
  required TextEditingController bodyCtrl,
  required StateSetter setModalState,
  required ValueChanged<bool> onBugCambiado,
}) {
return SizedBox(
    width: double.maxFinite,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type toggle: Bug / Sugerencia
        _ReportTypeToggle(
          isBug: isBug,
          glowColor: glow,
          onBg: onBg,
          r: r,
          onChanged: onBugCambiado,
        ),
        SizedBox(height: r.spacingM),
        TextField(
          controller: titleCtrl,
          style: TextStyle(color: onBg),
          decoration: InputDecoration(
            labelText: loc.setup.reportTitle,
            labelStyle: TextStyle(color: onBg.withValues(alpha: 0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: onBg.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: glow),
            ),
          ),
        ),
        SizedBox(height: r.spacingS),
        TextField(
          controller: bodyCtrl,
          maxLines: 4,
          style: TextStyle(color: onBg),
          decoration: InputDecoration(
            hintText: loc.setup.reportBody,
            hintStyle: TextStyle(color: onBg.withValues(alpha: 0.4)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: onBg.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: glow),
            ),
          ),
        ),
      ],
    ),
  );
}
