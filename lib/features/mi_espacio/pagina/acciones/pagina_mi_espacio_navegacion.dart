// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio_navegacion.dart — PART de pagina_mi_espacio
// .dart: abrir el detalle de un ítem de Mi Espacio según su tipo
// (álbum, playlist, artista o la info de una canción), resolviendo
// antes la fuente cuando el ítem la trae vacía.
// Se conecta con: pagina_mi_espacio.dart (misma library) +
// navegador_detalle + modal de info de canción.
// Parte del flujo: Home → Mi Espacio (tap en una tarjeta).
// ─────────────────────────────────────────────────────────────

part of '../base/pagina_mi_espacio.dart';

/// Abre el detalle según el tipo de ítem (vía navegador de detalle).
void _onItemTap(_PaginaMiEspacioState st, Item item) {
  if (item.idReal.isEmpty) return;
  final src = _resolverFuente(st, item);
  final context = st.context;
  switch (item.tipo) {
    case TipoItem.album:
      abrirDetalleAlbum(context, id: item.idReal, fuente: src);
    case TipoItem.playlist:
      abrirDetallePlaylist(
        context,
        id: item.idReal,
        nombre: item.titulo,
        fuente: src,
      );
    case TipoItem.artista:
      abrirDetalleArtista(context, id: item.idReal, nombre: item.titulo);
    case TipoItem.cancion:
      mostrarInfoCancionDesdeMiEspacio(context, item);
  }
}
