// tutorial_overlay_flecha.dart — PART de tutorial_overlay.dart: la flechita que
// une la tarjeta con el widget que está explicando.
//
// Va con relleno del color de la tarjeta y BORDE verde a juego con el halo del
// agujero: así se ve contra el fondo oscurecido (antes eran del mismo tono que
// la tarjeta y no se distinguían).
//
// Se conecta con: tutorial_overlay_tooltip (la coloca) y tutorial_overlay_ubicacion
// (le pasa el corrimiento y hacia dónde apunta).
// Parte del flujo: tutorial interactivo (capa 2 del overlay).
part of 'tutorial_overlay.dart';

/// Flechita que une la tarjeta con el widget apuntado. [haciaArriba] la
/// orienta: la tarjeta va debajo del objetivo (apunta al widget) o encima.
/// Lleva borde verde para que se vea contra el fondo oscurecido.
class _Flecha extends StatelessWidget {
  final double desplazamiento;
  final bool esOscuro;
  final bool haciaArriba;

  const _Flecha({
    required this.desplazamiento,
    required this.esOscuro,
    required this.haciaArriba,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: desplazamiento,
        top: haciaArriba ? 0 : 2,
        bottom: haciaArriba ? 2 : 0,
      ),
      child: CustomPaint(
        size: const Size(26, 12),
        painter: _PintorFlecha(
          relleno: ColoresApp.superficie(esOscuro),
          borde: _verdeTutorial,
          haciaArriba: haciaArriba,
        ),
      ),
    );
  }
}

class _PintorFlecha extends CustomPainter {
  final Color relleno;
  final Color borde;
  final bool haciaArriba;

  const _PintorFlecha({
    required this.relleno,
    required this.borde,
    required this.haciaArriba,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Punta en el centro de un borde y base en el opuesto; el flip cambia
    // qué borde lleva la punta.
    final puntaY = haciaArriba ? 0.0 : size.height;
    final baseY = haciaArriba ? size.height : 0.0;
    final triangulo =
        Path()
          ..moveTo(size.width / 2, puntaY)
          ..lineTo(size.width, baseY)
          ..lineTo(0, baseY)
          ..close();
    canvas.drawPath(triangulo, Paint()..color = relleno);
    canvas.drawPath(
      triangulo,
      Paint()
        ..color = borde.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorFlecha old) =>
      old.relleno != relleno ||
      old.borde != borde ||
      old.haciaArriba != haciaArriba;
}
