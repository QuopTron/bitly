// ─────────────────────────────────────────────────────────────
// datos_mi_espacio_items.dart — PART de datos_mi_espacio.dart:
// construye los ítems de las pestañas Canciones y Playlists
// combinando likes y descargas con deduplicación (ID normalizado +
// nombre/artista). Los ítems de Álbumes y Artistas viven en
// datos_mi_espacio_items2.dart.
// Se conecta con: datos_mi_espacio.dart (misma library) +
// cubit_like + cubit_descargas + modelos_item.
// Parte del flujo: Home → Mi Espacio (ítems Canciones/Playlists).
// ─────────────────────────────────────────────────────────────

part of 'datos_mi_espacio.dart';

/// Pestaña Canciones: likes de tracks + tracks descargados (dedup).
List<Item> _itemsCanciones(
  EstadoLikes estado,
  CubitDescargas? dl,
  Map<String, DatoBiblioteca> biblioteca,
) {
  final vistosId = <String>{};
  final vistosClave = <String>{};
  final canciones = <Item>[];
  final idsAmados = <String>{};
  for (final i in estado.todosAmados.values.where((i) => i.type == 'track')) {
    final normId = normalizarIdTrack(i.id);
    final clave =
        '${_normalizarNombre(i.name)}|${_normalizarNombre(i.artists ?? '')}';
    if (vistosId.contains(normId) || vistosClave.contains(clave)) continue;
    vistosId.add(normId);
    vistosClave.add(clave);
    idsAmados.add(normId);
    canciones.add(_itemDesdeAmado(i, TipoItem.cancion, biblioteca));
  }
  if (dl != null) {
    for (final t in dl.tracksCompletados) {
      final normId = normalizarIdTrack(t.id);
      final bib = biblioteca[normId];
      final clave =
          '${_normalizarNombre(t.name)}|${_normalizarNombre(t.artists ?? '')}';
      if (vistosId.contains(normId) || vistosClave.contains(clave)) continue;
      vistosId.add(normId);
      vistosClave.add(clave);
      canciones.add(
        Item(
          nombreDeItem(t.name, bib, respaldo: t.id),
          t.artists ?? '',
          TipoItem.cancion,
          coverUrl: caratulaDeItem(t.coverUrl, bib),
          idReal: t.id,
          fuente: t.source ?? '',
          origen:
              idsAmados.contains(normId)
                  ? OrigenItem.amado
                  : OrigenItem.descargado,
        ),
      );
    }
  }
  return canciones;
}

/// Pestaña Playlists: propias + amadas + descargadas (dedup por id/nombre).
List<Item> _itemsPlaylists(
  EstadoLikes estado,
  List<Item> creadas,
  CubitDescargas? dl,
  Map<String, DatoBiblioteca> biblioteca,
) {
  final idsCreadas = creadas.map((i) => normalizarIdTrack(i.idReal)).toSet();
  final nombresCreados =
      creadas.map((i) => _normalizarNombre(i.titulo)).toSet();
  final vistosId = <String>{...idsCreadas};
  final vistosNombre = <String>{...nombresCreados};
  final playlists = <Item>[];
  final idsAmados = <String>{};
  for (final i in estado.todosAmados.values.where(
    (i) => i.type == 'playlist',
  )) {
    final normId = normalizarIdTrack(i.id);
    final normNombre = _normalizarNombre(i.name);
    if (vistosId.contains(normId) || vistosNombre.contains(normNombre)) {
      continue;
    }
    vistosId.add(normId);
    vistosNombre.add(normNombre);
    idsAmados.add(normId);
    playlists.add(_itemDesdeAmado(i, TipoItem.playlist, biblioteca));
  }
  if (dl != null) {
    for (final entry in dl.state.descargas.entries) {
      if (entry.value.estado != EstadoDescarga.completado) continue;
      if (!entry.key.startsWith('playlist_')) continue;
      final parts = entry.key.split('_');
      if (parts.length < 3) continue;
      final src = parts.last;
      final playlistId = parts.sublist(1, parts.length - 1).join('_');
      final normId = normalizarIdTrack(playlistId);
      final nombre = dl.nombreLotePara(entry.key);
      final normNombre = _normalizarNombre(
        nombre.isNotEmpty ? nombre : playlistId,
      );
      if (vistosId.contains(normId) || vistosNombre.contains(normNombre)) {
        continue;
      }
      vistosId.add(normId);
      vistosNombre.add(normNombre);
      final caratula = dl.caratulaLotePara(entry.key);
      final bib = biblioteca[normId];
      playlists.add(
        Item(
          nombreDeItem(nombre, bib, respaldo: playlistId),
          src,
          TipoItem.playlist,
          coverUrl: caratulaDeItem(caratula, bib),
          idReal: playlistId,
          fuente: src,
          origen:
              idsAmados.contains(normId)
                  ? OrigenItem.amado
                  : OrigenItem.descargado,
        ),
      );
    }
  }
  return [...creadas, ...playlists];
}

/// Construye un Item desde un ítem amado (con su carátula local).
/// La carátula del like solo gana si el archivo existe de verdad; si no,
/// se usa la URL remota del propio like y, al final, la de la biblioteca.
Item _itemDesdeAmado(
  DatosItemAmado i,
  TipoItem tipo,
  Map<String, DatoBiblioteca> biblioteca,
) {
  final bib = biblioteca[normalizarIdTrack(i.id)];
  final propia =
      (i.rutaCaratulaLocal?.isNotEmpty == true)
          ? i.rutaCaratulaLocal
          : i.coverUrl;
  return Item(
    nombreDeItem(i.name, bib, respaldo: i.id),
    i.artists ?? '',
    tipo,
    coverUrl: caratulaDeItem(propia, bib),
    idReal: i.id,
    fuente: i.source ?? '',
    origen: OrigenItem.amado,
  );
}
