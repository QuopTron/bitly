// ─────────────────────────────────────────────────────────────
// editor_playlist.dart — Guarda una playlist armada a mano: crea
// o actualiza la colección (nombre + portada), deja sus canciones
// EXACTAMENTE como las eligió el usuario (con su orden) y se
// asegura de que cada una exista en la biblioteca local.
//
// Por qué la biblioteca local: `collection_items` solo guarda ids.
// El detalle de una playlist arma sus filas leyendo `tracks` de
// drift, así que una canción agregada desde búsqueda y ausente de
// la biblioteca se perdía (sin nombre, sin artista, sin carátula).
//
// El orden va en `position`: `addTrack` no la escribe y una
// playlist armada a mano quedaba ordenada al azar.
// Se conecta con: caches (colecciones/detalle en memoria) + ContentDao.
// Parte del flujo: Mi Espacio → playlists (crear/editar).
// ─────────────────────────────────────────────────────────────

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../shared/utilidades/portada/caratula_util.dart';
import '../../base_datos/app_database.dart';
import '../../base_datos/daos/content_dao.dart';
import '../../cache/almacenes/cache_colecciones.dart';
import '../../cache/almacenes/cache_detalle_memoria.dart';
import '../../modelos/feed/item_feed.dart';

part 'editor_playlist_biblioteca.dart';

/// Guarda playlists creadas o editadas desde la hoja de playlist.
class ServicioEditorPlaylist with ServicioEditorPlaylistBiblioteca {
  final CacheColecciones _colecciones;
  @override
  final ContentDao _contenido;
  final CacheDetalleMemoria _memoria;

  ServicioEditorPlaylist(AppDatabase db, this._colecciones, this._memoria)
    : _contenido = ContentDao(db);

  /// Suma UNA canción al final de una playlist existente, sin duplicarla, y
  /// deja su metadata en la biblioteca local (si no, el detalle no tendría ni
  /// nombre ni artista). Devuelve true si quedó agregada.
  Future<bool> agregarItem(String playlistId, ItemFeed item) async {
    try {
      if (playlistId.isEmpty || item.id.isEmpty) return false;
      final ids = await _colecciones.getTrackIdsColeccion(playlistId);
      if (ids.contains(item.id)) return false;
      await sincronizarItemEnBiblioteca(item);
      await _colecciones.reordenarItemsColeccion(playlistId, [...ids, item.id]);
      _memoria.invalidarPlaylist(playlistId);
      return true;
    } catch (e) {
      debugPrint('[Playlist] no se pudo agregar la canción: $e');
      return false;
    }
  }

  /// Crea (o actualiza) la playlist y la deja con EXACTAMENTE [items], en ese
  /// orden. Devuelve el id guardado, o null si algo falló.
  ///
  /// [playlistId] null = nueva. [portada] vacía = sin portada propia (la
  /// tarjeta cae a la carátula de la primera canción).
  Future<String?> guardar({
    String? playlistId,
    required String nombre,
    required String portada,
    required List<ItemFeed> items,
  }) async {
    try {
      String? id = playlistId;
      if (id == null || id.isEmpty) {
        id = await _colecciones.crearColeccion(nombre, portada);
      } else {
        await _colecciones.actualizarDatosColeccion(id, nombre, portada);
      }
      if (id == null || id.isEmpty) return null;

      for (final item in items) {
        await sincronizarItemEnBiblioteca(item);
      }
      await _colecciones.reordenarItemsColeccion(
        id,
        items.map((i) => i.id).toList(),
      );

      // El detalle en memoria (5 min) mostraría la versión vieja.
      _memoria.invalidarPlaylist(id);
      return id;
    } catch (e) {
      debugPrint('[Playlist] no se pudo guardar: $e');
      return null;
    }
  }
}
