// ─────────────────────────────────────────────────────────────
// contenido_mi_espacio_helpers.dart — PART de contenido_mi_espacio
// .dart: helpers de resolución del contenido — estado de descarga
// de un track (por clave de fuente, escaneo por prefijo y huellas/
// ISRC), mejor carátula de un ítem de grilla (propia, local del
// like o del lote que lo contiene) y conversión Item → ItemFeed
// para los servicios compartidos.
// Se conecta con: contenido_mi_espacio.dart (misma library) +
// cubit_like + cubit_descargas + huella_item.
// Parte del flujo: Home → Mi Espacio (helpers del contenido).
// ─────────────────────────────────────────────────────────────

part of 'contenido_mi_espacio.dart';

/// Estado de descarga de un track: clave de fuente exacta, luego
/// escaneo por prefijo (cualquier fuente del mismo ID) y huellas.
EstadoDescarga _estadoTrackPara(ContenidoMiEspacio c, ItemFeed item, String id) {
  final s = c.estadosDescarga[id];
  if (s != null && s != EstadoDescarga.ninguno) return s;
  final normId = normalizarIdTrack(item.id);
  final prefijo = 'track_${normId}_';
  for (final key in c.estadosDescarga.keys) {
    if (key.startsWith(prefijo)) {
      final estado = c.estadosDescarga[key];
      if (estado != null && estado != EstadoDescarga.ninguno) return estado;
    }
  }
  final huella = huellaItem(item);
  if (c.huellasDescargadas.contains(huella)) return EstadoDescarga.completado;
  final isrc = (item.isrc ?? '').trim();
  if (isrc.isNotEmpty && c.huellasDescargadas.contains(huellaIsrc(isrc))) {
    return EstadoDescarga.completado;
  }
  return EstadoDescarga.ninguno;
}

/// Resuelve la mejor carátula de un ítem de grilla: la propia, la
/// guardada localmente por like o la del lote descargado que lo contiene.
String? _resolverCaratula(BuildContext context, ContenidoMiEspacio c, Item item) {
  if (item.coverUrl?.isNotEmpty == true) return item.coverUrl;
  try {
    final likeCubit = context.read<CubitLikes>();
    final feed = _itemFeedPara(c, item);
    final local = likeCubit.caratulaLocalPara(feed);
    if (local != null && local.isNotEmpty) return local;
    if (item.tipo == TipoItem.album || item.tipo == TipoItem.playlist) {
      final dlCubit = context.read<CubitDescargas>();
      final normId = normalizarIdTrack(item.idReal);
      final prefijo = item.tipo == TipoItem.album ? 'album_' : 'playlist_';
      for (final entry in dlCubit.state.descargas.entries) {
        if (!entry.key.startsWith(prefijo)) continue;
        if (entry.value.estado != EstadoDescarga.completado) continue;
        final parts = entry.key.split('_');
        if (parts.length < 3) continue;
        final keyNormId =
            normalizarIdTrack(parts.sublist(1, parts.length - 1).join('_'));
        if (keyNormId == normId) {
          final caratula = dlCubit.caratulaLotePara(entry.key);
          if (caratula.isNotEmpty) return caratula;
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Identificadores de proveedor conocidos por el sistema de descargas.
const _fuentesConocidas = {
  'apple-music', 'spotify-web', 'spotify', 'deezer', 'deezer-web',
  'soundcloud', 'tidal-web', 'qobuz-web', 'pandora',
  'ytmusic-spotiflac', 'amazon',
};

/// Estado de descarga de un ítem de grilla: por clave exacta
/// (tipo + ID + fuente) o escaneo source-agnostic del mismo ID con
/// validación de que la fuente sea un proveedor conocido.
EstadoDescarga _resolverEstadoDescarga(
  Map<String, EstadoDescarga> estados,
  String tipo,
  Item item,
) {
  final normId = normalizarIdTrack(item.idReal);
  if (normId.isEmpty) return EstadoDescarga.ninguno;
  // 1) Coincidencia exacta: tipo + ID normalizado + fuente.
  final exactId = '${tipo}_${normId}_${item.fuente}';
  final exact = estados[exactId];
  if (exact != null) return exact;
  // 2) Source-agnostic: parsear la clave para que el segmento del ID
  //    coincida EXACTAMENTE (evita que 'pl' matchee 'pl.xxx').
  final prefijo = '${tipo}_${normId}_';
  final largoPrefijo = prefijo.length;
  EstadoDescarga mejor = EstadoDescarga.ninguno;
  for (final key in estados.keys) {
    if (!key.startsWith(prefijo)) continue;
    final fuente = key.substring(largoPrefijo);
    if (fuente.isEmpty) continue;
    if (!_fuentesConocidas.contains(fuente)) continue;
    final estado = estados[key];
    if (estado == null) continue;
    if (estado == EstadoDescarga.enProgreso) return estado;
    if (estado == EstadoDescarga.enCola && mejor != EstadoDescarga.enProgreso) {
      mejor = estado;
    }
    if (estado == EstadoDescarga.interrumpido && mejor == EstadoDescarga.ninguno) {
      mejor = estado;
    }
    if (estado == EstadoDescarga.completado && mejor == EstadoDescarga.ninguno) {
      mejor = estado;
    }
  }
  return mejor;
}

/// Convierte un Item en ItemFeed para los servicios compartidos.
ItemFeed _itemFeedPara(ContenidoMiEspacio c, Item item) {
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
    source: item.fuente,
  );
}