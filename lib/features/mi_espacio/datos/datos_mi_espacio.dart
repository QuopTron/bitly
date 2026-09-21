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

import '../../../app/inyeccion.dart';
import '../../../core/base_datos/app_database.dart';
import '../../../core/base_datos/daos/content_dao.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/cache/almacenes/cache_colecciones.dart';
import '../../../shared/utilidades/portada/caratula_util.dart';
import '../../../core/cache/estado/estado_descarga.dart';
import '../../../core/cache/estado/estado_like.dart';
import '../../../estado/descargas/cubit_descargas.dart';
import '../../../estado/like/cubit_like.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../modelos_item.dart';

part 'datos_mi_espacio_items.dart';
part 'datos_mi_espacio_items2.dart';
part 'datos_mi_espacio_biblioteca.dart';
part 'datos_mi_espacio_acciones.dart';

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
  } catch (_) {
    return [];
  }
}

/// Username guardado en los ajustes (drift).
Future<String> cargarUsername() async {
  try {
    final cache = sl<CacheAjustes>();
    final setup = await cache.cargarDatosSetup();
    return setup?.username ?? '';
  } catch (_) {
    return '';
  }
}

/// Minúsculas, sin espacios extra (dedup cross-extensión).
String _normalizarNombre(String n) =>
    n.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

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
