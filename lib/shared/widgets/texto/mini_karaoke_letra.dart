// ─────────────────────────────────────────────────────────────
// mini_karaoke_letra.dart — Tira compacta del karaoke TRADUCIDO.
//
// Muestra la traducción de la línea que se está cantando con el mismo
// barrido que la letra grande (lo ya cantado encendido, lo que falta
// tenue) y, debajo, la traducción de la siguiente línea para poder
// leer adelantado sin ocupar la letra original.
//
// Por qué un widget aparte: el modal del karaoke tiene la letra
// sincronizada grande; esto es el "mini karaoke" de abajo, que sigue el
// MISMO tiempo (incluido el retraso de 0.5s del modal). Al ser público
// se puede testear sin montar el reproductor: que el texto no se
// recorte y que el barrido encienda lo cantado.
//
// Se conecta con: features/reproductor/letras/hoja_letras_traduccion.dart.
// Parte del flujo: reproductor → letras (traducción).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Mini karaoke de una línea traducida (+ la siguiente, opcional).
class MiniKaraokeLetra extends StatelessWidget {
  /// Traducción de la línea ACTIVA (null si esa línea no tiene texto).
  final String? actual;

  /// Traducción de la línea siguiente, en tono bajo (null = no hay).
  final String? siguiente;

  /// Avance de la línea activa (0..1). Es el mismo progreso que usa la letra
  /// grande, así que el barrido va en sincronía.
  final double progreso;

  /// Color de lo ya cantado y de lo que falta.
  final Color brillo;
  final Color tenue;

  /// Color del texto de la línea siguiente.
  final Color siguienteColor;

  /// Tamaño de la línea activa (la siguiente sale un escalón más chica).
  final double tamanoFuente;

  const MiniKaraokeLetra({
    super.key,
    required this.actual,
    required this.siguiente,
    required this.progreso,
    required this.brillo,
    required this.tenue,
    required this.siguienteColor,
    this.tamanoFuente = 13,
  });

  @override
  Widget build(BuildContext context) {
    final texto = actual;
    if ((texto == null || texto.trim().isEmpty) &&
        (siguiente == null || siguiente!.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    // CENTRADO, igual que la letra grande: la tira es la misma lectura en otro
    // idioma, así que no tiene sentido que una vaya centrada y la otra no.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (texto != null && texto.trim().isNotEmpty)
          Text.rich(
            _spanBarrido(texto),
            textAlign: TextAlign.center,
            // Sin recorte: si la traducción es larga, envuelve entera.
            softWrap: true,
            style: TextStyle(fontSize: tamanoFuente, height: 1.25),
          ),
        if (siguiente != null && siguiente!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              siguiente!,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                color: siguienteColor,
                fontSize: tamanoFuente - 1,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }

  /// Parte la línea en "ya cantado" (encendido) y "falta" (tenue), en la misma
  /// proporción de texto que el avance de la línea.
  InlineSpan _spanBarrido(String texto) {
    final pintado = (texto.length * progreso).round().clamp(0, texto.length);
    return TextSpan(
      children: [
        TextSpan(
          text: texto.substring(0, pintado),
          style: TextStyle(color: brillo, fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text: texto.substring(pintado),
          style: TextStyle(color: tenue, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
