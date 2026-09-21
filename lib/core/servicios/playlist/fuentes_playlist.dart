// ─────────────────────────────────────────────────────────────
// fuentes_playlist.dart — De dónde saca una playlist sus canciones:
// "likeadas" (tracks amados) y "descargadas" (historial de descargas,
// incluyendo las que bajaron dentro de un álbum o una playlist).
//
// Por qué existe: los atajos de la hoja de playlist leían el estado EN
// MEMORIA de los cubits, que se carga async al arrancar. Abrir el armado
// antes de que terminara (o tener más de 100 descargas) sumaba cero
// canciones y parecía roto. Acá se lee la base local y siempre trae todo.
// Se conecta con: CacheFavoritos + CacheDescargas + huella_item.
// Parte del flujo: Mi Espacio / detalle → playlists (agregar canciones).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../shared/utilidades/portada/caratula_util.dart';
import '../../cache/almacenes/cache_descargas.dart';
import '../../cache/almacenes/cache_favoritos.dart';
import '../../modelos/feed/item_feed.dart';
import '../utilidades/huella_item.dart';
import '../utilidades/utilidades_id.dart';

/// Canciones disponibles para llenar una playlist propia.
class FuentesPlaylist {
  final CacheFavoritos _favoritos;
  final CacheDescargas _descargas;

  FuentesPlaylist(this._favoritos, this._descargas);

  /// Tracks amados (el corazón), sin repetir la misma canción.
  Future<List<ItemFeed>> likeadas() async =>
      _dedup(_itemsLike(await _filas(_favoritos.getTracksAmados)));

  /// Tracks descargados, de cualquier origen (sueltos o dentro de un
  /// álbum/playlist), sin repetir la misma canción.
  Future<List<ItemFeed>> descargadas() async =>
      _dedup(_itemsDescarga(await _filas(_descargas.getHistorialCompleto)));

  /// Filas crudas de una de las dos cachés (tolera vacío o corrupto).
  Future<List<Map<String, dynamic>>> _filas(
    Future<String> Function() traer,
  ) async {
    try {
      final json = await traer();
      if (json.isEmpty || json == '[]') return const [];
      return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Playlist] no se pudo leer la fuente: $e');
      return const [];
    }
  }

  /// Filas del JSON de favoritos (`trackId`/`trackName`/...).
  List<ItemFeed> _itemsLike(List<Map<String, dynamic>> filas) => [
    for (final m in filas)
      if (_texto(m, ['trackId', 'track_id']).isNotEmpty)
        ItemFeed(
          id: _texto(m, ['trackId', 'track_id']),
          type: 'track',
          name: _texto(m, ['trackName', 'track_name']),
          artists: _texto(m, ['artistName', 'artist_name']),
          albumName: _texto(m, ['albumName', 'album_name']),
          coverUrl: mejorCaratula(
            _texto(m, ['coverPath']),
            _texto(m, ['coverUrl', 'cover_url']),
          ),
          durationMs: _entero(m, ['durationMs', 'duration_ms']),
          isrc: _texto(m, ['isrc']),
          source: _texto(m, ['provider', 'source']),
        ),
  ];

  /// Filas del historial de descargas (snake_case + basura fuera).
  List<ItemFeed> _itemsDescarga(List<Map<String, dynamic>> filas) {
    final items = <ItemFeed>[];
    for (final m in filas) {
      final id = _texto(m, ['providerTrackId', 'id']);
      if (id.isEmpty || !_archivoVivo(m)) continue;
      items.add(
        ItemFeed(
          id: id,
          type: 'track',
          name: _texto(m, ['track_name', 'trackName']),
          artists: _texto(m, ['artist_name', 'artistName']),
          albumName: _texto(m, ['album_name', 'albumName']),
          coverUrl: mejorCaratula(
            _texto(m, ['cover_path']),
            _texto(m, ['cover_url']),
          ),
          durationMs: _entero(m, ['duration']),
          isrc: _texto(m, ['isrc']),
          source: _texto(m, ['providerSource', 'service']),
        ),
      );
    }
    return items;
  }

  /// True si la descarga sigue en disco (una fila sin archivo no suena).
  bool _archivoVivo(Map<String, dynamic> m) {
    final ruta = _texto(m, ['file_path']);
    if (ruta.isEmpty) return true;
    try {
      return File(ruta).existsSync();
    } catch (_) {
      return true;
    }
  }

  /// Una sola copia por id normalizado y huella, como Mi Espacio.
  List<ItemFeed> _dedup(List<ItemFeed> items) {
    final ids = <String>{};
    final huellas = <String>{};
    final salida = <ItemFeed>[];
    for (final item in items) {
      if (!ids.add(normalizarId(item.id))) continue;
      if (item.name.isNotEmpty &&
          !huellas.add(huellaDesdeNombre(item.name, item.artists ?? ''))) {
        continue;
      }
      salida.add(item);
    }
    return salida;
  }
}

/// Primer valor de texto no vacío entre [claves].
String _texto(Map<String, dynamic> m, List<String> claves) {
  for (final clave in claves) {
    final valor = m[clave];
    if (valor == null) continue;
    final texto = valor.toString().trim();
    if (texto.isNotEmpty) return texto;
  }
  return '';
}

/// Primer valor numérico entre [claves] (null si no hay).
int? _entero(Map<String, dynamic> m, List<String> claves) {
  for (final clave in claves) {
    final valor = m[clave];
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor);
  }
  return null;
}
