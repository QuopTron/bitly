// ─────────────────────────────────────────────────────────────
// feed_pagina_helpers.dart — PART de feed_pagina.dart: helpers de
// la página — las fuentes del selector salen SOLO de las secciones
// que el backend devolvió con contenido (evita duplicados y
// fuentes sin feed), el nombre legible de la fuente actual, y los
// delegados de acciones de ítem que reenvían a AccionesItem.
// Se conecta con: feed_pagina.dart (misma library) +
// constantes_fuente + acciones_item.
// Parte del flujo: feed de inicio (lógica de la página).
// ─────────────────────────────────────────────────────────────

part of 'feed_pagina.dart';

/// Fuentes con contenido del home feed (source → nombre legible).
Map<String, String> _fuentesDisponibles(_PaginaFeedState st) {
  final state = st.context.read<BlocFeed>().state;
  final mapa = <String, String>{};
  for (final s in state.secciones) {
    final key = s.source;
    if (key.isEmpty || mapa.containsKey(key)) continue;
    mapa[key] = nombreFuente(key);
  }
  return mapa;
}

/// Nombre legible de la fuente actualmente seleccionada.
String _nombreFuenteActual(_PaginaFeedState st) {
  final state = st.context.read<BlocFeed>().state;
  return _fuentesDisponibles(st)[state.fuenteSeleccionada] ??
      nombreFuente(state.fuenteSeleccionada);
}

// ── Acciones de ítem (delegadas a AccionesItem) ─────────────

void _alternarLike(_PaginaFeedState st, String id, [ItemFeed? item]) {
  if (item != null) AccionesItem.alternarLike(st.context, item);
}

void _iniciarDescarga(_PaginaFeedState st, ItemFeed item) =>
    AccionesItem.iniciarDescarga(st.context, item);

void _iniciarDescargaLote(_PaginaFeedState st, ItemFeed item) =>
    AccionesItem.iniciarDescargaLote(st.context, item);

void _borrarTrack(_PaginaFeedState st, ItemFeed item) =>
    AccionesItem.borrarTrack(st.context, item);

void _borradoLote(_PaginaFeedState st, ItemFeed item) =>
    AccionesItem.borrarLote(st.context, item);

void _exportarPlaylist(_PaginaFeedState st, ItemFeed item) =>
    AccionesItem.exportarPlaylist(st.context, item);

void _mostrarInfo(BuildContext context, ItemFeed item) =>
    AccionesItem.mostrarInfo(context, item);

void _mostrarMas(BuildContext context, ItemFeed item) =>
    AccionesItem.mostrarMas(context, item);