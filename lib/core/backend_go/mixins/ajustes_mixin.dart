// ─────────────────────────────────────────────────────────────
// ajustes_mixin.dart — Mixin de ajustes del backend Go: estadísticas
// y limpieza del caché de streaming, y fijar su tamaño máximo.
// Se conecta con: backend_go (RPC getStreamCacheStats, clearStreamCache,
// setStreamCacheMaxMb) — aún necesitan el servidor HTTP de Go.
// Parte del flujo: Ajustes → Caché de streaming.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../contrato_backend.dart';

/// Métodos de caché de streaming (viven en Go: servidor HTTP de streaming).
mixin AjustesMixin on BackendService {
  @override
  Future<Map<String, dynamic>> getStreamCacheStats() async {
    final raw = await rpcCall('getStreamCacheStats');
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> clearStreamCache() async {
    final raw = await rpcCall('clearStreamCache');
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{'ok': false};
  }

  @override
  Future<Map<String, dynamic>> setStreamCacheMaxMb(int mb) async {
    final raw = await rpcCall('setStreamCacheMaxMb', {'mb': mb});
    if (raw is String && raw.isNotEmpty) {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return parsed;
    }
    return <String, dynamic>{'ok': false};
  }
}