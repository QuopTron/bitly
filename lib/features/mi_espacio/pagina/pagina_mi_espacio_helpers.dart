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
/// Aplica búsqueda de texto y filtros/orden a la lista de ítems.
List<Item> _aplicarBusquedaYFiltros(
  List<Item> items,
  String texto,
  FiltrosMiEspacio filtros,
  _PaginaMiEspacioState st,
  EstadoLikes estadoLike,
) {
  var resultado = List<Item>.from(items);

  // Búsqueda por texto (título, subtítulo, fuente).
  if (texto.isNotEmpty) {
    resultado = resultado.where((item) {
      final busca = '$texto ${item.titulo} ${item.subtitulo} ${item.fuente}'
          .toLowerCase();
      return busca.contains(texto);
    }).toList();
  }

  // Filtros de origen.
  final dlCubit = st.context.read<CubitDescargas>();
  final huellasDesc = dlCubit.state.huellasDescargadas;
  if (filtros.soloAmados) {
    resultado = resultado.where((item) {
      return estadoLike.todosAmados.keys.any(
        (rawId) => normalizarIdTrack(rawId) == normalizarIdTrack(item.idReal),
      );
    }).toList();
  }
  if (filtros.soloDescargados) {
    resultado = resultado.where((item) {
      final normId = normalizarIdTrack(item.idReal);
      final prefijo = '${tipoParaPestana(st._pestanaSeleccionada)}_${normId}_';
      final tieneDescarga = dlCubit.state.descargas.keys.any(
        (k) => k.startsWith(prefijo),
      );
      return tieneDescarga ||
          huellasDesc.contains(huellaItem(ItemFeed(
            id: item.idReal, type: tipoParaPestana(st._pestanaSeleccionada),
            name: item.titulo, artists: item.subtitulo,
            source: item.fuente,
          )));
    }).toList();
  }
  // soloConPlaylist filtra por playlists.
  if (filtros.soloConPlaylist) {
    resultado = resultado.where((item) {
      return item.tipo == TipoItem.playlist;
    }).toList();
  }

  // Orden.
  switch (filtros.modoOrden) {
    case ModoOrden.az:
      resultado.sort((a, b) =>
          a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    case ModoOrden.azInvertido:
      resultado.sort((a, b) =>
          b.titulo.toLowerCase().compareTo(a.titulo.toLowerCase()));
    case ModoOrden.masEscuchados:
      resultado.sort((a, b) {
        final ra = st._contadoresReproduccion[a.idReal] ?? 0;
        final rb = st._contadoresReproduccion[b.idReal] ?? 0;
        return rb.compareTo(ra);
      });
    case ModoOrden.porArtista:
      resultado.sort((a, b) {
        final aa = a.subtitulo.toLowerCase();
        final ba = b.subtitulo.toLowerCase();
        final cmp = aa.compareTo(ba);
        if (cmp != 0) return cmp;
        return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      });
    case ModoOrden.nuevos:
      // Mantener el orden original (más recientes primero).
      break;
  }

  return resultado;
}

/// Mensaje de vacío considerando filtros y búsqueda activos.
String _mensajeVacioConFiltros(
  String texto,
  FiltrosMiEspacio filtros,
  AppLocalizations loc,
  int pestana,
) {
  if (texto.isNotEmpty) {
    return 'No se encontraron resultados para "$texto".';
  }
  if (filtros.hayFiltros) {
    return 'Nada coincide con los filtros seleccionados.';
  }
  return mensajeVacio(loc, pestana);
}