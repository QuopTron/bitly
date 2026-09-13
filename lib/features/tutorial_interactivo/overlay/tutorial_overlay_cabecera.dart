// tutorial_overlay_cabecera.dart — PART de tutorial_overlay.dart: icono, título
// y descripción del paso, más el aviso de "lo verás al abrirlo" cuando la
// función vive en otra vista.
//
// Se conecta con: tutorial_overlay_tarjeta (la coloca) y l10n (textos ES/EN).
// Parte del flujo: tutorial interactivo (encabezado de la capa 2).
part of 'tutorial_overlay.dart';

/// Encabezado de la tarjeta: icono, título, descripción y aviso opcional.
class _CabeceraPaso extends StatelessWidget {
  final TutorialPaso paso;
  final bool esOscuro;
  final bool avisarOtraVista;

  const _CabeceraPaso({
    required this.paso,
    required this.esOscuro,
    required this.avisarOtraVista,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).tutorialInteractivo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paso.icono != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _verdeTutorial.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(paso.icono, size: 20, color: _verdeTutorial),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso.titulo,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.enSuperficie(esOscuro),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  paso.descripcion,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: ColoresApp.enSuperficieApagado(esOscuro),
                  ),
                ),
                if (avisarOtraVista) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: ColoresApp.enSuperficieTenue(esOscuro),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          loc.verEnOtraVista,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: ColoresApp.enSuperficieTenue(esOscuro),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
