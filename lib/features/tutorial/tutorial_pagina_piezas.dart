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
  return Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(paso.icono, size: 80, color: ColoresApp.verdeBrillante),
        const SizedBox(height: 32),
        Text(paso.titulo,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorSuperficie),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(paso.descripcion,
            style: TextStyle(
                fontSize: 16,
                color: colorSuperficie.withValues(alpha: 0.6)),
            textAlign: TextAlign.center),
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

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: st._pagina == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: st._pagina == i
                    ? ColoresApp.verdeBrillante
                    : colorSuperficie.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            )),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: 220,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColoresApp.verdeBrillante,
            foregroundColor: Colors.white,
          ),
          onPressed: () => st._siguiente(total),
          child: Text(
              esUltimo ? loc.tutorial.empezar : loc.tutorial.siguiente),
        ),
      ),
    ],
  );
}