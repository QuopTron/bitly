// ─────────────────────────────────────────────────────────────
// indicador_red_hoja_piezas.dart — PART de indicador_red.dart:
// piezas de la hoja de detalle de red (manija, fila etiqueta/valor
// y botón de remedición inmediata).
// Se conecta con: indicador_red.dart (misma library) +
// servicio_calidad_red.
// Parte del flujo: Home → barra superior → detalle de red.
// ─────────────────────────────────────────────────────────────

part of 'indicador_red.dart';

/// Manija superior de la hoja.
Widget manijaHojaRed(Responsive r, Color onBg) => Center(
      child: Container(
        width: r.val(36, 28, 46),
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: onBg.withValues(alpha: 0.18),
        ),
      ),
    );

/// Fila etiqueta/valor de la hoja.
Widget filaDatoHojaRed({
  required Responsive r,
  required Color onBg,
  required String etiqueta,
  required String valor,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: r.spacingXS),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: r.subtitleSize,
            color: onBg.withValues(alpha: 0.55),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: r.subtitleSize,
            fontWeight: FontWeight.w700,
            color: onBg,
          ),
        ),
      ],
    ),
  );
}

/// Botón para forzar una remedición inmediata.
Widget botonMedirHojaRed(
  BuildContext context,
  Responsive r,
  Color onBg,
  bool midiendo,
) {
  final loc = AppLocalizations.of(context);
  return SizedBox(
    width: double.infinity,
    height: r.continueButtonHeight,
    child: GestureDetector(
      onTap: midiendo ? null : () => ServicioCalidadRed.instancia.medirAhora(),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: onBg.withValues(alpha: 0.12)),
          color: onBg.withValues(alpha: 0.04),
        ),
        child: Text(
          midiendo ? loc.red.measuring : loc.setup.retry,
          style: TextStyle(
            fontSize: r.subtitleSize,
            fontWeight: FontWeight.w600,
            color: onBg.withValues(alpha: midiendo ? 0.5 : 0.9),
          ),
        ),
      ),
    ),
  );
}
