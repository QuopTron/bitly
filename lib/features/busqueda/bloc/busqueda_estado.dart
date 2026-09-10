// ─────────────────────────────────────────────────────────────
// busqueda_estado.dart — Estado del bloc de búsqueda: query,
// fuente activa, tipo de filtro (tracks/albums/artists/playlists),
// resultados acumulados, loading, error, si ya se buscó, las
// búsquedas recientes y la config de búsqueda por fuente (burbujas
// de categoría del manifest de cada extensión).
// Se conecta con: modelos (ItemFeed, ConfigBusquedaFuente).
// Parte del flujo: búsqueda (estado del BlocBusqueda).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../../../core/modelos/config_busqueda_fuente.dart';
import '../../../core/modelos/item_feed.dart';

/// Estado del bloc de búsqueda.
class EstadoBusqueda extends Equatable {
  final String query;
  final String fuente;
  final String tipo;
  final List<ItemFeed> resultados;
  final bool cargando;
  final String? error;
  final bool haBuscado;
  final List<String> busquedasRecientes;

  /// Burbujas de categoría por fuente, del manifest de cada extensión.
  final Map<String, ConfigBusquedaFuente> configBusqueda;

  const EstadoBusqueda({
    this.query = '',
    this.fuente = '',
    this.tipo = 'tracks',
    this.resultados = const [],
    this.cargando = false,
    this.error,
    this.haBuscado = false,
    this.busquedasRecientes = const [],
    this.configBusqueda = const {},
  });

  EstadoBusqueda copiarCon({
    String? query,
    String? fuente,
    String? tipo,
    List<ItemFeed>? resultados,
    bool? cargando,
    String? error,
    bool? haBuscado,
    List<String>? busquedasRecientes,
    Map<String, ConfigBusquedaFuente>? configBusqueda,
  }) =>
      EstadoBusqueda(
        query: query ?? this.query,
        fuente: fuente ?? this.fuente,
        tipo: tipo ?? this.tipo,
        resultados: resultados ?? this.resultados,
        cargando: cargando ?? this.cargando,
        error: error,
        haBuscado: haBuscado ?? this.haBuscado,
        busquedasRecientes: busquedasRecientes ?? this.busquedasRecientes,
        configBusqueda: configBusqueda ?? this.configBusqueda,
      );

  @override
  List<Object?> get props => [
        query,
        fuente,
        tipo,
        resultados,
        cargando,
        error,
        haBuscado,
        busquedasRecientes,
        configBusqueda,
      ];
}