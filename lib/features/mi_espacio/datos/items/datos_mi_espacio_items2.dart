// ─────────────────────────────────────────────────────────────
// datos_mi_espacio_items2.dart — PART de datos_mi_espacio.dart:
// construye los ítems de las pestañas Álbumes (likes + lotes
// descargados 'album_' con dedup por ID y nombre|fuente) y
// Artistas (likes dedup por ID normalizado). Canciones/Playlists
// viven en datos_mi_espacio_items.dart.
// Se conecta con: datos_mi_espacio.dart (misma library) +
// cubit_like + cubit_descargas + modelos_item.
// Parte del flujo: Home → Mi Espacio (ítems Álbumes/Artistas).
// ─────────────────────────────────────────────────────────────

part of '../base/datos_mi_espacio.dart';

/// Pestaña Álbumes: likes + lotes descargados 'album_' (dedup).
List<Item> _itemsAlbumes(
  EstadoLikes estado,
  CubitDescargas? dl,
  Map<String, DatoBiblioteca> biblioteca,
) {
  final vistosId = <String>{};
  final vistosClave = <String>{};
  final albumes = <Item>[];
  final idsAmados = <String>{};
  for (final i in estado.todosAmados.values.where((i) => i.type == 'album')) {
    final normId = normalizarIdTrack(i.id);
    final clave =
        '${_normalizarNombre(i.name)}|${_normalizarNombre(i.artists ?? '')}';
    if (vistosId.contains(normId) || vistosClave.contains(clave)) continue;
    vistosId.add(normId);
    vistosClave.add(clave);
    idsAmados.add(normId);
    albumes.add(_itemDesdeAmado(i, TipoItem.album, biblioteca));
  }
  if (dl != null) {
    for (final entry in dl.state.descargas.entries) {
      if (entry.value.estado != EstadoDescarga.completado) continue;
      if (!entry.key.startsWith('album_')) continue;
      final parts = entry.key.split('_');
      if (parts.length < 3) continue;
      final src = parts.last;
      final albumId = parts.sublist(1, parts.length - 1).join('_');
      final normId = normalizarIdTrack(albumId);
      final nombre = dl.nombreLotePara(entry.key);
      final clave =
          '${_normalizarNombre(nombre.isNotEmpty ? nombre : albumId)}|$src';
      if (vistosId.contains(normId) || vistosClave.contains(clave)) continue;
      vistosId.add(normId);
      vistosClave.add(clave);
      final caratula = dl.caratulaLotePara(entry.key);
      final bib = biblioteca[normId];
      albumes.add(
        Item(
          nombreDeItem(nombre, bib, respaldo: albumId),
          src,
          TipoItem.album,
          coverUrl: caratulaDeItem(caratula, bib),
          idReal: albumId,
          fuente: src,
          origen:
              idsAmados.contains(normId)
                  ? OrigenItem.amado
                  : OrigenItem.descargado,
        ),
      );
    }
  }
  return albumes;
}

/// Pestaña Artistas: likes de artistas (dedup por ID normalizado).
List<Item> _itemsArtistas(
  EstadoLikes estado,
  Map<String, DatoBiblioteca> biblioteca,
) {
  final vistos = <String>{};
  return estado.todosAmados.values
      .where((i) => i.type == 'artist' && vistos.add(normalizarIdTrack(i.id)))
      .map((i) => _itemDesdeAmado(i, TipoItem.artista, biblioteca))
      .toList();
}
