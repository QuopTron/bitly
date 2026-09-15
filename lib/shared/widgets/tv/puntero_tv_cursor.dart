// ─────────────────────────────────────────────────────────────
// puntero_tv_cursor.dart — Widget visual del cursor de TV.
//
// Qué hace: dibuja un círculo blanco con borde oscuro (para que se
// vea sobre cualquier fondo) y un punto verde que se contrae al
// hacer clic como feedback visual. El cursor es solo dibujo: nunca
// intercepta eventos (IgnorePointer), los eventos los manda el
// estado del puntero.
//
// Se conecta con: puntero_tv.dart (lo posiciona con Positioned).
// Parte del flujo: entrada de usuario en TV.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'puntero_tv.dart';

/// El cursor: aro blanco con borde oscuro y punto verde que se contrae
/// al hacer clic, como feedback.
class CursorTv extends StatelessWidget {
  final bool presionando;

  const CursorTv({super.key, required this.presionando});

  static const Color _verde = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final lado = PunteroTv.radio * 2;
    return AnimatedScale(
      scale: presionando ? 0.82 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: presionando ? 0.9 : 0.72),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.55),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _verde,
            ),
          ),
        ),
      ),
    );
  }
}
