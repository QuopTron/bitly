// ─────────────────────────────────────────────────────────────
// cabecera_detalle_color.dart — PART de cabecera_detalle.dart:
// extracción del color dominante de la carátula usando el pipeline
// de decodificación de Flutter (muestreo del centro de la imagen
// en RGBA, promedio → HSL con saturación/brillo ajustados) para
// pintar el gradiente de fondo de la cabecera.
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (color del fondo).
// ─────────────────────────────────────────────────────────────

part of 'cabecera_detalle.dart';

/// Decodifica la imagen y extrae el color dominante (centro promediado).
Future<Color?> _extraerColorDominante(ImageProvider provider) async {
  try {
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image?>();
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    final image = await completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        stream.removeListener(listener);
        return null;
      },
    );
    stream.removeListener(listener);
    if (image == null) return null;
    try {
      final w = image.width;
      final h = image.height;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      final data = byteData.buffer.asUint8List();
      int rSum = 0, gSum = 0, bSum = 0, count = 0;
      final pasoX = (w ~/ 12).clamp(1, 1 << 30);
      final pasoY = (h ~/ 12).clamp(1, 1 << 30);
      for (int y = h ~/ 4; y < h * 3 ~/ 4; y += pasoY) {
        for (int x = w ~/ 4; x < w * 3 ~/ 4; x += pasoX) {
          final i = (y * w + x) * 4;
          if (data[i + 3] < 128) continue;
          rSum += data[i];
          gSum += data[i + 1];
          bSum += data[i + 2];
          count++;
        }
      }
      if (count == 0) return null;
      final hsl = HSLColor.fromColor(
        Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count),
      );
      return hsl
          .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
          .withLightness(0.18)
          .toColor();
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

/// Proveedor de imagen para la URL (archivo local o red).
ImageProvider providerPara(String url, bool esLocal) {
  if (esLocal) {
    final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return FileImage(File(path));
  }
  return NetworkImage(url);
}