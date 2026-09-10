// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_helpers.dart — PART de pagina_mi_espacio.dart:
// helpers de conversión de la página — Item → ItemFeed (para los
// servicios compartidos) y resolución de la fuente de un ítem
// desde su ID (separador / o :) cuando el campo fuente está vacío.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// modelos_item + item_feed.
// Parte del flujo: Home → Mi Espacio (helpers de la página).
// ─────────────────────────────────────────────────────────────

part of 'pagina_mi_espacio.dart';

/// Convierte un Item en ItemFeed para los servicios compartidos.
ItemFeed _itemFeedPara(_PaginaMiEspacioState st, Item item) {
  final tipo = switch (item.tipo) {
    TipoItem.cancion => 'track',
    TipoItem.playlist => 'playlist',
    TipoItem.album => 'album',
    TipoItem.artista => 'artist',
  };
  return ItemFeed(
    id: item.idReal,
    type: tipo,
    name: item.titulo,
    artists: item.subtitulo,
    coverUrl: item.coverUrl,
    source: _resolverFuente(st, item),
  );
}

/// Resuelve la fuente de un ítem desde su ID (separador / o :).
String _resolverFuente(_PaginaMiEspacioState st, Item item) {
  if (item.fuente.isNotEmpty) return item.fuente;
  final ultimoSlash = item.idReal.lastIndexOf('/');
  final ultimoColon = item.idReal.lastIndexOf(':');
  final sep = ultimoSlash > ultimoColon ? ultimoSlash : ultimoColon;
  if (sep > 0 && sep < item.idReal.length - 1) {
    return item.idReal.substring(0, sep);
  }
  return '';
}