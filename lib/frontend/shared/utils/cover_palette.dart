import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/cover_image.dart' show isLocalUrl;

// ── WCAG contrast helpers ────────────────────────────────────────────────
// These guarantee text drawn over ANY background (blurred cover + veil)
// stays readable in both dark and light themes.

/// Relative luminance per WCAG 2.x (0 = black, 1 = white).
double relativeLuminance(Color c) {
  double channel(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two colors (1..21).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Returns [color] adjusted (lightness nudged toward the readable side) so it
/// keeps at least [minRatio]:1 contrast against [background]. Preserves hue and
/// saturation as much as possible, so the cover's personality stays.
Color ensureContrast(Color color, Color background, {double minRatio = 4.0}) {
  if (contrastRatio(color, background) >= minRatio) return color;
  final bgLum = relativeLuminance(background);
  final hsl = HSLColor.fromColor(color);
  final goLight = bgLum < 0.5; // dark panel → lighten text
  var lightness = hsl.lightness;
  for (var i = 0; i < 24; i++) {
    if (goLight) {
      lightness = math.min(1.0, lightness + 0.045);
    } else {
      lightness = math.max(0.0, lightness - 0.045);
    }
    final candidate = hsl.withLightness(lightness).toColor();
    if (contrastRatio(candidate, background) >= minRatio) return candidate;
  }
  // Last resort: pure white on dark / pure black on light.
  return goLight ? Colors.white : Colors.black;
}

/// Picks the most readable neutral (white or black) on [background].
Color bestNeutral(Color background) =>
    relativeLuminance(background) < 0.5 ? Colors.white : Colors.black;

/// Palette derived from a song's cover art, used to color the karaoke lines
/// (active line + upcoming lines) with the artwork's own colors instead of a
/// fixed brand color.
class CoverPalette {
  /// Most saturated / vivid color found in the cover.
  final Color vibrant;

  /// Overall dominant (average-ish) color of the cover.
  final Color dominant;

  /// True when the artwork is bright (light background).
  final bool isLightCover;

  const CoverPalette({
    required this.vibrant,
    required this.dominant,
    required this.isLightCover,
  });

  /// Returns [vibrant] adjusted for contrast against a dark or light surface
  /// (karaoke panel uses a translucent dark surface in dark mode and a light
  /// one in light mode).
  ///
  /// [background] is the REAL panel color behind the text (blurred cover +
  /// veil blended). When null, a conservative dark/light panel is assumed.
  Color textAccent({required bool onDarkSurface, Color? background}) {
    final bg = background ??
        (onDarkSurface ? const Color(0xFF141414) : const Color(0xFFF6F6F6));
    final hsl = HSLColor.fromColor(vibrant);
    // Saturate a bit so the cover identity survives the contrast fix.
    final vivid = hsl.withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0)).toColor();
    // Hard minimum for the active line — it must always pop.
    return ensureContrast(vivid, bg, minRatio: 4.5);
  }

  /// Fades [textAccent] for "upcoming" lines: the first lines that follow the
  /// active one read as a soft gradient of the cover's accent, drifting back
  /// to the neutral text color as they get further away. Every intermediate
  /// color is contrast-checked against [background] so nothing fades into the
  /// panel.
  Color accentForNextLine({
    required bool onDarkSurface,
    required int distance,
    Color? background,
  }) {
    final bg = background ??
        (onDarkSurface ? const Color(0xFF141414) : const Color(0xFFF6F6F6));
    final accent = textAccent(onDarkSurface: onDarkSurface, background: bg);
    final base = bestNeutral(bg);
    final strength = (1.12 - distance * 0.20).clamp(0.18, 0.82);
    final blended = Color.lerp(base, accent, strength)!;
    // Upcoming lines are secondary: 3.0:1 is enough, but never let one fall
    // below the readable floor.
    return ensureContrast(blended, bg, minRatio: 3.0);
  }
}

/// In-memory cache so re-entering lyrics for the same cover is instant.
final Map<String, Future<CoverPalette?>> _paletteCache = {};

Future<CoverPalette?> paletteForCover(String? coverUrlOrPath) async {
  if (coverUrlOrPath == null || coverUrlOrPath.isEmpty) return null;
  final key = 'cover|$coverUrlOrPath';
  return _paletteCache.putIfAbsent(key, () => _extract(coverUrlOrPath));
}

Future<CoverPalette?> _extract(String src) async {
  try {
    final bytes = await _readBytes(src);
    if (bytes == null) return null;
    return await _computeFromBytes(bytes);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _readBytes(String src) async {
  if (isLocalUrl(src)) {
    final f = File(src);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }
  final resp = await http
      .get(Uri.parse(src))
      .timeout(const Duration(seconds: 8));
  if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
  return resp.bodyBytes;
}

Future<CoverPalette?> _computeFromBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 96,
    targetHeight: 96,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final pixels = data.buffer.asUint8List();

    var rSum = 0, gSum = 0, bSum = 0, count = 0;
    var vR = 0, vG = 0, vB = 0, vCount = 0;
    var midR = 0, midG = 0, midB = 0, midCount = 0;
    var lumSum = 0.0;

    for (var i = 0; i < pixels.length; i += 4) {
      final a = pixels[i + 3];
      if (a < 200) continue;
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];

      final maxC = _max3(r, g, b);
      final minC = _min3(r, g, b);
      final sat = maxC == 0 ? 0.0 : (maxC - minC) / maxC;
      final lum = (maxC + minC) / (2 * 255.0);
      lumSum += lum;

      rSum += r;
      gSum += g;
      bSum += b;
      count++;

      // "Vibrant": saturated pixels in a readable lightness band.
      if (sat > 0.30 && lum > 0.16 && lum < 0.88) {
        vR += r;
        vG += g;
        vB += b;
        vCount++;
      }
      // Midtones fallback for very desaturated covers.
      if (lum > 0.2 && lum < 0.75) {
        midR += r;
        midG += g;
        midB += b;
        midCount++;
      }
    }

    if (count == 0) return null;

    final dominant = Color.fromARGB(
      255,
      rSum ~/ count,
      gSum ~/ count,
      bSum ~/ count,
    );

    Color vibrant;
    if (vCount > count * 0.03) {
      vibrant = Color.fromARGB(255, vR ~/ vCount, vG ~/ vCount, vB ~/ vCount);
    } else if (midCount > 0) {
      // Desaturated cover: boost saturation of the midtone for a usable accent.
      final mid = Color.fromARGB(255, midR ~/ midCount, midG ~/ midCount, midB ~/ midCount);
      final hsl = HSLColor.fromColor(mid);
      vibrant = hsl.withSaturation((hsl.saturation + 0.25).clamp(0.0, 0.6)).toColor();
    } else {
      vibrant = dominant;
    }

    final isLightCover = lumSum / count > 0.52;
    return CoverPalette(
      vibrant: vibrant,
      dominant: dominant,
      isLightCover: isLightCover,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

int _max3(int a, int b, int c) => a > b ? (a > c ? a : c) : (b > c ? b : c);
int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
