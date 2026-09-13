// ─────────────────────────────────────────────────────────────
// cabecera_detalle_imagen.dart — PART de cabecera_detalle.dart:
// imágenes de la cabecera: portada (local/red con cacheWidth),
// fondo difuminado con decode pequeño (60px, bajo costo de GPU)
// y placeholder de nota musical. Comparte la detección de URL
// local con el resto de la cabecera.
// Se conecta con: cabecera_detalle.dart (misma library).
// Parte del flujo: Detalle (imágenes de la cabecera).
// ─────────────────────────────────────────────────────────────

part of 'cabecera_detalle.dart';

/// True si la URL apunta a un archivo local (ruta o file://).
bool _esPortadaLocal(CabeceraDetalle w) {
  final url = w.coverUrl;
  if (url == null || url.isEmpty) return false;
  return url.startsWith('/') || url.startsWith('file://');
}

/// Portada principal con decode a 2x del tamaño pedido.
Widget _imgPortada(_CabeceraDetalleState st, double size) {
  final url = st.widget.coverUrl;
  if (url == null || url.isEmpty) return _placeholder(st.context, size);
  if (_esPortadaLocal(st.widget)) {
    final path =
        url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: size.toInt() * 2,
      errorBuilder: (c, e, s) => _placeholder(st.context, size),
    );
  }
  return Image.network(
    url,
    fit: BoxFit.cover,
    cacheWidth: size.toInt() * 2,
    errorBuilder: (c, e, s) => _placeholder(st.context, size),
    gaplessPlayback: true,
  );
}

/// Fondo difuminado con decode pequeño (60px) para bajo costo de GPU.
Widget _fondoBlur(_CabeceraDetalleState st) {
  final url = st.widget.coverUrl;
  if (url == null || url.isEmpty) return const SizedBox.shrink();
  if (_esPortadaLocal(st.widget)) {
    final path =
        url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 60,
      errorBuilder: (c, e, s) => const SizedBox.shrink(),
    );
  }
  return Image.network(
    url,
    fit: BoxFit.cover,
    cacheWidth: 60,
    errorBuilder: (c, e, s) => const SizedBox.shrink(),
    gaplessPlayback: true,
  );
}

/// Placeholder de nota musical cuando no hay carátula.
Widget _placeholder(BuildContext context, double size) {
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  return Container(
    color: esOscuro ? Colors.white10 : Colors.black12,
    child: Icon(
      Icons.music_note,
      size: size * 0.3,
      color: (esOscuro ? Colors.white : Colors.black).withValues(alpha: 0.3),
    ),
  );
}