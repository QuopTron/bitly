// ─────────────────────────────────────────────────────────────
// imagen_portada_helpers.dart — PART de imagen_portada.dart:
// helpers de carga de carátulas — detección de URL local,
// construcción del widget de imagen (archivo local o URL remota
// con caché, decode acotado, filtro low, fade) y el placeholder
// shimmer con gradiente barrido para mientras carga.
// Se conecta con: imagen_portada.dart (misma library) +
// cached_network_image + dart:io.
// Parte del flujo: feed, búsqueda, detalle, mi espacio (carátulas).
// ─────────────────────────────────────────────────────────────

part of 'imagen_portada.dart';

/// True si [url] apunta a un archivo local.
bool esUrlLocal(String url) =>
    url.startsWith('/') ||
    url.startsWith(r'\\') ||
    (url.length > 3 && url[1] == ':');

/// Construye un [Image] desde URL remota o archivo local.
/// Devuelve [fallback] si la URL está vacía o hay error.
/// El decode acotado, filtro low, fade corto y useOldImageOnUrlChange
/// siguen el manejo de portadas de SpotiFLAC (rápido + memoria acotada).
Widget imagenDesdeUrl(
  String? url, {
  double? ancho,
  double? alto,
  BoxFit ajuste = BoxFit.cover,
  Widget? fallback,
}) {
  if (url == null || url.isEmpty) {
    return fallback ?? const SizedBox.shrink();
  }
  if (esUrlLocal(url)) {
    return Image.file(
      File(url),
      width: ancho,
      height: alto,
      fit: ajuste,
      cacheWidth: _extentCachePara(ancho),
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: ancho,
    height: alto,
    fit: ajuste,
    memCacheWidth: _extentCachePara(ancho),
    filterQuality: FilterQuality.low,
    useOldImageOnUrlChange: true,
    fadeInDuration: const Duration(milliseconds: 150),
    fadeOutDuration: const Duration(milliseconds: 100),
    placeholder: (_, _) => const SizedBox.shrink(),
    errorWidget: (_, _, _) => fallback ?? const SizedBox.shrink(),
  );
}

/// Calcula un tamaño de decode acotado para una imagen de [tamano] px
/// lógicos (retina ×2, entre 64 y 512 px) para ahorrar memoria en
/// carátulas pequeñas.
int? _extentCachePara(double? tamano) {
  if (tamano == null || !tamano.isFinite || tamano <= 0) return null;
  return (tamano * 2).round().clamp(64, 512);
}

/// Shimmer simple con gradiente barrido. Sin dependencias externas.
class _PlaceholderShimmer extends StatefulWidget {
  final double? ancho;
  final double? alto;
  final double radioBorde;
  final Color? colorFondo;

  const _PlaceholderShimmer({
    this.ancho,
    this.alto,
    this.radioBorde = 0,
    this.colorFondo,
  });

  @override
  State<_PlaceholderShimmer> createState() => _PlaceholderShimmerState();
}

class _PlaceholderShimmerState extends State<_PlaceholderShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.colorFondo ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE8E8E8));
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: widget.ancho,
          height: widget.alto,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radioBorde),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t, 0),
              end: Alignment(-0.5 + 2.0 * t, 0),
              colors: [
                base,
                base.withValues(alpha: 0.5),
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}