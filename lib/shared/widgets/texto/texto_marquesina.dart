// ─────────────────────────────────────────────────────────────
// texto_marquesina.dart — Muestra un texto de UNA línea y, si no
// entra en el ancho disponible, lo desplaza de izquierda a derecha
// (ping-pong) para que se lea completo.
//
// Por qué existe: el karaoke cortaba las líneas largas con "…", así
// que la parte final de la letra —que el artista SÍ canta— no se veía
// nunca. Esto la muestra entera sin romper la altura fija de la línea.
//
// El estilo efectivo sale del DefaultTextStyle heredado mezclado con
// `estilo`: el mismo TextStyle se usa para medir y para pintar, así el
// cálculo de desborde coincide con lo que se ve.
//
// Coste: solo anima cuando hay desborde Y el dueño lo pide (`activo`),
// así que como máximo hay un ticker vivo a la vez.
//
// Se conecta con: hoja_letras (línea karaoke activa) y cualquier texto
// de una línea que pueda desbordar.
// Parte del flujo: reproductor (letras sincronizadas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

part 'texto_marquesina_estado.dart';

/// Texto de una línea que se desplaza si no entra en su caja.
class TextoMarquesina extends StatefulWidget {
  /// Texto (o spans con estilos por palabra) a mostrar.
  final InlineSpan span;

  /// Estilo base aplicado al conjunto (se mezcla con el heredado).
  final TextStyle estilo;

  /// Si false, el texto se pinta quieto (y recortado si desborda).
  final bool activo;

  /// Velocidad del desplazamiento en píxeles por segundo.
  final double velocidad;

  /// Pausa en cada extremo antes de volver.
  final Duration pausa;

  /// Aire al final para que la última palabra no quede pegada al borde.
  final double margenFinal;

  const TextoMarquesina({
    super.key,
    required this.span,
    this.estilo = const TextStyle(),
    this.activo = true,
    this.velocidad = 34,
    this.pausa = const Duration(milliseconds: 900),
    this.margenFinal = 28,
  });

  @override
  State<TextoMarquesina> createState() => _TextoMarquesinaState();
}

