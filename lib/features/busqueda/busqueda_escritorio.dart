// ─────────────────────────────────────────────────────────────
// busqueda_escritorio.dart — Variante escritorio de la búsqueda:
// panel de vidrio centrado con ancho máximo, barra de búsqueda
// (selector de fuente dentro), chips de categoría y el cuerpo
// (resultados/recientes/pegar URL). Todo el contenido viene
// construido desde la página para no duplicar lógica.
// Se conecta con: pagina_busqueda.dart (padre) + contenedor_vidrio.
// Parte del flujo: búsqueda (diseño de escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';

/// Layout de escritorio de la búsqueda (panel centrado).
class BusquedaEscritorio extends StatelessWidget {
  final Widget barra;
  final Widget chips;
  final Widget cuerpo;

  const BusquedaEscritorio({
    super.key,
    required this.barra,
    required this.chips,
    required this.cuerpo,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = ColoresApp.enSuperficie(esOscuro);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.spacingXL, vertical: r.spacingL),
          child: ContenedorVidrio(
            borderRadius: 20,
            borderColor: onBg.withValues(alpha: 0.08),
            bgColor: onBg.withValues(alpha: 0.02),
            padding: EdgeInsets.all(r.spacingM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                barra,
                SizedBox(height: r.spacingS),
                chips,
                SizedBox(height: r.spacingXS),
                Expanded(child: cuerpo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}