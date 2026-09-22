// ─────────────────────────────────────────────────────────────
// feed_busqueda_mixin.dart — Mixin de feed del home + búsqueda
// (normal y en streaming) contra el backend Go.
// Se conecta con: backend_go (RPC getHomeFeed, search, searchStream,
// getSearchStreamResults, getSearchConfig, getSources).
// Parte del flujo: Inicio (feed) y Búsqueda.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../../modelos/proveedores/base/config_busqueda_fuente.dart';
import '../../../modelos/feed/item_feed.dart';
import '../../../modelos/feed/seccion_feed.dart';
import '../../nucleo/base/ayudantes_backend.dart';
import '../../nucleo/base/contrato_backend.dart';
import '../../nucleo/datos/resultados_busqueda_stream.dart';

import 'package:flutter/foundation.dart';
/// Feed del home + búsqueda (RPCs de Go).
mixin FeedBusquedaMixin on BackendService {
  @override
  Future<List<SeccionFeed>> getHomeFeed({String locale = 'en'}) async {
    try {
      return AyudantesBackend.parsearSeccionesFeed(
        await rpcCall('getHomeFeed', {'locale': locale}),
      );
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
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
        if (decodificado is List) {
          return decodificado.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
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
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
      // Un solo intento, a propósito. Antes se re-lanzaba la búsqueda COMBINADA
      // entera 2s después, porque se creía que el puente nativo serializaba los
      // RPCs en un hilo y que la búsqueda podía exceder el timeout del RPC. Ya
      // no es así: MainActivity corre las llamadas de Go en un POOL de threads
      // (uno colgado no bloquea al resto) y el timeout real es de 45s en el
      // puente / 60s en Dart, así que una excepción acá es un fallo de verdad y
      // repetir la misma consulta 2s más tarde falla igual: solo duplicaba el
      // trabajo de todos los proveedores y retrasaba el error.
      return [];
    }
  }

  Future<List<ItemFeed>> _ejecutarBusqueda(
    String query,
    String source,
    String type,
    int limit,
  ) async {
    final params = <String, dynamic>{'query': query, 'limit': limit};
    if (source.isNotEmpty) params['source'] = source;
    if (type.isNotEmpty) params['type'] = type;
    return AyudantesBackend.parsearResultadosBusqueda(
      await rpcCall('search', params),
    );
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
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
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
        // Estado por fuente: con la lista vacía esto decide entre "no hay nada"
        // (todas respondieron) y "no se pudo preguntar" (ninguna respondió).
        final fallidas = (raw['fallidas'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final fuentesOk = (raw['fuentes_ok'] as num?)?.toInt() ?? 0;
        return ResultadosBusquedaStream(
          items: items,
          done: done,
          generation: gen,
          fallidas: fallidas,
          fuentesOk: fuentesOk,
        );
      }
      // Respuesta ilegible: se marca como fallo (no como "terminó sin
      // resultados") — así el sondeo la reintenta en vez de dar la búsqueda
      // por vacía.
      return const ResultadosBusquedaStream(
        items: [],
        done: false,
        generation: 0,
        fallo: true,
      );
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
      return const ResultadosBusquedaStream(
        items: [],
        done: false,
        generation: 0,
        fallo: true,
      );
    }
  }

  @override
  Future<List<ConfigBusquedaFuente>> getSearchConfig() async {
    try {
      final resultado = await rpcCall('getSearchConfig');
      final raw = resultado is String ? jsonDecode(resultado) : resultado;
      if (raw is List) {
        return raw
            .map(
              (e) => ConfigBusquedaFuente.desdeJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[FeedBusquedaMixin] $e');
      return [];
    }
  }
}
