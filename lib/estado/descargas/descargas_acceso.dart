// ─────────────────────────────────────────────────────────────
// descargas_acceso.dart — PART de cubit_descargas.dart: consultas
// de estado y metadata para la UI: estado de una descarga, metadata
// de track (nombre/artista/carátula), fuente de un lote, persistencia
// de un lote completado (con invalidación de caches), helpers
// sha1/sanitización, carátulas de tracks y lotes, cheques de
// colección descargada y si el padre del lote sigue amado.
// Se conecta con: descargas_estado.dart (misma library).
// Parte del flujo: descargas (Mi Espacio y detalle).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Consultas y metadata. Mixin aplicado en CubitDescargas.
mixin DescargasAcceso on DescargasLoteFinalizar {
  DatosEstadoDescarga estadoDescargaPara(String id) =>
      state.descargas[id] ?? const DatosEstadoDescarga();

  /// Devuelve la metadata cacheada (nombre, artista, carátula) de un state
  /// key, o null si no está disponible. Lo usan las páginas de detalle para
  /// resolver nombres desde lotes cuando la API aún no cargó.
  ({String name, String artist, String cover})? metaTrackPara(String stateKey) {
    final m = _metaTrack[stateKey];
    if (m == null) return null;
    return (
      name: m.name,
      artist: m.artist ?? '',
      cover: m.coverUrl ?? m.coverPath ?? '',
    );
  }

  /// Encuentra la fuente usada para descargar un lote (álbum/playlist).
  /// Chequea _metaLote primero, luego escanea las keys de state.descargas.
  String buscarFuenteLote(String type, String itemId) {
    final normId = normalizarId(itemId);
    // 1) _metaLote por coincidencia exacta.
    for (final entry in _metaLote.entries) {
      final key = entry.key; // p.ej. 'playlist_normId_ytmusic-spotiflac'
      if (key.startsWith('${type}_') && key.contains('_${normId}_')) {
        return entry.value.source;
      }
    }
    // 2) Escanear state.descargas buscando la key de lote.
    for (final key in state.descargas.keys) {
      if (key.startsWith('${type}_') && key.contains('_${normId}_')) {
        final parts = key.split('_');
        if (parts.length >= 3) return parts.last;
      }
    }
    // 3) La BD ya se chequeó en la carga; sin lote → fuente vacía.
    return '';
  }

  /// SHA-1 hex digest, coincide con el utils.HashString de Go.
  String _sha1Hex(String input) => sha1.convert(utf8.encode(input)).toString();

  /// Sanitiza un nombre de archivo para que coincida con utils.SanitizeFilename
  /// de Go.
  String _sanitizarNombreArchivo(String name) {
    const invalid = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];
    var result = name;
    for (final ch in invalid) {
      result = result.replaceAll(ch, '_');
    }
    result = result
        .replaceAll(RegExp(r'^[. ]+'), '')
        .replaceAll(RegExp(r'[. ]+$'), '');
    return result.isEmpty ? 'unknown' : result;
  }

  /// Mejor carátula disponible de un track descargado: ruta local VIVA (si
  /// se guardó y sigue en disco) → URL remota → null. Una ruta local muerta
  /// no gana: dejaría la tarjeta gris con la URL remota disponible.
  String? caratulaTrackLocal(String trackId, String source) {
    final key = 'track_${normalizarId(trackId)}_$source';
    final meta = _metaTrack[key];
    return mejorCaratula(meta?.coverPath, meta?.coverUrl);
  }

  /// Nombre almacenado de un lote (álbum/playlist), o vacío.
  String nombreLotePara(String batchKey) => _metaLote[batchKey]?.name ?? '';

  /// Lista de state keys de tracks que pertenecen a un lote.
  List<String> idsLotePara(String batchKey) =>
      _batchTrackIds[batchKey] ?? const [];

  /// Mejor carátula de un lote: ruta local VIVA primero, luego URL, o vacía.
  String caratulaLotePara(String batchKey) {
    final meta = _metaLote[batchKey];
    if (meta != null) {
      final propia = mejorCaratula(meta.coverPath, meta.coverUrl);
      if (propia != null && propia.isNotEmpty) return propia;
    }
    // Fallback en runtime: buscar en _metaTrack el primer track del lote.
    final trackIds = _batchTrackIds[batchKey];
    if (trackIds != null && trackIds.isNotEmpty) {
      for (final tid in trackIds) {
        final tm = _metaTrack[tid];
        if (tm == null) continue;
        final delTrack = mejorCaratula(tm.coverPath, tm.coverUrl);
        if (delTrack != null && delTrack.isNotEmpty) return delTrack;
      }
    }
    return '';
  }

  /// ¿Esta canción ya está en disco? Clave exacta (id + fuente) o por ISRC
  /// cuando se bajó desde otra extensión (misma grabación, identidad exacta).
  /// Lo usan los detalles de álbum/playlist para contar y para no volver a
  /// bajar lo que ya está.
  bool trackDescargado(String trackId, {String source = '', String? isrc}) =>
      trackDescargadoEnEstado(
        descargas: state.descargas,
        huellasDescargadas: state.huellasDescargadas,
        trackId: trackId,
        source: source,
        isrc: isrc,
      );

  /// True cuando el álbum/playlist dueño de [batchKey] sigue amado. Su
  /// carátula NO se debe borrar al quitar la descarga porque Mi Espacio sigue
  /// mostrando esa misma carátula para el item amado.
  bool _padreAmado(String batchKey) {
    final parts = batchKey.split('_');
    if (parts.length < 3) return false;
    final type = parts.first;
    if (type != 'album' && type != 'playlist') return false;
    final parentId = parts.sublist(1, parts.length - 1).join('_');
    if (parentId.isEmpty) return false;
    final likeCubit = di.sl<CubitLikes>();
    return likeCubit.state.todosAmados.values.any(
      (i) => i.type == type && normalizarId(i.id) == parentId,
    );
  }
}
