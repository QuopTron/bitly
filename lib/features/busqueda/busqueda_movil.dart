// ─────────────────────────────────────────────────────────────
// busqueda_movil.dart — Variante móvil de la búsqueda: columna
// full-width con la barra de búsqueda (selector de fuente dentro),
// los chips de categoría y el cuerpo (resultados/recientes/pegar
// URL) dentro de un panel de vidrio. Todo el contenido viene
// construido desde la página para no duplicar lógica.
// Se conecta con: pagina_busqueda.dart (padre) + contenedor_vidrio.
// Parte del flujo: búsqueda (diseño Android actual).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';

/// Layout móvil de la búsqueda (diseño Android actual).
class BusquedaMovil extends StatelessWidget {
  final Widget barra;
  final Widget chips;
  final Widget cuerpo;

  const BusquedaMovil({
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

    return Column(
      children: [
        SizedBox(height: r.spacingM),
        Expanded(
          child: ContenedorVidrio(
            borderRadius: 16,
            borderColor: onBg.withValues(alpha: 0.06),
            bgColor: onBg.withValues(alpha: 0.02),
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
      ],
    );
  }
}