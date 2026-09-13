// ─────────────────────────────────────────────────────────────
// descargas_modelos.dart — PART de cubit_descargas.dart: clases
// auxiliares de datos del cubit de descargas: datos originales de
// un lote (para reintentar tracks fallidos), un track esperando en
// la cola secuencial, metadata persistente de un track descargado
// y metadata de un lote (álbum/playlist) descargado.
// Se conecta con: descargas_base.dart (misma library).
// Parte del flujo: descargas (estado y reintentos).
// ─────────────────────────────────────────────────────────────

part of 'cubit_descargas.dart';

/// Guarda los datos originales de los tracks de un lote para poder reintentar
/// los que fallaron después.
class _DatosLote {
  final List<Map<String, dynamic>> tracks;
  final AjustesDescarga ajustes;
  final String source;
  final String? calidadForzada;

  const _DatosLote(this.tracks, this.ajustes, this.source, [this.calidadForzada]);
}

/// Un track individual esperando en la cola secuencial de descargas.
class _TrackEnCola {
  final Map<String, dynamic> trackMap;
  final String trackId;
  final String source;
  final AjustesDescarga ajustes;
  final String? calidadForzada;
  final String? batchKey;

  const _TrackEnCola(this.trackMap, this.trackId, this.source, this.ajustes,
      [this.calidadForzada, this.batchKey]);
}

/// Metadata persistente de un track descargado (sobrevive reinicios vía BD).
class _InfoTrack {
  final String trackId;
  final String name;
  final String? artist;
  final String? coverUrl;
  final String? coverPath;
  final String source;

  /// ISRC cuando se conoce al despachar (sobrevive ids de proveedor vacíos —
  /// amazon/otros resuelven ASINs reales por ISRC aunque el track del feed
  /// no traiga id).
  final String isrc;

  const _InfoTrack(this.trackId, this.name, this.artist, this.coverUrl,
      this.source, [this.coverPath, this.isrc = '']);
}

/// Metadata de un lote (álbum/playlist) descargado.
class _MetaLote {
  final String name;
  final String itemType;
  final String itemId;
  final String source;
  final String coverUrl;
  final String coverPath;

  const _MetaLote(this.name, this.itemType, this.itemId, this.source,
      {this.coverUrl = '', this.coverPath = ''});
}