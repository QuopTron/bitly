// ─────────────────────────────────────────────────────────────
// update_sheet_acciones.dart — PART de update_modal.dart: notas de la release y botones de acción (descargar e instalar / ahora no) de la hoja de actualización.
// Se conecta con: update_modal.dart (misma library) + update_sheet_ui.
// Parte del flujo: Ajustes → Versión → actualización (acciones).
// ─────────────────────────────────────────────────────────────

part of 'update_modal.dart';

// Notas de la release (cuerpo del changelog).
Widget _notasActualizacion(
  _EstadoHojaActualizacion st,
  Responsive r,
  Color sobreFondo,
  Color borde,
) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.spacingM),
      decoration: BoxDecoration(
        color: sobreFondo.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde),
      ),
      child: Text(
        st.widget.info.body,
        style: TextStyle(
          fontSize: r.footerSize,
          color: sobreFondo.withValues(alpha: 0.7),
          height: 1.5,
        ),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// Botones "Descargar e instalar" y "Ahora no".
Widget _botonesActualizacion(
  _EstadoHojaActualizacion st,
  BuildContext context,
  Responsive r,
  Color apagado,
) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: st._descargarEInstalar,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresApp.exito,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.download_rounded, size: 20),
                SizedBox(width: r.spacingS),
                Text(
                  'Descargar e instalar',
                  style: TextStyle(
                    fontSize: r.subtitleSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          r.spacingXL,
          r.spacingS,
          r.spacingXL,
          r.spacingXL,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: apagado,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Ahora no',
              style: TextStyle(
                fontSize: r.footerSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
