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

import '../../app/inyeccion.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/cache/cache_colecciones.dart';
import '../../core/cache/estado_descarga.dart';
import '../../core/cache/estado_like.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/estrategia_descarga.dart';
import 'modelos_item.dart';

part 'datos_mi_espacio_items.dart';
part 'datos_mi_espacio_items2.dart';

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
List<Item> itemsParaPestana(
  EstadoLikes estadoLike,
  int pestana,
  List<Item> playlistsCreadas, {
  CubitDescargas? cubitDescargas,
}) {
  switch (pestana) {
    case 0:
      return _itemsCanciones(estadoLike, cubitDescargas);
    case 1:
      return _itemsPlaylists(estadoLike, playlistsCreadas, cubitDescargas);
    case 2:
      return _itemsAlbumes(estadoLike, cubitDescargas);
    case 3:
      return _itemsArtistas(estadoLike);
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

/// Quita el like de un ítem de la pestaña [pestana].
void quitarLikeItem(Item item, BuildContext context, int pestana) {
  if (item.idReal.isEmpty) return;
  final tipo = tipoParaPestana(pestana);
  context.read<CubitLikes>().quitarLikePorId(
    item.idReal,
    tipo,
    item.titulo,
    item.subtitulo,
    item.coverUrl,
  );
}

/// Tipo de ítem (string) según la pestaña activa.
String tipoParaPestana(int pestana) {
  switch (pestana) {
    case 0:
      return 'track';
    case 1:
      return 'playlist';
    case 2:
      return 'album';
    case 3:
      return 'artist';
    default:
      return '';
  }
}

/// Contador de canciones amadas + descargadas con la misma dedup
/// que itemsParaPestana (para la insignia del perfil).
int contarTracks(EstadoLikes estado, {CubitDescargas? cubitDescargas}) {
  final vistosId = <String>{};
  final vistosClave = <String>{};
  for (final i in estado.todosAmados.values.where((i) => i.type == 'track')) {
    vistosId.add(normalizarIdTrack(i.id));
    vistosClave.add('${_normalizarNombre(i.name)}|${_normalizarNombre(i.artists ?? '')}');
  }
  var count = vistosId.length;
  if (cubitDescargas != null) {
    for (final t in cubitDescargas.tracksCompletados) {
      final normId = normalizarIdTrack(t.id);
      final clave = '${_normalizarNombre(t.name)}|${_normalizarNombre(t.artists ?? '')}';
      if (!vistosId.contains(normId) && !vistosClave.contains(clave)) {
        vistosId.add(normId);
        vistosClave.add(clave);
        count++;
      }
    }
  }
  return count;
}