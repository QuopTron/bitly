// tutorial_overlay_cabecera.dart — PART de tutorial_overlay.dart: icono, título
// y descripción del paso, más el aviso de "lo verás al abrirlo" cuando la
// función vive en otra vista.
//
// Se conecta con: tutorial_overlay_tarjeta (la coloca) y l10n (textos ES/EN).
// Parte del flujo: tutorial interactivo (encabezado de la capa 2).
part of '../../tutorial_overlay.dart';

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
    // La cabecera mide por aparato: en la tele el ícono y los textos crecen.
    final r = Responsive(context);
    final esp = EspecificacionesPlataforma.de(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.sobre(18, 28),
        r.spacingL,
        r.sobre(18, 28),
        r.spacingM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paso.icono != null) ...[
            Container(
              padding: EdgeInsets.all(r.spacingM),
              decoration: BoxDecoration(
                color: _verdeTutorial.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(esp.radioTarjeta),
              ),
              child: Icon(
                paso.icono,
                size: esp.iconoAccion,
                color: _verdeTutorial,
              ),
            ),
            SizedBox(width: r.spacingM),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso.titulo,
                  style: TextStyle(
                    fontSize: r.sobre(16.5, 24),
                    fontWeight: FontWeight.w700,
                    color: ColoresApp.enSuperficie(esOscuro),
                  ),
                ),
                SizedBox(height: r.spacingS),
                Text(
                  paso.descripcion,
                  style: TextStyle(
                    fontSize: r.sobre(13.5, 20),
                    height: 1.4,
                    color: ColoresApp.enSuperficieApagado(esOscuro),
                  ),
                ),
                if (avisarOtraVista) ...[
                  SizedBox(height: r.spacingM),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: r.sobre(13, 19),
                        color: ColoresApp.enSuperficieTenue(esOscuro),
                      ),
                      SizedBox(width: r.spacingS),
                      Flexible(
                        child: Text(
                          loc.verEnOtraVista,
                          style: TextStyle(
                            fontSize: r.sobre(11.5, 17),
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
