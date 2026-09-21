// ─────────────────────────────────────────────────────────────
// tutorial_overlay_tarjeta_build.dart — PART de tutorial_overlay.dart:
// el `build` de la tarjeta del tutorial — contenedor con borde y
// sombra, bloque desplazable (cabecera del paso + progreso) y fila de
// acciones SIEMPRE visible con Wrap para que no desborde con fuentes
// grandes del sistema.
// Se conecta con: tutorial_overlay.dart (misma library).
// Parte del flujo: tutorial interactivo (contenido de la capa 2).
// ─────────────────────────────────────────────────────────────

part of '../../tutorial_overlay.dart';

Widget _construirTarjetaPaso(
  BuildContext context,
  TutorialPaso paso,
  TutorialController controller,
  bool esOscuro,
  bool avisarOtraVista,
) {
  final loc = AppLocalizations.of(context).tutorialInteractivo;
  final esUltimo = controller.indiceActual >= controller.totalPasos - 1;
  // La tarjeta del tutorial mide por aparato: en la tele crece el radio, el
  // progreso y los aires (se lee a metros).
  final r = Responsive(context);
  final esp = EspecificacionesPlataforma.de(context);
  final radius = BorderRadius.circular(esp.radioHoja * 0.7);

  return Container(
    decoration: BoxDecoration(
      color: ColoresApp.superficie(esOscuro),
      borderRadius: radius,
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
      borderRadius: radius,
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
                    padding: EdgeInsets.fromLTRB(
                      r.sobre(18, 28),
                      0,
                      r.sobre(18, 28),
                      r.spacingS,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${controller.indiceActual + 1}/${controller.totalPasos}',
                          style: TextStyle(
                            fontSize: r.sobre(11.5, 17),
                            fontWeight: FontWeight.w600,
                            color: ColoresApp.enSuperficieTenue(esOscuro),
                          ),
                        ),
                        SizedBox(width: r.spacingM),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              r.spacingXS / 2,
                            ),
                            child: LinearProgressIndicator(
                              value:
                                  (controller.indiceActual + 1) /
                                  controller.totalPasos,
                              minHeight: r.sobre(3, 6),
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
            padding: EdgeInsets.fromLTRB(r.spacingM, 0, r.spacingM, r.spacingM),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: r.spacingS,
                runSpacing: r.spacingS,
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
                        SizedBox(width: r.spacingS),
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
