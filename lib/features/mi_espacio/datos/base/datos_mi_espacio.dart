// ─────────────────────────────────────────────────────────────
// datos_mi_espacio.dart — Carga y transformación de datos de Mi
// Espacio: username, playlists propias (drift) y los ítems de
// cada pestaña combinando likes y descargas con deduplicación
// por ID y nombre. Incluye contador, mensaje de vacío y quitar.
// Se conecta con: cache_colecciones + cache_ajustes + cubits.
// Parte del flujo: Home → Mi Espacio (datos de las pestañas).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/base_datos/app_database.dart';
import '../../../../core/base_datos/daos/contenido/content_dao.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../core/cache/almacenes/biblioteca/base/cache_colecciones.dart';
import '../../../../shared/utilidades/portada/base/caratula_util.dart';
import '../../../../core/cache/estado/estado_descarga.dart';
import '../../../../core/cache/estado/estado_like.dart';
import '../../../../estado/descargas/cubit_descargas.dart';
import '../../../../estado/like/base/cubit_like.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../modelos_item.dart';

part '../items/datos_mi_espacio_items.dart';
part '../items/datos_mi_espacio_items2.dart';
part 'datos_mi_espacio_biblioteca.dart';
part '../items/datos_mi_espacio_acciones.dart';

/// Playlists propias (drift) — con insignia "propia".
Future<List<Item>> cargarPlaylistsPropias() async {
  try {
    final cache = sl<CacheColecciones>();
    final cols = await cache.getTodasLasPlaylists();
    return cols.map((c) {
      final cover = limpiarRutaCaratulaLocal(c.coverPath ?? '');
      return Item(
        c.name,
        '',
        TipoItem.playlist,
        coverUrl: cover?.isNotEmpty == true ? cover : null,
        idReal: c.id,
        origen: OrigenItem.propio,
      );
    }).toList();
  } catch (e) {
    debugPrint('[datos_mi_espacio] $e');
    return [];
  }
}

/// Username guardado en los ajustes (drift).
Future<String> cargarUsername() async {
  try {
    final cache = sl<CacheAjustes>();
    final setup = await cache.cargarDatosSetup();
    return setup?.username ?? '';
  } catch (e) {
    debugPrint('[datos_mi_espacio] $e');
    return '';
  }
}

/// Minúsculas, sin espacios extra (dedup cross-extensión).
/// Espacios colapsados a uno. La expresión se compila UNA vez: esto corre
/// dentro de los bucles que arman la biblioteca entera (todos los likes y
/// todas las descargas), así que recrear el `RegExp` por ítem se pagaba en
/// cada armado de Mi Espacio.
final RegExp _reEspaciosNombre = RegExp(r'\s+');

String _normalizarNombre(String n) =>
    n.toLowerCase().trim().replaceAll(_reEspaciosNombre, ' ');

/// Ítems de la pestaña [pestana] combinando likes + descargas.
/// [biblioteca] es el índice local (nombre + carátula) que actúa como
/// último respaldo para que ninguna tarjeta quede gris ni sin título;
/// por defecto usa el índice ya cargado por la página.
List<Item> itemsParaPestana(
  EstadoLikes estadoLike,
  int pestana,
  List<Item> playlistsCreadas, {
  CubitDescargas? cubitDescargas,
  Map<String, DatoBiblioteca>? biblioteca,
}) {
  final bib = biblioteca ?? bibliotecaLocal;
  switch (pestana) {
    case 0:
      return _itemsCanciones(estadoLike, cubitDescargas, bib);
    case 1:
      return _itemsPlaylists(estadoLike, playlistsCreadas, cubitDescargas, bib);
    case 2:
      return _itemsAlbumes(estadoLike, cubitDescargas, bib);
    case 3:
      return _itemsArtistas(estadoLike, bib);
    default:
      return [];
  }
}

/// Mensaje de estado vacío de la pestaña activa.
String mensajeVacio(AppLocalizations loc, int pestana) {
  switch (pestana) {
    case 0:
      return loc.setup.miSpaceEmptySongs;
    case 1:
      return loc.setup.miSpaceEmptyPlaylists;
    case 2:
      return loc.setup.miSpaceEmptyAlbums;
    case 3:
      return loc.setup.miSpaceEmptyArtists;
    default:
      return '';
  }
}
