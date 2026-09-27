// ─────────────────────────────────────────────────────────────
// settings_sheet_appearance_estilo_previa_panel.dart — PART de
// settings_sheet_new.dart: los paneles de la vista previa. Pintan las MISMAS
// cuentas que las superficies reales (el tinte acomodado a las letras del tema
// que hace `EstiloHelper.fondoDeCover`), por eso el panel no miente.
//
// Un panel pinta, en miniatura, lo que hace una zona en la app:
//   [apagaArte] true  → la carátula se va y el color del cover entra
//                       (fondos principal, del reproductor y modales),
//   [apagaArte] false → la carátula queda debajo y encima entra el
//                       tinte (así quedaron los fondos de las cards).
// Y `_MiniCardPrevia` dibuja una tarjeta de canción con su borde y su
// tinte, para la zona "cards de canción".
//
// Se conecta con: estilo_helper (la intensidad, 1:1) + settings_sheet_appearance_
// estilo_previa.dart (los monta) + ..._estilo_previa_card.dart (la mini
// tarjeta y la carátula de ejemplo).
// Parte del flujo: Ajustes → Apariencia → Estilo con cover.
// ─────────────────────────────────────────────────────────────

part of '../../../settings_sheet_new.dart';

/// Un panel de la vista previa: arte + velo + tinte del color del cover.
class _PanelPrevia extends StatelessWidget {
  final String titulo;
  final double nivel;
  final double velo;
  final bool apagaArte;
  final bool conMiniCard;
  final Color acento;
  final Widget arte;
  final bool esOscuro;
  final Color onBg;
  final Responsive r;

  const _PanelPrevia({
    required this.titulo,
    required this.nivel,
    required this.velo,
    required this.apagaArte,
    required this.acento,
    required this.arte,
    required this.esOscuro,
    required this.onBg,
    required this.r,
    this.conMiniCard = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: (r.height * 0.055).clamp(52.0, 88.0),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: ColoresApp.superficie(esOscuro)),
                // La carátula: se apaga con la intensidad en los fondos y se
                // queda (tapada por el tinte) en las cards.
                if (apagaArte)
                  AtenuadoPorNivel(
                    opacidad: 1 - nivel,
                    // La carátula se va DESENFOCANDO con la intensidad, igual
                    // que en los fondos reales: el panel no miente.
                    child: DesenfoqueHijo(
                      sigma: EstiloHelper.sigmaPorNivel(6, nivel),
                      tope: EstiloHelper.topeSigma(6),
                      child: arte,
                    ),
                  )
                else
                  arte,
                if (conMiniCard)
                  Padding(
                    padding: EdgeInsets.all(r.spacingXS),
                    child: _MiniCardPrevia(
                      nivel: nivel,
                      acento: acento,
                      arte: arte,
                      esOscuro: esOscuro,
                      r: r,
                    ),
                  ),
                // Velo del tema sobre el arte (legibilidad), que se abre a
                // medida que entra el tinte: es el mismo papel que cumple en
                // los fondos reales, y por eso va con el color de superficie
                // y no con el del texto.
                ColoredBox(
                  color: ColoresApp.superficie(
                    esOscuro,
                  ).withValues(alpha: velo * (1 - nivel)),
                ),
                if (nivel > 0)
                  AtenuadoPorNivel(
                    opacidad: nivel,
                    // El color del cover con presencia Y acomodado a las letras
                    // del tema, igual que en las vistas reales
                    // (`EstiloHelper.fondoDeCover`): así el panel no miente
                    // sobre el efecto —antes mostraba un tinte más claro que el
                    // que termina pintando el reproductor—.
                    child: ColoredBox(
                      color: EstiloHelper.fondoDeCover(
                        acento,
                        ColoresApp.superficie(esOscuro),
                        ColoresApp.enSuperficie(esOscuro),
                        mezcla: apagaArte ? 0.58 : 0.55,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.footerSize - 3,
            color: onBg.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
