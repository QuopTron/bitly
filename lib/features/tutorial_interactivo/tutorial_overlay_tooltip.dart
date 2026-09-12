// tutorial_overlay_tooltip.dart — PART de tutorial_overlay.dart: la tarjeta que
// explica cada paso, con su flecha y sus botones.
//
// La flecha va con relleno de la tarjeta y BORDE verde a juego con el halo del
// agujero: sin el borde se perdía contra el fondo oscurecido y no se veía.
//
// Sin overflows: el alto lo impone el layout (Positioned con top Y bottom) y el
// contenido de la tarjeta se desplaza si no entra, así que nunca se sale de
// pantalla. La posición la decide `ubicarTarjeta` (ver
// tutorial_overlay_ubicacion.dart).
//
// Se conecta con: tutorial_overlay (la monta), tutorial_overlay_tarjeta (el
// contenido de la tarjeta) y l10n (textos ES/EN).
// Parte del flujo: tutorial interactivo (capa 2 del overlay).
part of 'tutorial_overlay.dart';

class _TooltipTutorial extends StatelessWidget {
  final TutorialPaso paso;
  final Rect? objetivo;
  final Size pantalla;
  final TutorialController controller;
  final bool esOscuro;

  const _TooltipTutorial({
    required this.paso,
    required this.objetivo,
    required this.pantalla,
    required this.controller,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = math.min(
      pantalla.width - 32,
      pantalla.width > 700 ? 400.0 : 344.0,
    );
    final ubic = ubicarTarjeta(
      objetivo: objetivo,
      pantalla: pantalla,
      inset: MediaQuery.paddingOf(context),
      ancho: ancho,
    );

    // Centrada: la función vive en otra vista (reproductor, descargas,
    // Premium) o el objetivo ocupa toda la pantalla.
    if (ubic.lado == LadoTarjeta.centrada) {
      return Positioned.fill(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SizedBox(
                width: ubic.ancho,
                child: _tarjeta(avisarOtraVista: objetivo == null),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: ubic.izquierda,
      top: ubic.arriba,
      // El borde opuesto fija el alto disponible: el layout se encarga de
      // que la tarjeta nunca se salga (su contenido se desplaza si no entra).
      bottom: ubic.abajo,
      width: ubic.ancho,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ubic.flechaArriba)
            _Flecha(
              desplazamiento: ubic.punta,
              esOscuro: esOscuro,
              haciaArriba: true,
            ),
          Flexible(child: _tarjeta(avisarOtraVista: false)),
          if (!ubic.flechaArriba)
            _Flecha(
              desplazamiento: ubic.punta,
              esOscuro: esOscuro,
              haciaArriba: false,
            ),
        ],
      ),
    );
  }

  Widget _tarjeta({required bool avisarOtraVista}) {
    return Material(
      color: Colors.transparent,
      child: _TarjetaPaso(
        paso: paso,
        controller: controller,
        esOscuro: esOscuro,
        avisarOtraVista: avisarOtraVista,
      ),
    );
  }
}
