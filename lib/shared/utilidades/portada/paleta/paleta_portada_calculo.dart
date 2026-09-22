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
///
/// Para URLs remotas NO se hace una petición propia: se lee el archivo que
/// cached_network_image ya descargó para PINTAR la portada (misma caché de
/// disco). Antes cada carátula se bajaba DOS veces —una para el widget y otra
/// para la paleta—, lo que duplicaba el tráfico, satu­raba la conexión en
/// listas largas y dejaba la paleta llegando tarde.
Future<Uint8List?> _leerBytes(String src) async {
  if (esUrlLocal(src)) {
    final f = File(src);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }
  const esperaMax = Duration(seconds: 8);
  try {
    // 1. Ya en caché de disco (lo normal mientras se hace scroll).
    final enCache = await DefaultCacheManager().getFileFromCache(src);
    final archivoCache = enCache?.file;
    if (archivoCache != null && await archivoCache.exists()) {
      final bytes = await archivoCache.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
  } catch (_) {
    // Caché no disponible (o entrada corrupta): se intenta descargar abajo.
  }
  try {
    // 2. No estaba: se descarga UNA vez a través de la misma caché, así el
    // widget la reutiliza enseguida en vez de bajarla otra vez.
    final archivo = await DefaultCacheManager()
        .getSingleFile(src)
        .timeout(esperaMax);
    if (!await archivo.exists()) return null;
    final bytes = await archivo.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

/// Lado del muestreo para la paleta.
///
/// 48 y no 96: la paleta es un PROMEDIO del arte, así que 2.304 píxeles por
/// canal dan el mismo color que 9.216 (la diferencia no se ve en pantalla),
/// pero el `toByteData` —que es una LECTURA de la GPU a la CPU y por eso lo
/// caro de esta función— mueve la CUARTA parte de bytes. Cada carátula nueva
/// que entra en pantalla (seis por frame en un scroll rápido) paga este
/// readback, así que acá está el pico de frames del scroll.
const int _ladoMuestreo = 48;

/// Calcula la paleta muestreando los píxeles de la imagen.
Future<PaletaPortada?> _calcularDesdeBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: _ladoMuestreo,
    targetHeight: _ladoMuestreo,
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
      vibrante = Color.fromARGB(255, vR ~/ vCount, vG ~/ vCount, vB ~/ vCount);
    } else if (midCount > 0) {
      // Carátula desaturada: sube la saturación del tono medio.
      final mid = Color.fromARGB(
        255,
        midR ~/ midCount,
        midG ~/ midCount,
        midB ~/ midCount,
      );
      final hsl = HSLColor.fromColor(mid);
      vibrante =
          hsl.withSaturation((hsl.saturation + 0.25).clamp(0.0, 0.6)).toColor();
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
