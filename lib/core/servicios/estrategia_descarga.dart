// ─────────────────────────────────────────────────────────────
// estrategia_descarga.dart — Estrategia de descarga: construye el
// mapa de metadatos común (track_id, item_id, títulos, fuente,
// isrc...) que el backend Go y el tracker de progreso esperan, y
// despacha la descarga de un track único (directa si viene de una
// cola de lote, encolada si viene de la UI). La normalización de IDs
// vive en utilidades_id.dart (normalizarId).
// Se conecta con: CubitDescargas (despacho) + backend Go.
// Parte del flujo: descargas (botón de descarga y lotes).
// ─────────────────────────────────────────────────────────────

import '../modelos/ajustes_descarga.dart';
import '../../estado/cubit_descargas.dart';

/// Construye el mapa de metadatos común para un despacho de descarga.
/// Devuelve un Map con las keys que esperan el backend Go y el sistema de
/// tracking de progreso.
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

/// Despacha la descarga de audio (y opcionalmente video/letras) de un track.
/// Delega en CubitDescargas para que las actualizaciones de estado ocurran
/// dentro del cubit donde `emit` es accesible.
///
/// [esDespachoDeLote] true (llamado desde la cola de lote) despacha directo;
/// false (track único desde la UI) encola vía el lote de singles.
void despacharDescargas({
  required CubitDescargas cubit,
  required Map<String, dynamic> metaComun,
  required AjustesDescarga ajustes,
  required String baseId,
  String? calidadForzada,
  bool esDespachoDeLote = false,
}) {
  if (esDespachoDeLote) {
    // Ya está en una cola de lote — despachar directo.
    cubit.despacharTrackIndividual(
      metaComun: metaComun,
      ajustes: ajustes,
      baseId: baseId,
      calidadForzada: calidadForzada,
    );
  } else {
    // Track único desde la UI — encolar en el lote de singles.
    cubit.encolarTrackIndividual(
      metaComun: metaComun,
      ajustes: ajustes,
      baseId: baseId,
      calidadForzada: calidadForzada,
    );
  }
}