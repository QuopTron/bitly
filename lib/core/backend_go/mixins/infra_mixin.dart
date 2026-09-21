// ─────────────────────────────────────────────────────────────
// infra_mixin.dart — Mixin de infraestructura: caché de carátulas
// (guardar/borrar/buscar local) y reset total de datos.
// Se conecta con: backend_go (saveCover, deleteCover,
// getCoverPathForTrack, resetDatabase).
// Parte del flujo: carátulas locales y reset de fábrica.
// ─────────────────────────────────────────────────────────────

import "package:flutter/foundation.dart";
import '../nucleo/contrato_backend.dart';

/// Claves con las que se indexa una carátula local.
///
/// Una portada se nombra por el hash de su URL (así la misma tapa de 20
/// canciones es un solo archivo), pero cada camino pregunta por datos
/// distintos: el like tiene el id de la fuente y la descarga el ISRC o el
/// nombre. Pasar estas claves al guardar permite que CUALQUIER camino
/// recupere la misma carátula desde disco, sin volver a bajarla.
List<String> clavesCaratula({
  String? isrc,
  String? trackId,
  String? nombre,
  String? artista,
}) {
  final claves = <String>[];
  void agregar(String? valor) {
    final v = valor?.trim() ?? '';
    if (v.isNotEmpty && !claves.contains(v)) claves.add(v);
  }

  agregar(isrc);
  agregar(trackId);
  final n = nombre?.trim() ?? '';
  if (n.isNotEmpty) agregar('$n|${artista?.trim() ?? ''}');
  return claves;
}

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
          })
          as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> saveCover(
    String coverUrl, {
    List<String> keys = const [],
  }) async {
    try {
      return await rpcCall('saveCover', {'url': coverUrl, 'keys': keys})
          as String?;
    } catch (e) {
      // Antes era un catch vacío: la carátula desaparecía sin dejar rastro.
      debugPrint('[Backend] saveCover falló: $e');
      return null;
    }
  }

  @override
  Future<void> deleteCover(String coverUrl) async {
    try {
      await rpcCall('deleteCover', {'url': coverUrl});
    } catch (e) {
      debugPrint("[Backend] $e");
    }
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
