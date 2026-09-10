// ─────────────────────────────────────────────────────────────
// cache_descargas.dart — Caché local del historial de descargas
// (wrapper sobre DownloadDao): historial, lotes (batch), tracks
// descargados y rutas de archivo.
// Se conecta con: base_datos (DownloadDao) + DownloadCubit.
// Parte del flujo: descargas (Mi Espacio y botón de descarga).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../base_datos/app_database.dart';
import '../base_datos/daos/download_dao.dart';

/// Caché local de historial de descargas — wrappers sobre [DownloadDao].
class CacheDescargas {
  final DownloadDao _dao;
  CacheDescargas(AppDatabase db) : _dao = DownloadDao(db);

  Future<String> getHistorialDescargas({String? desde}) async {
    final items = await _dao.getHistory(since: desde);
    final lista = items.map((e) => <String, dynamic>{
      'id': e.id, 'track_name': e.trackName,
      'artist_name': e.artistName, 'album_name': e.albumName ?? '',
      'isrc': e.isrc ?? '', 'file_path': e.filePath ?? '',
      'service': e.service ?? '', 'duration': e.duration ?? 0,
      'downloaded_at': e.downloadedAt.toIso8601String(),
      'providerTrackId': e.providerTrackId ?? e.id,
      'providerSource': e.providerSource ?? e.service ?? '',
      'cover_url': e.coverUrl ?? '', 'cover_path': e.coverPath ?? '',
    }).toList();
    return jsonEncode(lista);
  }

  Future<String> getLotesDescargados({String? desde}) async {
    final items = await _dao.getBatches(since: desde);
    final lista = items.map((e) => <String, dynamic>{
      'batch_key': e.batchKey, 'item_type': e.itemType ?? '',
      'item_id': e.itemId ?? '', 'source': e.source ?? '',
      'name': e.name ?? '', 'downloaded_at': e.downloadedAt.toIso8601String(),
      'track_ids': e.trackIds ?? '',
      'cover_url': e.coverUrl ?? '',
      'cover_path': e.coverPath ?? '',
    }).toList();
    return jsonEncode(lista);
  }

  /// Guarda un lote de descarga. [trackIds] son state-keys de tracking;
  /// [trackMeta] (paralela, opcional) guarda `name/artist/cover` junto a los
  /// IDs para que las páginas de detalle reconstruyan nombres sin historial.
  Future<void> guardarLoteDescargado(
    String key,
    String type,
    String id,
    String source,
    String name, {
    List<String>? trackIds,
    List<Map<String, dynamic>>? trackMeta,
    String? coverUrl,
    String? coverPath,
  }) async {
    // Codifica trackIds como JSON array. Si hay trackMeta guardamos objetos
    // `{id, name, artist, cover}` para que _construirDesdeLote() tenga nombres.
    String? codificado;
    if (trackIds != null) {
      if (trackMeta != null && trackMeta.length == trackIds.length) {
        final enriquecidos = <Map<String, dynamic>>[];
        for (var i = 0; i < trackIds.length; i++) {
          enriquecidos.add({
            'id': trackIds[i],
            'name': (trackMeta[i]['name'] ?? '') as String,
            'artist': (trackMeta[i]['artist'] ?? '') as String,
            'cover': (trackMeta[i]['cover'] ?? '') as String,
          });
        }
        codificado = jsonEncode(enriquecidos);
      } else {
        codificado = jsonEncode(trackIds);
      }
    }
    await _dao.saveBatch(DownloadBatchesCompanion(
      batchKey: Value(key),
      itemType: Value(type),
      itemId: Value(id),
      source: Value(source),
      name: Value(name),
      trackIds: codificado != null ? Value(codificado) : const Value.absent(),
      downloadedAt: Value(DateTime.now()),
      coverUrl: coverUrl != null ? Value(coverUrl) : const Value.absent(),
      coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
    ));
  }

  Future<void> guardarTrackDescargado({
    required String id,
    required String trackName,
    required String artistName,
    String? albumName,
    String? isrc,
    String? filePath,
    String? service,
    int? duration,
    String? providerTrackId,
    String? providerSource,
    String? coverUrl,
    String? coverPath,
  }) => _dao.saveEntry(DownloadHistoryCompanion.insert(
    id: id,
    trackName: trackName,
    artistName: artistName,
    downloadedAt: DateTime.now(),
    albumName: albumName != null ? Value(albumName) : const Value.absent(),
    isrc: isrc != null ? Value(isrc) : const Value.absent(),
    filePath: filePath != null ? Value(filePath) : const Value.absent(),
    service: service != null ? Value(service) : const Value.absent(),
    duration: duration != null ? Value(duration) : const Value.absent(),
    providerTrackId: providerTrackId != null ? Value(providerTrackId) : const Value.absent(),
    providerSource: providerSource != null ? Value(providerSource) : const Value.absent(),
    coverUrl: coverUrl != null ? Value(coverUrl) : const Value.absent(),
    coverPath: coverPath != null ? Value(coverPath) : const Value.absent(),
  ));

  Future<void> borrarTracksDescargados(List<String> ids) async {
    for (final id in ids) {
      await _dao.removeById(id);
    }
  }

  Future<String?> getRutaArchivoPorId(String id) => _dao.getFilePathById(id);

  Future<DownloadBatche?> getLotePorItem(String itemType, String itemId, String source) =>
      _dao.getBatchByItem(itemType, itemId, source);

  Future<void> quitarLotePorItem(String itemType, String itemId, String source) =>
      _dao.removeBatchByItem(itemType, itemId, source);

  Future<void> quitarLotes(List<String> keys) => _dao.removeBatches(keys);

  /// Cuenta cuántos lotes referencian [trackId] en su track_ids.
  Future<int> contarLotesReferenciandoTrack(String trackId) =>
      _dao.countBatchesReferencingTrack(trackId);

  /// Actualiza la ruta de archivo de una entrada del historial.
  /// Se usa cuando el archivo real en disco difiere del guardado
  /// (p.ej. tras renombrar .flac → .dec.flac por el decrypt).
  Future<void> actualizarRutaArchivo(String id, String nuevaRuta) =>
      _dao.updateFilePath(id, nuevaRuta);

  /// Backfill de carátula de una entrada del historial (tracks viejos
  /// descargados sin cover: les faltaba cover_url al momento de descargar).
  Future<void> actualizarCaratulaTrack(
    String id,
    String coverUrl,
    String coverPath,
  ) => _dao.updateTrackCover(id, coverUrl, coverPath);
}