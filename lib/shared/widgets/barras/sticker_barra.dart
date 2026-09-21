// ─────────────────────────────────────────────────────────────
// sticker_barra.dart — La CALCOMANÍA de una barra: el detalle que algunos
// diseños del cofre le ponen encima al navbar y al miniplayer.
//
// El modelo guarda solo un id ('destello', 'nota'...), así que el ícono se
// resuelve acá: el catálogo sigue siendo puro y un id desconocido no rompe
// nada (se dibuja sin calcomanía).
//
// Va pequeña y con el color del diseño: es un detalle, no un protagonista, y
// no puede tapar los controles de la barra.
//
// Se conecta con: barra_adornada (la dibuja) + catalogo_disenos_barra (los
// ids) + el cofre de Ajustes (la muestra en su tarjeta).
// Parte del flujo: presentación (navbar y miniplayer).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Ícono de una calcomanía por su id (null si el id no es de nadie).
IconData? stickerIcono(String id) {
  switch (id) {
    case 'destello':
      return Icons.auto_awesome_rounded;
    case 'nota':
      return Icons.music_note_rounded;
    default:
      return null;
  }
}

/// La calcomanía que se dibuja encima de una barra.
class StickerBarra extends StatelessWidget {
  /// Id de la calcomanía (ver stickerIcono).
  final String id;

  /// Color con el que se pinta.
  final Color color;

  /// Tamaño del ícono; la muestra del cofre la usa más chica.
  final double tamano;

  const StickerBarra({
    super.key,
    required this.id,
    required this.color,
    this.tamano = 15,
  });

  @override
  Widget build(BuildContext context) {
    final icono = stickerIcono(id);
    if (icono == null) return const SizedBox.shrink();
    return Icon(
      icono,
      size: tamano,
      color: color,
      shadows: [
        Shadow(color: color.withValues(alpha: 0.55), blurRadius: tamano * 0.8),
      ],
    );
  }
}
