// tutorial_overlay_tarjeta.dart — PART de tutorial_overlay.dart: el contenido
// de la tarjeta del tutorial (icono, título, descripción, progreso y botones).
//
// CLAVE: las ACCIONES (saltar paso, atrás, siguiente) quedan FUERA del área
// que se desplaza y SIEMPRE visibles. Antes iban dentro del scroll, y en
// celulares con el tamaño de fuente del sistema aumentado la tarjeta se
// quedaba sin alto: el botón "Siguiente" caía más abajo del pliegue y el
// tutorial no se podía avanzar. El texto puede desplazarse; para avanzar no.
//
// La fila de acciones además usa Wrap: si el texto del sistema es tan grande
// que los tres botones no entran en un renglón, se apilan en vez de desbordar.
//
// Se conecta con: tutorial_overlay_tooltip (la coloca) + tutorial_overlay_botones.
// Parte del flujo: tutorial interactivo (contenido de la capa 2).
part of 'tutorial_overlay.dart';

/// La tarjeta en sí: icono, título, descripción, progreso y acciones.
class _TarjetaPaso extends StatelessWidget {
  final TutorialPaso paso;
  final TutorialController controller;
  final bool esOscuro;
  final bool avisarOtraVista;

  const _TarjetaPaso({
    required this.paso,
    required this.controller,
    required this.esOscuro,
    required this.avisarOtraVista,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context).tutorialInteractivo;
    final esUltimo = controller.indiceActual >= controller.totalPasos - 1;

    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.superficie(esOscuro),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _verdeTutorial.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: esOscuro ? 0.55 : 0.2),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lo que SÍ puede desplazarse: la explicación y el progreso. Si el
            // alto disponible es corto (celu con fuente grande), se lee
            // scrolleando sin romper nada.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono, título y descripción del paso.
                    _CabeceraPaso(
                      paso: paso,
                      esOscuro: esOscuro,
                      avisarOtraVista: avisarOtraVista,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                      child: Row(
                        children: [
                          Text(
                            '${controller.indiceActual + 1}/${controller.totalPasos}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ColoresApp.enSuperficieTenue(esOscuro),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value:
                                    (controller.indiceActual + 1) /
                                    controller.totalPasos,
                                minHeight: 3,
                                backgroundColor: ColoresApp.borde(esOscuro),
                                valueColor: const AlwaysStoppedAnimation(
                                  _verdeTutorial,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Las acciones NUNCA se desplazan: son la única forma de avanzar.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _BotonTexto(
                      etiqueta: loc.skipStep,
                      esOscuro: esOscuro,
                      onTap: controller.siguiente,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Flecha "atrás": solo cuando hay a dónde volver.
                        if (controller.indiceActual > 0) ...[
                          _BotonFlecha(
                            icono: Icons.arrow_back_rounded,
                            tooltip: loc.back,
                            esOscuro: esOscuro,
                            onTap: controller.anterior,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _BotonPrincipal(
                          etiqueta: esUltimo ? loc.gotIt : loc.next,
                          esOscuro: esOscuro,
                          esUltimo: esUltimo,
                          onTap:
                              esUltimo
                                  ? controller.completar
                                  : controller.siguiente,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
