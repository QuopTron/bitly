// tutorial_overlay_spotlight.dart — Pintado del "spotlight": capa oscura que
// cubre la pantalla con un agujero redondeado sobre el widget explicado.
//
// Si no hay objetivo (el paso habla de algo que vive en otra vista) solo se
// pinta el fondo oscurecido: el tooltip va centrado y el paso se explica igual.
//
// Se conecta con: tutorial_overlay (lo instancia y le pasa el rect objetivo).
// Parte del flujo: tutorial interactivo (capa 1 del overlay).
part of 'tutorial_overlay.dart';

class _PintorSpotlight extends CustomPainter {
  /// Rect del widget explicado en coordenadas globales, o null.
  final Rect? objetivo;

  /// 0..1 del latido del borde (viene del AnimationController del overlay).
  final double pulso;

  const _PintorSpotlight({required this.objetivo, required this.pulso});

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    final hole = objetivo?.inflate(8);

    // Fondo: la app se ve por detrás, apagada, para que el foco sea el widget.
    final fondo =
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.72);
    if (hole == null) {
      canvas.drawRect(area, fondo);
      return;
    }

    // Sin agujero no hay nada que mirar; con agujero se recorta el fondo.
    final recorte = RRect.fromRectAndRadius(hole, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(area),
        Path()..addRRect(recorte),
      ),
      fondo,
    );

    // Halo: se abre y cierra con el latido, y marca "esto es lo que importa".
    final halo = 0.12 + pulso * 0.16;
    canvas.drawRRect(
      recorte,
      Paint()
        ..color = const Color(0xFF1DB954).withValues(alpha: halo)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 + pulso * 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Borde nítido encima del halo (le da definición al agujero).
    canvas.drawRRect(
      recorte,
      Paint()
        ..color = const Color(0xFF1DB954).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorSpotlight old) =>
      old.objetivo != objetivo || old.pulso != pulso;
}
