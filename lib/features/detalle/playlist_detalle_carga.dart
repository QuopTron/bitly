// ─────────────────────────────────────────────────────────────
// playlist_detalle_carga.dart — PART de playlist_detalle_pagina.dart:
// secuencia de carga: memoria de sesión → drift local → cache
// JSON/API → lote offline → error. Incluye el chequeo de tracks
// completos y el refresco en background. El fallback del lote
// vive en playlist_detalle_lote.dart; las mutaciones se repintan
// con st.repintar().
// Se conecta con: playlist_detalle_pagina.dart + caches + backend.
// Parte del flujo: Detalle → playlist (carga).
// ─────────────────────────────────────────────────────────────

part of 'playlist_detalle_pagina.dart';

/// Secuencia de carga: memoria → local → API → lote (offline).
Future<void> _cargarDetallePlaylist(_PlaylistDetallePaginaState st) async {
  st._cargando = true;
  st._error = false;
  st.repintar();
  st._estaEnLinea = await ServicioConectividad.estaEnLinea();
  final memoria = sl<CacheDetalleMemoria>();
  final local = sl<ReproduccionDetalleLocal>();
  final cache = sl<CacheDetalle>();
  final backend = sl<BackendService>();
  final dlCubit = sl<CubitDescargas>();

  DetallePlaylist? detalle;

  // 1) Memoria de sesión (instantánea).
  detalle = memoria.getPlaylist(st.widget.collectionId);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    final completo = _todosTracksDescargadosPlaylist(st, detalle, dlCubit);
    st._playlist = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 2) Drift local (rápido, funciona sin red).
  detalle = await local.getDetallePlaylistLocal(st.widget.collectionId);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    memoria.setPlaylist(st.widget.collectionId, detalle);
    final completo = _todosTracksDescargadosPlaylist(st, detalle, dlCubit);
    st._playlist = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 3) Con red: cache JSON persistente primero, luego API.
  if (st._estaEnLinea) {
    try {
      var json = await cache.getDetallePlaylist(st.widget.collectionId);
      if (json == null || json.isEmpty || json == '{}') {
        final jsonRemoto = await backend.fetchPlaylistDetail(
          st.widget.collectionId,
          st.widget.source,
        );
        if (jsonRemoto.isNotEmpty && jsonRemoto != '{}') {
          json = jsonRemoto;
          await cache.guardarDetallePlaylist(
            st.widget.collectionId,
            jsonRemoto,
          );
        }
      }
      if (json != null && json.isNotEmpty && json != '{}') {
        detalle =
            DetallePlaylist.desdeJson(jsonDecode(json) as Map<String, dynamic>);
        memoria.setPlaylist(st.widget.collectionId, detalle);
      }
    } catch (_) {}
    if (detalle != null && detalle.tracks.isNotEmpty) {
      st._playlist = detalle;
      st._cargando = false;
      st.repintar();
      return;
    }
  }

  // 4) Offline: reconstruir desde el lote de descargas.
  detalle = await _construirDesdeLotePlaylist(st);
  if (detalle != null && detalle.tracks.isNotEmpty) {
    memoria.setPlaylist(st.widget.collectionId, detalle);
    final completo = _todosTracksDescargadosPlaylist(st, detalle, dlCubit);
    st._playlist = detalle;
    st._cargando = false;
    st.repintar();
    if (!completo && st._estaEnLinea) _refrescarDesdeApi(st, cache, backend);
    return;
  }

  // 5) Nada encontrado: marcar error si quedó null.
  st._playlist = detalle;
  st._cargando = false;
  st._error = detalle == null;
  st.repintar();
}

/// ¿Todos los tracks de la playlist están descargados?
bool _todosTracksDescargadosPlaylist(
  _PlaylistDetallePaginaState st,
  DetallePlaylist detalle,
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

/// Refresca el detalle desde la API y lo guarda en todos los caches.
Future<void> _refrescarDesdeApi(
  _PlaylistDetallePaginaState st,
  CacheDetalle cache,
  BackendService backend,
) async {
  try {
    final json = await backend.fetchPlaylistDetail(
      st.widget.collectionId,
      st.widget.source,
    );
    if (json.isEmpty || json == '{}') return;
    final fresco =
        DetallePlaylist.desdeJson(jsonDecode(json) as Map<String, dynamic>);
    sl<CacheDetalleMemoria>().setPlaylist(st.widget.collectionId, fresco);
    await sl<ReproduccionSync>()
        .sincronizarDetallePlaylist(fresco, fuente: st.widget.source);
    await cache.guardarDetallePlaylist(st.widget.collectionId, json);
    st._playlist = fresco;
    st._error = false;
    st.repintar();
  } catch (_) {}
}