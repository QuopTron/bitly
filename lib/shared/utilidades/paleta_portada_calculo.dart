// ─────────────────────────────────────────────────────────────
// paleta_portada_calculo.dart — PART de paleta_portada.dart:
// cálculo de la paleta desde los bytes de la carátula — lee los
// píxeles RGBA (decode acotado a 96px), promedia el color
// dominante, detecta el vibrante (saturado con luminancia legible,
// con respaldo de tonos medios) y decide si el arte es claro.
// Se conecta con: paleta_portada.dart (misma library).
// Parte del flujo: reproductor (letras karaoke, cálculo).
// ─────────────────────────────────────────────────────────────

part of 'paleta_portada.dart';

/// Lee los bytes de la fuente (archivo local o URL remota).
Future<Uint8List?> _leerBytes(String src) async {
  if (esUrlLocal(src)) {
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

/// Calcula la paleta muestreando los píxeles de la imagen (96x96).
Future<PaletaPortada?> _calcularDesdeBytes(Uint8List bytes) async {
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

      // "Vibrante": píxeles saturados en una banda de luminancia legible.
      if (sat > 0.30 && lum > 0.16 && lum < 0.88) {
        vR += r;
        vG += g;
        vB += b;
        vCount++;
      }
      // Tonos medios como respaldo para carátulas muy desaturadas.
      if (lum > 0.2 && lum < 0.75) {
        midR += r;
        midG += g;
        midB += b;
        midCount++;
      }
    }

    if (count == 0) return null;

    final dominante = Color.fromARGB(
      255,
      rSum ~/ count,
      gSum ~/ count,
      bSum ~/ count,
    );

    Color vibrante;
    if (vCount > count * 0.03) {
      vibrante =
          Color.fromARGB(255, vR ~/ vCount, vG ~/ vCount, vB ~/ vCount);
    } else if (midCount > 0) {
      // Carátula desaturada: sube la saturación del tono medio.
      final mid = Color.fromARGB(
          255, midR ~/ midCount, midG ~/ midCount, midB ~/ midCount);
      final hsl = HSLColor.fromColor(mid);
      vibrante = hsl
          .withSaturation((hsl.saturation + 0.25).clamp(0.0, 0.6))
          .toColor();
    } else {
      vibrante = dominante;
    }

    final esClara = lumSum / count > 0.52;
    return PaletaPortada(
      vibrante: vibrante,
      dominante: dominante,
      esPortadaClara: esClara,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

int _max3(int a, int b, int c) => a > b ? (a > c ? a : c) : (b > c ? b : c);
int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);