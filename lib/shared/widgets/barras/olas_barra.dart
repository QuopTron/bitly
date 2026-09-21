// ─────────────────────────────────────────────────────────────
// olas_barra.dart — El borde ONDULADO de una barra: el camino de la ola,
// el recorte y el trazo que la sigue.
//
// Va aparte de barra_adornada.dart para que cada archivo haga una sola cosa:
// este sabe dibujar la ola, el otro decide cuándo usarla y le suma la
// calcomanía. El recorte y el trazo COMPARTEN el mismo camino, por eso
// coinciden exactamente y el contorno no queda como una línea recta cruzada.
//
// Se conecta con: barra_adornada (lo usa).
// Parte del flujo: presentación (navbar y miniplayer).
// ─────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// El camino del borde ondulado: sube por el costado, ondula arriba y baja.
Path caminoOlas(Size size, int olas) {
  final n = math.max(2, olas);
  final amp = size.height * 0.075;
  final base = size.height * 0.11;
  final paso = size.width / n;
  final p =
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, base);
  for (var i = 0; i < n; i++) {
    final x0 = paso * i;
    p.quadraticBezierTo(x0 + paso * 0.5, base - amp * 1.6, x0 + paso, base);
  }
  p
    ..lineTo(size.width, size.height)
    ..close();
  return p;
}

/// Recorta la barra con el borde de arriba ondulado.
class ClipperOlas extends CustomClipper<Path> {
  final int olas;
  const ClipperOlas(this.olas);

  @override
  Path getClip(Size size) => caminoOlas(size, olas);

  @override
  bool shouldReclip(ClipperOlas oldClipper) => oldClipper.olas != olas;
}

/// Pinta el trazo que sigue la ola, pegado a su borde de arriba.
class PintorOlas extends CustomPainter {
  final int olas;
  final Color color;
  const PintorOlas(this.olas, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final camino = caminoOlas(size, olas);
    // Se recorta el trazo a una franja superior: así solo se ve la ola y no
    // los costados.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.22));
    canvas.drawPath(
      camino,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorOlas old) => old.olas != olas || old.color != color;
}
