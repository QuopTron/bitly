// ─────────────────────────────────────────────────────────────
// album_detalle_carga.dart — PART de album_detalle_pagina.dart:
// secuencia de carga del álbum: memoria de sesión → drift local →
// cache JSON/API → lote offline → error. Incluye el chequeo de
// tracks completos y el refresco en background. El fallback del
// lote vive en album_detalle_lote.dart; las mutaciones se repintan
// con st.repintar().
// Se conecta con: album_detalle_pagina.dart + caches + backend.
// Parte del flujo: Detalle → álbum (carga).
// ─────────────────────────────────────────────────────────────

part of 'album_detalle_pagina.dart';

/// Secuencia de carga: memoria → local → API → lote (offline).
Future<void> _cargarDetalleAlbum(_AlbumDetallePaginaState st) async {
  st._cargando = true;
  st._error = false;
  st.repintar();
  st._estaEnLinea = await ServicioConectividad.estaEnLinea();
  final memoria = sl<CacheDetalleMemoria>();
  final local = sl<ReproduccionDetalleLocal>();
  final cache = sl<CacheDetalle>();
  final backend = sl<BackendService>();
  final dlCubit = sl<CubitDescargas>();

  DetalleAlbum? detalle;

  // 1) Memoria de sesión (instantánea).
  detalle = memoria.getAlbum(st.widget.albumId);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    final completo = _todosTracksDescargados(st, detalle, dlCubit);
    st._album = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 2) Drift local (rápido, funciona sin red).
  detalle = await local.getDetalleAlbumLocal(st.widget.albumId);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    memoria.setAlbum(st.widget.albumId, detalle);
    final completo = _todosTracksDescargados(st, detalle, dlCubit);
    st._album = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 3) Con red: cache JSON persistente primero, luego API.
  if (st._estaEnLinea) {
    try {
      var json = await cache.getDetalleAlbum(st.widget.albumId);
      if (json == null || json.isEmpty || json == '{}') {
        final jsonRemoto = await backend.fetchAlbumDetail(
          st.widget.albumId,
          st.widget.source,
        );
        if (jsonRemoto.isNotEmpty && jsonRemoto != '{}') {
          json = jsonRemoto;
          await cache.guardarDetalleAlbum(st.widget.albumId, jsonRemoto);
        }
      }
      if (json != null && json.isNotEmpty && json != '{}') {
        detalle = DetalleAlbum.desdeJson(jsonDecode(json) as Map<String, dynamic>);
        memoria.setAlbum(st.widget.albumId, detalle);
      }
    } catch (_) {}
    if (detalle != null && detalle.tracks.isNotEmpty) {
      st._album = detalle;
      st._cargando = false;
      st.repintar();
      return;
    }
  }

  // 4) Offline: reconstruir desde el lote de descargas.
  detalle = await _construirDesdeLote(st);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    memoria.setAlbum(st.widget.albumId, detalle);
    final completo = _todosTracksDescargados(st, detalle, dlCubit);
    st._album = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 5) Nada disponible → estado de error.
  st._album = detalle;
  st._cargando = false;
  st._error = detalle == null;
  st.repintar();
}

/// True si todos los tracks del detalle están descargados.
bool _todosTracksDescargados(
  _AlbumDetallePaginaState st,
  DetalleAlbum detalle,
  CubitDescargas dlCubit,
) {
  if (detalle.tracks.isEmpty) return false;
  final src = st.widget.source.isNotEmpty
      ? st.widget.source
      : (detalle.tracks.first.provider ?? '');
  for (final t in detalle.tracks) {
    final clave = 'track_${normalizarIdTrack(t.trackId)}_$src';
    if (dlCubit.estadoDescargaPara(clave).estado !=
        EstadoDescarga.completado) {
      return false;
    }
  }
  return true;
}

/// Refresca el detalle desde la API en background (sin tocar la UI visible).
Future<void> _refrescarDesdeApi(
  _AlbumDetallePaginaState st,
  CacheDetalle cache,
  BackendService backend,
) async {
  try {
    final json = await backend.fetchAlbumDetail(
      st.widget.albumId,
      st.widget.source,
    );
    if (json.isNotEmpty && json != '{}') {
      final fresco = DetalleAlbum.desdeJson(jsonDecode(json) as Map<String, dynamic>);
      sl<CacheDetalleMemoria>().setAlbum(st.widget.albumId, fresco);
      await cache.guardarDetalleAlbum(st.widget.albumId, json);
      st._album = fresco;
      st._error = false;
      st.repintar();
    }
  } catch (_) {}
}

// (la reconstrucción offline desde el lote vive en album_detalle_lote.dart)