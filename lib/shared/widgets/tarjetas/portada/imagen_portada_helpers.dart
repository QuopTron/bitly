// ─────────────────────────────────────────────────────────────
// imagen_portada_helpers.dart — PART de imagen_portada.dart:
// helpers de carga de carátulas — detección de URL local y
// construcción del widget de imagen (archivo local o URL remota
// con caché, decode acotado, filtro low, fade).
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
///
/// [respaldoRemoto], si se pasa, es la URL a la que cae el widget cuando
/// [url] es un archivo LOCAL que no se pudo abrir. Permite resolver el caso
/// "ruta local muerta" SIN consultar el sistema de archivos en el build.
Widget imagenDesdeUrl(
  String? url, {
  double? ancho,
  double? alto,
  BoxFit ajuste = BoxFit.cover,
  Widget? fallback,
  String? respaldoRemoto,
}) {
  if (url == null || url.isEmpty) {
    return fallback ?? const SizedBox.shrink();
  }
  if (esUrlLocal(url)) {
    final tieneRespaldo =
        respaldoRemoto != null &&
        respaldoRemoto.isNotEmpty &&
        !esUrlLocal(respaldoRemoto);
    return Image.file(
      File(url),
      width: ancho,
      height: alto,
      fit: ajuste,
      cacheWidth: _extentCachePara(ancho),
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder:
          // Ruta local muerta: se intenta el cover de red antes de darse por
          // vencido (antes esto lo decidía un `existsSync` por build).
          (_, _, _) =>
              tieneRespaldo
                  ? imagenDesdeUrl(
                    respaldoRemoto,
                    ancho: ancho,
                    alto: alto,
                    ajuste: ajuste,
                    fallback: fallback,
                  )
                  : (fallback ?? const SizedBox.shrink()),
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

// El shimmer de carga se eliminó: nadie lo activaba (`mostrarShimmer` nunca
// llegaba en true) y, de estar montado, cada tarjeta cargando habría tenido su
// propio AnimationController en `repeat()` repintando un gradiente en cada
// frame. El hueco de carga lo cubre el color de fondo del contenedor.


