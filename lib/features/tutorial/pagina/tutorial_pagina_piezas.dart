// ─────────────────────────────────────────────────────────────
// tutorial_pagina_piezas.dart — PART de tutorial_pagina.dart:
// construcción visual de un paso (icono, título, descripción) y
// de los controles (indicadores de página + botón principal
// Siguiente/Empezar). El estado de página lo lee del State padre.
// Se conecta con: tutorial_pagina.dart (misma library) + l10n +
// colores_app.
// Parte del flujo: arranque (primer uso, piezas del tutorial).
// ─────────────────────────────────────────────────────────────

part of 'tutorial_pagina.dart';

/// Un paso del PageView: icono, título y descripción centrados.
Widget _construirPaso(BuildContext context, Paso paso) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final colorSuperficie = ColoresApp.enSuperficie(esOscuro);
  // Cada paso se mide con el aparato: en la tele el ícono y los textos crecen
  // (a tres metros un ícono de 80 no se ve).
  final r = Responsive(context);
  return Padding(
    padding: EdgeInsets.all(r.sobre(40, 64)),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          paso.icono,
          size: r.sobre(80, 120),
          color: ColoresApp.verdeBrillante,
        ),
        SizedBox(height: r.sobre(32, 48)),
        Text(
          paso.titulo,
          style: TextStyle(
            fontSize: r.sobre(24, 34),
            fontWeight: FontWeight.bold,
            color: colorSuperficie,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.sobre(16, 26)),
        Text(
          paso.descripcion,
          style: TextStyle(
            fontSize: r.sobre(16, 24),
            color: colorSuperficie.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Indicadores de página + botón principal (Siguiente/Empezar).
Widget _construirControles(_TutorialPaginaState st, int total) {
  final esOscuro = Theme.of(st.context).brightness == Brightness.dark;
  final colorSuperficie = ColoresApp.enSuperficie(esOscuro);
  final loc = AppLocalizations.of(st.context);
  final esUltimo = st._pagina == total - 1;
  // Indicadores y botón también por aparato: en la tele el botón principal
  // tiene que ser un blanco grande para el puntero.
  final r = Responsive(st.context);
  final esp = EspecificacionesPlataforma.de(st.context);
  final altoPunto = esp.altoIndicador * 0.34; // 8 en celular

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          total,
          (i) => Container(
            margin: EdgeInsets.symmetric(horizontal: r.spacingXS),
            width: st._pagina == i ? r.sobre(24, 36) : altoPunto,
            height: altoPunto,
            decoration: BoxDecoration(
              color:
                  st._pagina == i
                      ? ColoresApp.verdeBrillante
                      : colorSuperficie.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(altoPunto / 2),
            ),
          ),
        ),
      ),
      SizedBox(height: r.sobre(24, 36)),
      SizedBox(
        width: r.sobre(220, 320),
        height: esp.altoBotonGrande,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColoresApp.verdeBrillante,
            foregroundColor: Colors.white,
          ),
          onPressed: () => st._siguiente(total),
          child: Text(esUltimo ? loc.tutorial.empezar : loc.tutorial.siguiente),
        ),
      ),
    ],
  );
}
