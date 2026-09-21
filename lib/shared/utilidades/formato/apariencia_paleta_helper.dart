// ─────────────────────────────────────────────────────────────
// apariencia_paleta_helper.dart — PINTURA de una paleta del cofre: el
// gradiente con el que se tiñe una barra y el color de su contorno.
//
// Va aparte de apariencia_barras_helper.dart (que resuelve QUÉ paleta está
// puesta) para que cada archivo haga una sola cosa: este es solo el cálculo
// de color, sin saber de preferencias ni de contextos.
//
// Se conecta con: barra_navegacion_flotante + miniplayer (pintan con esto) y
// apariencia_barras_helper (le pasa los colores ya resueltos).
// Parte del flujo: presentación (navbar y miniplayer).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Pintura de las paletas del cofre.
class AparienciaPaleta {
  AparienciaPaleta._();

  /// Intensidad con la que la paleta se mezcla sobre el fondo. En oscuro
  /// aguanta más color sin ensuciar el texto; en claro se pide menos.
  static const _tinteOscuro = 0.50;
  static const _tinteClaro = 0.30;

  /// Gradiente de una barra con su paleta, o null si no hay paleta (la barra
  /// queda exactamente como está hoy).
  ///
  /// Se arma MEZCLANDO la paleta sobre [base] (el color real del fondo),
  /// nunca reemplazándolo: así el texto sigue legible en tema claro y oscuro
  /// y la barra no pierde su carácter de vidrio. El último color entra más
  /// tenue para que la barra "respire" hacia su final.
  static LinearGradient? gradiente(
    List<Color> paleta, {
    required bool esOscuro,
    required Color base,
    AlignmentGeometry desde = Alignment.centerLeft,
    AlignmentGeometry hasta = Alignment.centerRight,
  }) {
    if (paleta.isEmpty) return null;
    final intensidad = esOscuro ? _tinteOscuro : _tinteClaro;
    Color mezclar(Color c, double factor) =>
        Color.alphaBlend(c.withValues(alpha: intensidad * factor), base);
    if (paleta.length == 1) {
      return LinearGradient(
        begin: desde,
        end: hasta,
        colors: [mezclar(paleta.first, 1), mezclar(paleta.first, 0.45)],
      );
    }
    return LinearGradient(
      begin: desde,
      end: hasta,
      colors: [
        for (var i = 0; i < paleta.length; i++)
          mezclar(paleta[i], 1 - i * 0.25),
      ],
    );
  }

  /// Color del contorno de la barra cuando hay paleta (si no, el contorno lo
  /// decide el trazo elegido). El GROSOR sigue siendo el del usuario.
  static Color? borde(List<Color> paleta, {required bool esOscuro}) =>
      paleta.isEmpty
          ? null
          : paleta.first.withValues(alpha: esOscuro ? 0.55 : 0.40);
}
