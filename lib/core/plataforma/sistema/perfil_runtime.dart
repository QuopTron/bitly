// ─────────────────────────────────────────────────────────────
// perfil_runtime.dart — Detección de capacidad del dispositivo
// (gama baja/media/alta) para rendimiento adaptativo: tamaño del
// caché de imágenes, overscroll y blur de fondo. Se persiste en
// SharedPreferences.
// Se conecta con: shared_preferences + Painter (image cache).
// Parte del flujo: arranque (loadRuntimeProfile → configureImageCache).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../modelos/usuario/perfil_rendimiento.dart';
import 'deteccion_gama.dart';

enum NivelRendimientoRuntime { bajo, estandar, alto }

class PerfilRuntime {
  final NivelRendimientoRuntime nivel;
  final int tamanoMaximoCacheImagenes;
  final int tamanoMaximoCacheBytes;
  final bool deshabilitarOverscroll;
  final bool habilitarBlurFondo;

  const PerfilRuntime._({
    required this.nivel,
    required this.tamanoMaximoCacheImagenes,
    required this.tamanoMaximoCacheBytes,
    required this.deshabilitarOverscroll,
    required this.habilitarBlurFondo,
  });

  const PerfilRuntime.bajo()
      : this._(
          nivel: NivelRendimientoRuntime.bajo,
          tamanoMaximoCacheImagenes: 120,
          tamanoMaximoCacheBytes: 24 << 20,
          deshabilitarOverscroll: true,
          habilitarBlurFondo: false,
        );

  const PerfilRuntime.estandar()
      : this._(
          nivel: NivelRendimientoRuntime.estandar,
          tamanoMaximoCacheImagenes: 240,
          tamanoMaximoCacheBytes: 60 << 20,
          deshabilitarOverscroll: false,
          habilitarBlurFondo: false,
        );

  const PerfilRuntime.alto()
      : this._(
          nivel: NivelRendimientoRuntime.alto,
          tamanoMaximoCacheImagenes: 320,
          tamanoMaximoCacheBytes: 80 << 20,
          deshabilitarOverscroll: false,
          habilitarBlurFondo: true,
        );

  static PerfilRuntime? desdeNivel(String nivel) => switch (nivel) {
    'low' => const PerfilRuntime.bajo(),
    'standard' => const PerfilRuntime.estandar(),
    'high' => const PerfilRuntime.alto(),
    _ => null,
  };

  String get claveNivel => switch (nivel) {
    NivelRendimientoRuntime.bajo => 'low',
    NivelRendimientoRuntime.estandar => 'standard',
    NivelRendimientoRuntime.alto => 'high',
  };
}

// v2: la v1 quedaba SIEMPRE en "standard" (nunca detectaba nada), así que
// subir la clave es lo que hace que los equipos de gama baja ya instalados
// vuelvan a calcular su perfil (y su caché) al actualizar.
const _claveNivelPerfilRuntime = 'runtime_profile_tier_v2';

/// Carga el perfil de runtime del dispositivo actual.
///
/// Si no hay valor guardado se DETECTA la gama del equipo (núcleos + RAM) en
/// vez de asumir "estándar": un celular de gama baja necesita la caché chica
/// para no llenar la RAM y que el sistema no lo mate por OOM.
Future<PerfilRuntime> cargarPerfilRuntime(SharedPreferences prefs) async {
  final nivelCacheado = prefs.getString(_claveNivelPerfilRuntime);
  if (nivelCacheado != null) {
    final cacheado = PerfilRuntime.desdeNivel(nivelCacheado);
    if (cacheado != null) return cacheado;
  }

  final detectado = segmentoPorGama(await detectarNivelRendimiento());
  await prefs.setString(_claveNivelPerfilRuntime, detectado.claveNivel);
  return detectado;
}

/// Traduce la gama de rendimiento a la caché de imágenes correspondiente.
PerfilRuntime segmentoPorGama(NivelRendimiento nivel) => switch (nivel) {
  NivelRendimiento.bajo => const PerfilRuntime.bajo(),
  NivelRendimiento.alto => const PerfilRuntime.alto(),
  NivelRendimiento.medio => const PerfilRuntime.estandar(),
};

/// Guarda el nivel del perfil de runtime en SharedPreferences.
Future<void> guardarPerfilRuntime(SharedPreferences prefs, PerfilRuntime perfil) async {
  await prefs.setString(_claveNivelPerfilRuntime, perfil.claveNivel);
}

/// Configura el caché de imágenes según el perfil de runtime.
void configurarCacheImagenes(PerfilRuntime perfil) {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = perfil.tamanoMaximoCacheImagenes;
  imageCache.maximumSizeBytes = perfil.tamanoMaximoCacheBytes;
}