// ─────────────────────────────────────────────────────────────
// paleta_portada.dart — Extrae la paleta de colores de la carátula
// (vibrante + dominante) para pintar el karaoke de letras con los
// colores del arte. El contraste WCAG vive en
// paleta_portada_contraste.dart y el cálculo en
// paleta_portada_calculo.dart.
// Se conecta con: hoja de letras (karaoke) + widgets de video.
// Parte del flujo: reproductor (letras karaoke).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/imagen_portada.dart' show esUrlLocal;

part 'paleta_portada_contraste.dart';
part 'paleta_portada_calculo.dart';

/// Paleta derivada de la carátula, usada para colorear las líneas de karaoke.
class PaletaPortada {
  /// Color más saturado / vivo de la carátula.
  final Color vibrante;

  /// Color dominante (promedio) de la carátula.
  final Color dominante;

  /// True cuando el arte es brillante (fondo claro).
  final bool esPortadaClara;

  const PaletaPortada({
    required this.vibrante,
    required this.dominante,
    required this.esPortadaClara,
  });

  /// Devuelve [vibrante] ajustado para contraste contra una superficie
  /// oscura o clara (el panel real del karaoke). [fondo] es el color real
  /// detrás del texto; si es null se asume el panel por defecto.
  Color acentoTexto({required bool sobreSuperficieOscura, Color? fondo}) {
    final bg = fondo ??
        (sobreSuperficieOscura
            ? const Color(0xFF141414)
            : const Color(0xFFF6F6F6));
    final hsl = HSLColor.fromColor(vibrante);
    // Satura un poco para que la identidad de la portada sobreviva el fix.
    final vivo =
        hsl.withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0)).toColor();
    // Mínimo duro para la línea activa — siempre debe resaltar.
    return garantizarContraste(vivo, bg, ratioMin: 4.5);
  }

  /// Atenúa [acentoTexto] para las líneas siguientes a la activa: se leen
  /// como un degradado suave del acento que vuelve al neutro con la
  /// distancia. Cada color intermedio es verificado contra [fondo].
  Color acentoSiguienteLinea({
    required bool sobreSuperficieOscura,
    required int distancia,
    Color? fondo,
  }) {
    final bg = fondo ??
        (sobreSuperficieOscura
            ? const Color(0xFF141414)
            : const Color(0xFFF6F6F6));
    final acento =
        acentoTexto(sobreSuperficieOscura: sobreSuperficieOscura, fondo: bg);
    final base = mejorNeutro(bg);
    final fuerza = (1.12 - distancia * 0.20).clamp(0.18, 0.82);
    final mezclado = Color.lerp(base, acento, fuerza)!;
    // Líneas siguientes: 3.0:1 es suficiente, nunca por debajo del piso.
    return garantizarContraste(mezclado, bg, ratioMin: 3.0);
  }
}

/// Caché en memoria: re-entrar a letras de la misma carátula es instantáneo.
final Map<String, Future<PaletaPortada?>> _cachePaleta = {};

/// Obtiene (o calcula) la paleta para una carátula por URL o ruta local.
Future<PaletaPortada?> paletaParaPortada(String? urlORuta) async {
  if (urlORuta == null || urlORuta.isEmpty) return null;
  final clave = 'cover|$urlORuta';
  return _cachePaleta.putIfAbsent(clave, () => _extraer(urlORuta));
}

Future<PaletaPortada?> _extraer(String src) async {
  try {
    final bytes = await _leerBytes(src);
    if (bytes == null) return null;
    return await _calcularDesdeBytes(bytes);
  } catch (_) {
    return null;
  }
}