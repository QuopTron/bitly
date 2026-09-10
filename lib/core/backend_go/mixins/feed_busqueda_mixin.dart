// ─────────────────────────────────────────────────────────────
// feed_busqueda_mixin.dart — Mixin de feed del home + búsqueda
// (normal y en streaming) contra el backend Go.
// Se conecta con: backend_go (RPC getHomeFeed, search, searchStream,
// getSearchStreamResults, getSearchConfig, getSources).
// Parte del flujo: Inicio (feed) y Búsqueda.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../modelos/config_busqueda_fuente.dart';
import '../../modelos/item_feed.dart';
import '../../modelos/seccion_feed.dart';
import '../ayudantes_backend.dart';
import '../contrato_backend.dart';
import '../resultados_busqueda_stream.dart';

/// Feed del home + búsqueda (RPCs de Go).
mixin FeedBusquedaMixin on BackendService {
  @override
  Future<List<SeccionFeed>> getHomeFeed({String locale = 'en'}) async {
    try {
      return AyudantesBackend.parsearSeccionesFeed(await rpcCall('getHomeFeed', {'locale': locale}));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> getSources() async {
    try {
      final resultado = await rpcCall('getSources');
      if (resultado is List) return resultado.map((e) => e.toString()).toList();
      if (resultado is String && resultado.isNotEmpty) {
        final decodificado = jsonDecode(resultado);
        if (decodificado is List) return decodificado.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<ItemFeed>> search({
    required String query,
    String source = '',
    String type = '',
    int limit = 20,
  }) async {
    try {
      return await _ejecutarBusqueda(query, source, type, limit);
    } catch (_) {
      // El bridge nativo serializa los RPCs en un hilo; una búsqueda lanzada
      // mientras corre una llamada pesada (fallback de descarga / resolución
      // de stream) puede exceder el timeout del RPC. Reintenta una vez — para
      // entonces la cola ya drenó — para que un stall transitorio nunca
      // parezca "sin resultados".
      try {
        await Future<void>.delayed(const Duration(seconds: 2));
        return await _ejecutarBusqueda(query, source, type, limit);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<ItemFeed>> _ejecutarBusqueda(String query, String source, String type, int limit) async {
    final params = <String, dynamic>{'query': query, 'limit': limit};
    if (source.isNotEmpty) params['source'] = source;
    if (type.isNotEmpty) params['type'] = type;
    return AyudantesBackend.parsearResultadosBusqueda(await rpcCall('search', params));
  }

  // ── Búsqueda en streaming ──────────────────────────────

  @override
  Future<int> searchStreaming({
    required String query,
    String source = '',
    String type = '',
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'query': query, 'limit': limit};
    if (source.isNotEmpty) params['source'] = source;
    if (type.isNotEmpty) params['type'] = type;
    try {
      final resultado = await rpcCall('searchStream', params);
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is Map) {
        return (raw['generation'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<ResultadosBusquedaStream> getSearchStreamResults() async {
    try {
      final resultado = await rpcCall('getSearchStreamResults');
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is Map) {
        final items = AyudantesBackend.parsearResultadosBusqueda(raw['items']);
        final done = raw['done'] == true;
        final gen = (raw['generation'] as num?)?.toInt() ?? 0;
        return ResultadosBusquedaStream(items: items, done: done, generation: gen);
      }
      return const ResultadosBusquedaStream(items: [], done: true, generation: 0);
    } catch (_) {
      return const ResultadosBusquedaStream(items: [], done: true, generation: 0);
    }
  }

  @override
  Future<List<ConfigBusquedaFuente>> getSearchConfig() async {
    try {
      final resultado = await rpcCall('getSearchConfig');
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is List) {
        return raw.map((e) => ConfigBusquedaFuente.desdeJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}