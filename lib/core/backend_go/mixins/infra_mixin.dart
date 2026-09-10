// ─────────────────────────────────────────────────────────────
// infra_mixin.dart — Mixin de infraestructura: caché de carátulas
// (guardar/borrar/buscar local) y reset total de datos.
// Se conecta con: backend_go (saveCover, deleteCover,
// getCoverPathForTrack, resetDatabase).
// Parte del flujo: carátulas locales y reset de fábrica.
// ─────────────────────────────────────────────────────────────

import '../contrato_backend.dart';

/// RPCs de caché de carátulas y reset de datos.
mixin InfraMixin on BackendService {
  @override
  Future<String?> getCoverPathForTrack({
    required String trackId,
    String? isrc,
    String? trackName,
    String? artistName,
    String? coverUrl,
  }) async {
    try {
      return await rpcCall('getCoverPathForTrack', {
        'track_id': trackId,
        'isrc': isrc ?? '',
        'track_name': trackName ?? '',
        'artist_name': artistName ?? '',
        'cover_url': coverUrl ?? '',
      }) as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> saveCover(String coverUrl) async {
    try {
      return await rpcCall('saveCover', {'url': coverUrl}) as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteCover(String coverUrl) async {
    try {
      await rpcCall('deleteCover', {'url': coverUrl});
    } catch (_) {}
  }

  @override
  Future<bool> resetAllData() async {
    try {
      await rpcCall('resetDatabase');
      return true;
    } catch (_) {
      return false;
    }
  }
}