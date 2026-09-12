// tutorial_overlay_capas.dart — PART de tutorial_overlay.dart: las tres capas
// visuales del tutorial, de abajo hacia arriba:
//
//   1. Fondo oscurecido con el AGUJERO sobre el widget explicado (el halo late
//      para marcar "mirá acá") y un bloqueo de toques para lo de atrás.
//   2. La tarjeta que explica el paso.
//   3. La pastilla para salir de todo el tutorial, siempre a mano.
//
// Se separó del estado para que cada archivo quede corto y se entienda de un
// vistazo qué se dibuja y en qué orden.
//
// Se conecta con: tutorial_overlay_estado (lo instancia), tutorial_overlay_tooltip
// (capa 2), tutorial_overlay_saltar (capa 3) y tutorial_overlay_spotlight (capa 1).
// Parte del flujo: tutorial interactivo (composición visual).
part of 'tutorial_overlay.dart';

class _CapasTutorial extends StatelessWidget {
  /// Fade de entrada del paso.
  final Animation<double> fade;

  /// Latido del borde del agujero.
  final Animation<double> pulso;

  final TutorialController controller;

  /// Rect del widget explicado, o null si no está montado.
  final Rect? objetivo;

  final bool esOscuro;

  const _CapasTutorial({
    required this.fade,
    required this.pulso,
    required this.controller,
    required this.objetivo,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final paso = controller.pasoActual!;
    return FadeTransition(
      opacity: fade,
      child: Stack(
        children: [
          // Capa 1: fondo oscurecido + agujero sobre el objetivo (si está).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // bloquea la interacción con lo de atrás
              child: AnimatedBuilder(
                animation: pulso,
                builder:
                    (context, _) => CustomPaint(
                      painter: _PintorSpotlight(
                        objetivo: objetivo,
                        pulso: pulso.value,
                      ),
                    ),
              ),
            ),
          ),

          // Capa 2: la tarjeta que explica el paso.
          _TooltipTutorial(
            paso: paso,
            objetivo: objetivo,
            pantalla: MediaQuery.sizeOf(context),
            controller: controller,
            esOscuro: esOscuro,
          ),

          // Capa 3: salir del tutorial entero, siempre a mano.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: _BotonSaltarTodo(controller: controller),
          ),
        ],
      ),
    );
  }
}
