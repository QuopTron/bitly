// ─────────────────────────────────────────────────────────────
// busqueda_estado.dart — Estado del bloc de búsqueda: query,
// fuente activa, tipo de filtro (tracks/albums/artists/playlists),
// resultados acumulados, loading, el CÓDIGO de error (no su texto),
// si ya se buscó, las
// búsquedas recientes y la config de búsqueda por fuente (burbujas
// de categoría del manifest de cada extensión).
// Se conecta con: modelos (ItemFeed, ConfigBusquedaFuente).
// Parte del flujo: búsqueda (estado del BlocBusqueda).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

import '../../../../core/modelos/proveedores/base/config_busqueda_fuente.dart';
import '../../../../core/modelos/feed/item_feed.dart';

/// Qué salió mal en la última búsqueda.
///
/// El estado guarda el CÓDIGO, nunca el texto: la UI lo traduce con l10n, así
/// el mensaje sigue el idioma activo en vez de quedar congelado en el idioma
/// en que se buscó.
enum ErrorBusqueda {
  /// La fuente pide verificación (Cloudflare/sesión firmada) antes de buscar.
  verificacion,

  /// La búsqueda se cayó (timeout, puente/red): no hay nada que el usuario
  /// pueda corregir, solo reintentar.
  fallo,
}

/// Estado del bloc de búsqueda.
class EstadoBusqueda extends Equatable {
  final String query;
  final String fuente;
  final String tipo;
  final List<ItemFeed> resultados;
  final bool cargando;

  /// Código del error de la última búsqueda (null = sin error).
  final ErrorBusqueda? error;

  /// Fuente sobre la que falló la búsqueda: se guarda aparte porque el usuario
  /// puede cambiar de pestaña antes de que se pinte el error.
  final String fuenteError;
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
    this.fuenteError = '',
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
    ErrorBusqueda? error,
    String? fuenteError,
    bool? haBuscado,
    List<String>? busquedasRecientes,
    Map<String, ConfigBusquedaFuente>? configBusqueda,
  }) => EstadoBusqueda(
    query: query ?? this.query,
    fuente: fuente ?? this.fuente,
    tipo: tipo ?? this.tipo,
    resultados: resultados ?? this.resultados,
    cargando: cargando ?? this.cargando,
    error: error,
    fuenteError: fuenteError ?? this.fuenteError,
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
    fuenteError,
    haBuscado,
    busquedasRecientes,
    configBusqueda,
  ];
}
