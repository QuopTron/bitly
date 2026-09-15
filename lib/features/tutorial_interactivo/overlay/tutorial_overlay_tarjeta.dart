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
  Widget build(BuildContext context) => _construirTarjetaPaso(
        context, paso, controller, esOscuro, avisarOtraVista);

}
