// ─────────────────────────────────────────────────────────────
// acciones_mixin.dart — Mixin de acciones core contra Go: likes,
// despacho de descargas, progreso, estimación de tamaño y sync de
// config (las sesiones firmadas viven en sesiones_firmadas_mixin).
// Se conecta con: backend_go (RPC likeItem, downloadByStrategy,
// setBackendConfig, getAllDownloadProgress...).
// Parte del flujo: likes, descargas, ajustes.
// ─────────────────────────────────────────────────────────────

import '../contrato_backend.dart';

/// Acciones core: like, descarga, progreso, tamaño estimado y config van a Go.
mixin AccionesMixin on BackendService {
  @override
  Future<void> likeItem(String itemId, bool liked) async {
    try {
      await rpcCall('likeItem', {'item_id': itemId, 'liked': liked});
    } catch (_) {}
  }

  @override
  Future<void> downloadItem(String itemId) async {
    try {
      await rpcCall('downloadItem', {'item_id': itemId});
    } catch (_) {}
  }

  // ── Progreso de descarga y estrategia (Go) ──────────────

  @override
  Future<String> getAllDownloadProgress() async {
    try {
      return await rpcCall('getAllDownloadProgress') as String;
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> cancelDownload(String itemId) async {
    try {
      await rpcCall('cancelDownload', {'item_id': itemId});
    } catch (_) {}
  }

  @override
  Future<dynamic> downloadByStrategy(String json) async {
    try {
      return await rpcCall('downloadByStrategy', {'request': json});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> initItemProgress(String itemId, {String trackName = '', String artistName = ''}) async {
    try {
      await rpcCall('initItemProgress', {
        'item_id': itemId,
        'track_name': trackName,
        'artist_name': artistName,
      });
    } catch (_) {}
  }

  @override
  Future<String> estimateTrackFileSize(int durationMs, String quality) async {
    try {
      return await rpcCall('estimateTrackFileSize', {
        'duration_ms': durationMs,
        'quality': quality,
      }) as String;
    } catch (_) {
      return '{}';
    }
  }

  // ── Sync de config ──────────────────────────────────────

  @override
  Future<void> syncDownloadDir(String path) async {
    try {
      await rpcCall('setDownloadDirectory', {'path': path});
    } catch (_) {}
  }

  @override
  Future<void> syncBackendConfig({
    String? mode,
    int? streamCacheMaxMb,
    int? downloadConcurrency,
    int? streamChunkSize,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (mode != null) params['mode'] = mode;
      if (streamCacheMaxMb != null) params['stream_cache_max_mb'] = streamCacheMaxMb;
      if (downloadConcurrency != null) params['download_concurrency'] = downloadConcurrency;
      if (streamChunkSize != null) params['stream_chunk_size'] = streamChunkSize;
      if (params.isNotEmpty) await rpcCall('setBackendConfig', params);
    } catch (_) {}
  }

  @override
  Future<void> syncDownloadProviderPriority(List<String> providers) async {
    try {
      await rpcCall('setDownloadProviderPriority', {'providers': providers});
    } catch (_) {}
  }

}