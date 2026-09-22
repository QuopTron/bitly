// ─────────────────────────────────────────────────────────────
// imagen_portada.dart — Widget de carátula con borde redondeado,
// shimmer mientras carga y glow de color opcional detrás de la
// imagen. Los helpers de carga (URL local vs remota con caché,
// decode acotado) viven en el part imagen_portada_helpers.dart.
// Se conecta con: cached_network_image + dart:io (archivos locales).
// Parte del flujo: feed, búsqueda, detalle, mi espacio (carátulas).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

part 'imagen_portada_helpers.dart';

/// Widget de portada con borde redondeado, shimmer opcional y glow.
class ImagenPortada extends StatelessWidget {
  final String? coverUrl;
  final String? rutaLocal;
  final double? ancho;
  final double? alto;
  final BoxFit ajuste;
  final double radioBorde;
  final Widget? fallback;
  final Color? fondoFallback;

  /// Si se define, pinta un glow de color suave detrás de la imagen
  /// (p.ej. el color dominante de la portada). Alpha controla intensidad.
  final Color? colorGlow;

  /// Radio de dispersión del glow cuando [colorGlow] está definido.
  final double dispersionGlow;

  const ImagenPortada({
    super.key,
    this.coverUrl,
    this.rutaLocal,
    this.ancho,
    this.alto,
    this.ajuste = BoxFit.cover,
    this.radioBorde = 0,
    this.fallback,
    this.fondoFallback,
    this.colorGlow,
    this.dispersionGlow = 6,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(radioBorde);

    Widget imagen = _construirImagen(context);

    if (colorGlow != null) {
      imagen = Container(
        decoration: BoxDecoration(
          borderRadius: radio,
          boxShadow: [
            BoxShadow(
              color: colorGlow!.withValues(alpha: 0.35),
              blurRadius: dispersionGlow * 2,
              spreadRadius: dispersionGlow,
            ),
          ],
        ),
        child: ClipRRect(borderRadius: radio, child: imagen),
      );
    } else if (radioBorde > 0) {
      imagen = ClipRRect(borderRadius: radio, child: imagen);
    }

    return imagen;
  }

  Widget _construirImagen(BuildContext context) {
    final respaldo = fallback ?? _fallbackPorDefecto(context);
    final local = rutaLocal;
    if (local != null && local.isNotEmpty) {
      if (local.startsWith('http://') || local.startsWith('https://')) {
        return imagenDesdeUrl(
          local,
          ancho: ancho,
          alto: alto,
          ajuste: ajuste,
          fallback: respaldo,
        );
      }
      // SIN `existsSync`: consultar el sistema de archivos en el `build()` de
      // cada tarjeta es una llamada al sistema por frame (antes: una por
      // tarjeta y por build). `Image.file` ya resuelve el archivo y, si no
      // existe o falla, cae al cover de red (o al respaldo) vía `errorBuilder`:
      // mismo resultado visible, cero syscalls.
      return imagenDesdeUrl(
        local,
        ancho: ancho,
        alto: alto,
        ajuste: ajuste,
        fallback: respaldo,
        respaldoRemoto: coverUrl,
      );
    }

    return imagenDesdeUrl(
      coverUrl,
      ancho: ancho,
      alto: alto,
      ajuste: ajuste,
      fallback: respaldo,
    );
  }

  Widget _fallbackPorDefecto(BuildContext context) {
    if (fondoFallback != null) {
      return Container(width: ancho, height: alto, color: fondoFallback);
    }
    return const SizedBox.shrink();
  }
}
