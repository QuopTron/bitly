// ─────────────────────────────────────────────────────────────
// busqueda_cache.dart — PART de busqueda_bloc.dart: entrada del
// cache de resultados en memoria (resultados + momento de guardado)
// y helpers de clave de cache. Los resultados vacíos se cachean con
// TTL corto para no "congelar" un falso negativo durante minutos.
// Se conecta con: busqueda_bloc.dart (misma library) + ItemFeed.
// Parte del flujo: búsqueda (cache en memoria del BlocBusqueda).
// ─────────────────────────────────────────────────────────────

part of 'busqueda_bloc.dart';

/// Entrada del cache de resultados: resultados + momento de guardado.
class _BusquedaCacheada {
  final List<ItemFeed> resultados;
  final DateTime en;

  const _BusquedaCacheada(this.resultados, this.en);
}

/// Clave canónica del cache: query + fuente + tipo + límite.
String _claveCache(String query, String fuente, String tipo, int limite) =>
    '$query\u0001$fuente\u0001$tipo\u0001$limite';

/// Inserta o reemplaza una búsqueda reciente (máximo 10, sin duplicados).
List<String> _agregarReciente(List<String> recientes, String query) {
  final lista = List<String>.from(recientes);
  lista.remove(query);
  lista.insert(0, query);
  if (lista.length > 10) lista.removeLast();
  return lista;
}

/// Expulsa la entrada más vieja cuando el cache llega al tope (LRU).
void _expulsarVieja(Map<String, _BusquedaCacheada> cache) {
  String? claveVieja;
  DateTime? enViejo;
  cache.forEach((k, v) {
    if (enViejo == null || v.en.isBefore(enViejo!)) {
      claveVieja = k;
      enViejo = v.en;
    }
  });
  if (claveVieja != null) cache.remove(claveVieja);
}