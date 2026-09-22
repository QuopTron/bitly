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
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../../widgets/tarjetas/portada/imagen_portada.dart' show esUrlLocal;

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
    final bg =
        fondo ??
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
    final bg =
        fondo ??
        (sobreSuperficieOscura
            ? const Color(0xFF141414)
            : const Color(0xFFF6F6F6));
    final acento = acentoTexto(
      sobreSuperficieOscura: sobreSuperficieOscura,
      fondo: bg,
    );
    final base = mejorNeutro(bg);
    final fuerza = (1.12 - distancia * 0.20).clamp(0.18, 0.82);
    final mezclado = Color.lerp(base, acento, fuerza)!;
    // Líneas siguientes: 3.0:1 es suficiente, nunca por debajo del piso.
    return garantizarContraste(mezclado, bg, ratioMin: 3.0);
  }
}

/// Caché en memoria: re-entrar a letras de la misma carátula es instantáneo.
///
/// ACOTADA a propósito: sin límite quedaba una entrada por cada cover visto,
/// así que recorrer el feed en una sesión larga hacía crecer la memoria sin
/// techo (cada entrada retiene su Future y su tamaño de píxeles leídos).
const int _maxPaletas = 48;
final Map<String, Future<PaletaPortada?>> _cachePaleta = {};

/// Obtiene (o calcula) la paleta para una carátula por URL o ruta local.
Future<PaletaPortada?> paletaParaPortada(String? urlORuta) {
  if (urlORuta == null || urlORuta.isEmpty) return Future.value(null);
  final clave = 'cover|$urlORuta';
  final yaPedida = _cachePaleta[clave];
  if (yaPedida != null) return yaPedida;
  if (_cachePaleta.length >= _maxPaletas) {
    // Los Map de Dart conservan el orden de inserción, así que `keys.first`
    // es la más antigua: se descarta esa y no todo el caché.
    _cachePaleta.remove(_cachePaleta.keys.first);
  }
  final futura = _extraer(urlORuta);
  _cachePaleta[clave] = futura;
  return futura;
}

/// Igual que [paletaParaPortada] pero esperando a que el hilo de UI esté libre.
///
/// La usan las TARJETAS: piden la paleta mientras el usuario hace scroll, así
/// que una pasada rápida por una lista larga encola decenas de paletas de golpe
/// y cada una corta el frame en curso. Con esto el trabajo se agenda como tarea
/// ociosa y los frames del scroll van primero (el resultado es el mismo; solo
/// llega un poco después, cuando la tarjeta ya está quieta).
Future<PaletaPortada?> paletaParaPortadaDiferida(String? urlORuta) async {
  if (urlORuta == null || urlORuta.isEmpty) return null;
  // Si YA está en caché es instantáneo: no tiene sentido diferirlo.
  final clave = 'cover|$urlORuta';
  if (_cachePaleta.containsKey(clave)) return paletaParaPortada(urlORuta);
  await _esperarHuecoLibre();
  return paletaParaPortada(urlORuta);
}

/// Espera al hueco ocioso del planificador. Si el scheduler todavía no está
/// listo (tests puros), cae a un salto de microtarea normal.
Future<void> _esperarHuecoLibre() {
  final c = Completer<void>();
  try {
    SchedulerBinding.instance.scheduleTask(() {
      if (!c.isCompleted) c.complete();
    }, Priority.idle);
  } catch (_) {
    if (!c.isCompleted) c.complete();
  }
  return c.future;
}

Future<PaletaPortada?> _extraer(String src) async {
  try {
    final bytes = await _leerBytes(src);
    if (bytes == null) {
      // No se pudo leer: se saca de la caché para que un reintento (o una
      // red que vuelve) no quede clavado con el null para siempre.
      _cachePaleta.remove('cover|$src');
      return null;
    }
    return await _calcularDesdeBytes(bytes);
  } catch (e) {
    debugPrint('[PaletaPortada] $e');
    _cachePaleta.remove('cover|$src');
    return null;
  }
}
