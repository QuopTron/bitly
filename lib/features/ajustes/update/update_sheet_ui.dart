// ─────────────────────────────────────────────────────────────
// update_sheet_ui.dart — PART de update_modal.dart: UI de la hoja
// de actualización (handle, icono, versión, progreso, notas y
// botones). Se expone como función top-level y el State delega su
// build acá; los bloques viven en update_sheet_bloques.dart.
// Se conecta con: update_modal.dart (misma library).
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

part of 'update_modal.dart';

/// Construye la hoja de actualización a partir del estado.
Widget _construirHojaActualizacion(
  _EstadoHojaActualizacion st,
  BuildContext context,
) {
  final info = st.widget.info;
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final fondo = ColoresApp.superficie(esOscuro);
  final sobreFondo = ColoresApp.enSuperficie(esOscuro);
  final apagado = ColoresApp.enSuperficieApagado(esOscuro);
  final borde = ColoresApp.borde(esOscuro);

  return Container(
    margin: EdgeInsets.only(top: r.spacingXL * 2),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: r.spacingM),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sobreFondo.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: r.spacingXL),
            _cabeceraActualizacion(st, r, sobreFondo, apagado),
            if (st._descargando)
              _progresoActualizacion(st, r, sobreFondo, apagado),
            if (st._error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.spacingXL),
                child: Text(
                  st._error!,
                  style: TextStyle(
                    fontSize: r.footerSize,
                    color: ColoresApp.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (!st._descargando && info.body.isNotEmpty)
              _notasActualizacion(st, r, sobreFondo, borde),
            SizedBox(height: r.spacingXL),
            if (!st._descargando) _botonesActualizacion(st, context, r, apagado),
            // + menú de navegación del sistema: los botones van al pie de la
            // hoja, que se ancla al borde físico de la pantalla.
            SizedBox(height: r.spacingM + insetInferiorSistema(context)),
          ],
        ),
      ),
    ),
  );
}
