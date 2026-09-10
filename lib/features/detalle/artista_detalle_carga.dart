// ─────────────────────────────────────────────────────────────
// artista_detalle_carga.dart — PART de artista_detalle_pagina.dart:
// secuencia de carga del artista: memoria de sesión → drift local →
// cache JSON/API → error. Incluye el refresco en background cuando
// hay red y el detalle vino de local; las mutaciones se repintan
// con st.repintar().
// Se conecta con: artista_detalle_pagina.dart + caches + backend.
// Parte del flujo: Detalle → artista (carga).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Secuencia de carga: memoria → local → API → error.
Future<void> _cargarDetalleArtista(_ArtistaDetallePaginaState st) async {
  st._cargando = true;
  st._error = false;
  st.repintar();
  st._estaEnLinea = await ServicioConectividad.estaEnLinea();
  final memoria = sl<CacheDetalleMemoria>();
  final local = sl<ReproduccionDetalleLocal>();
  final cache = sl<CacheDetalle>();
  final backend = sl<BackendService>();

  DetalleArtista? detalle;

  // 1) Memoria de sesión (instantánea).
  detalle = memoria.getArtista(st.widget.artistId);
  if (detalle != null && _tieneContenido(detalle)) {
    st._artista = detalle;
    st._cargando = false;
    st.repintar();
    return;
  }

  // 2) Drift local (rápido, funciona sin red).
  detalle = await local.getDetalleArtistaLocal(st.widget.artistId);
  if (detalle != null && _tieneContenido(detalle)) {
    memoria.setArtista(st.widget.artistId, detalle);
    st._artista = detalle;
    st._cargando = false;
    st.repintar();
    if (st._estaEnLinea) _refrescarArtista(st, cache, backend);
    return;
  }

  // 3) Con red: cache JSON persistente primero, luego API.
  if (st._estaEnLinea) {
    try {
      var json = await cache.getDetalleArtista(st.widget.artistId);
      if (json == null || json.isEmpty || json == '{}') {
        final jsonRemoto =
            await backend.fetchArtistDetail(st.widget.artistId, st.widget.source);
        if (jsonRemoto.isNotEmpty && jsonRemoto != '{}') {
          json = jsonRemoto;
          await cache.guardarDetalleArtista(st.widget.artistId, jsonRemoto);
        }
      }
      if (json != null && json.isNotEmpty && json != '{}') {
        detalle =
            DetalleArtista.desdeJson(jsonDecode(json) as Map<String, dynamic>);
        memoria.setArtista(st.widget.artistId, detalle);
      }
    } catch (_) {}
  }

  // 4) Nada encontrado: marcar error si quedó null.
  st._artista = detalle;
  st._cargando = false;
  st._error = detalle == null;
  st.repintar();
}

/// ¿El artista tiene tracks o álbumes que mostrar?
bool _tieneContenido(DetalleArtista detalle) =>
    detalle.topTracks.isNotEmpty || detalle.topAlbums.isNotEmpty;

/// Refresca el detalle del artista desde la API y actualiza los caches.
Future<void> _refrescarArtista(
  _ArtistaDetallePaginaState st,
  CacheDetalle cache,
  BackendService backend,
) async {
  try {
    final json = await backend.fetchArtistDetail(st.widget.artistId, st.widget.source);
    if (json.isEmpty || json == '{}') return;
    final fresco =
        DetalleArtista.desdeJson(jsonDecode(json) as Map<String, dynamic>);
    sl<CacheDetalleMemoria>().setArtista(st.widget.artistId, fresco);
    await sl<ReproduccionSync>()
        .sincronizarDetalleArtista(fresco, fuente: st.widget.source);
    await cache.guardarDetalleArtista(st.widget.artistId, json);
    st._artista = fresco;
    st._error = false;
    st.repintar();
  } catch (_) {}
}