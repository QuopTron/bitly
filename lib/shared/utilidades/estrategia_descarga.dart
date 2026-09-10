// ─────────────────────────────────────────────────────────────
// estrategia_descarga.dart — Helpers de descarga compartidos:
// normaliza ids de tracks (quitando prefijos de proveedor como
// "spotify-web/" o "deezer:playlist:") y arma el mapa de metadata
// común (track_id, isrc, duración...) que esperan Go y el sistema
// de progreso. También despacha descargas individuales a través
// del CubitDescargas (directo en batch o encolado desde la UI).
// Se conecta con: cubit_descargas + modelos (ajustes_descarga) +
// backend_go (metadata de descarga).
// Parte del flujo: búsqueda, feed, detalle (botón de descargar).
// ─────────────────────────────────────────────────────────────

import '../../estado/cubit_descargas.dart';
import '../../core/modelos/ajustes_descarga.dart';

/// Normaliza un id de track/álbum/playlist quitando cualquier prefijo
/// de proveedor (p.ej. "spotify-web/", "spotify:track:", "deezer:playlist:")
/// y lo pasa a minúsculas. Devuelve el [id] sin transformar si no aplica.
String normalizarIdTrack(String id) {
  final lastSep = id.lastIndexOf('/');
  final lastColon = id.lastIndexOf(':');
  final split = lastSep > lastColon ? lastSep : lastColon;
  if (split > 0 && split < id.length - 1) {
    return id.substring(split + 1).toLowerCase();
  }
  return id.toLowerCase();
}

/// Arma el mapa de metadata común para el despacho de una descarga.
/// Las claves son las que esperan Go y el sistema de progreso.
Map<String, dynamic> construirMetaTrack({
  required String trackId,
  required String trackTitle,
  required String artistName,
  required String albumName,
  required String source,
  required String isrc,
  required int durationMs,
  String? coverUrl,
}) {
  return {
    'track_id': trackId,
    'item_id': trackId,
    'track_title': trackTitle,
    'artist_name': artistName,
    'album_name': albumName,
    'source': source,
    'isrc': isrc,
    'duration_ms': durationMs,
    if (coverUrl != null) 'cover_url': coverUrl,
  };
}

/// Despacha las descargas de audio (y opcionalmente video/letras) de un
/// track. [esDespachoBatch] true = ya va en una cola batch (despacha
/// directo); false = desde la UI (encola en el lote de individuales).
void despacharDescargas({
  required CubitDescargas cubit,
  required Map<String, dynamic> metaComun,
  required AjustesDescarga ajustes,
  required String baseId,
  String? calidadForzada,
  bool esDespachoBatch = false,
}) {
  if (esDespachoBatch) {
    cubit.despacharTrackIndividual(
      metaComun: metaComun,
      ajustes: ajustes,
      baseId: baseId,
      calidadForzada: calidadForzada,
    );
  } else {
    cubit.encolarTrackIndividual(
      metaComun: metaComun,
      ajustes: ajustes,
      baseId: baseId,
      calidadForzada: calidadForzada,
    );
  }
}