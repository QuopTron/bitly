// ─────────────────────────────────────────────────────────────
// pagina_busqueda_helpers.dart — PART de pagina_busqueda.dart:
// helpers puros de la búsqueda — burbujas de categoría del
// manifest, fuentes buscables (primaria primero), hint por fuente,
// validación de categorías, id de filtro activo y límites por
// categoría — más los delegados de acciones de ítem que reenvían
// a AccionesItem (lógica globalizada, sin duplicación).
// Se conecta con: pagina_busqueda.dart (misma library) +
// constantes_fuente + config_busqueda_fuente + acciones_item.
// Parte del flujo: búsqueda (lógica de la página).
// ─────────────────────────────────────────────────────────────

part of 'pagina_busqueda.dart';

/// Burbujas de categoría del manifest de la fuente activa (o default).
List<ConfigFiltroBusqueda> _filtrosPara(EstadoBusqueda state, String fuente) {
  final cfg = state.configBusqueda[fuente];
  if (cfg != null && cfg.filters.isNotEmpty) return cfg.filters;
  return const [
    ConfigFiltroBusqueda(id: 'tracks', label: ''),
    ConfigFiltroBusqueda(id: 'artists', label: ''),
    ConfigFiltroBusqueda(id: 'albums', label: ''),
    ConfigFiltroBusqueda(id: 'playlists', label: ''),
  ];
}

/// Fuentes buscables del backend (la primaria primero), con fallback.
Map<String, String> _fuentesBusqueda(EstadoBusqueda state) {
  final ordenadas = <String, String>{};
  final cfg = state.configBusqueda;
  if (cfg.isNotEmpty) {
    final primarias = cfg.entries.where((e) => e.value.primary).toList();
    final resto = cfg.entries.where((e) => !e.value.primary).toList();
    for (final e in [...primarias, ...resto]) {
      ordenadas[e.key] = nombreFuente(e.key);
    }
    return ordenadas;
  }
  for (final s in const [
    'deezer', 'spotify-web', 'apple-music', 'soundcloud', 'amazon',
    'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
  ]) {
    ordenadas[s] = nombreFuente(s);
  }
  return ordenadas;
}

/// Hint de la barra: placeholder del manifest de la fuente activa.
String? _hintBusqueda(_PaginaBusquedaState st, EstadoBusqueda state) {
  final cfg = state.configBusqueda;
  if (cfg.isEmpty) return null;
  final p = cfg[st._fuente]?.placeholder;
  if (st._fuente.isNotEmpty && p != null && p.isNotEmpty) return p;
  final primarias = cfg.values.where((c) => c.primary).toList();
  if (primarias.isNotEmpty && primarias.first.placeholder.isNotEmpty) {
    return primarias.first.placeholder;
  }
  return null;
}

bool _fuenteTieneCategoria(EstadoBusqueda state, String fuente, String cat) {
  return _filtrosPara(state, fuente).any((f) => categoriaBusquedaDe(f.id) == cat);
}

/// Id del filtro del manifest para la categoría activa (o la categoría).
String? _idFiltroActivo(_PaginaBusquedaState st) {
  if (st._tipo == null) return null;
  final state = st.context.read<BlocBusqueda>().state;
  for (final f in _filtrosPara(state, st._fuente)) {
    if (categoriaBusquedaDe(f.id) == st._tipo) return f.id;
  }
  return st._tipo;
}

int _limiteParaTipo(String cat) => cat == 'tracks' ? 50 : 20;

// ── Acciones de ítem (delegadas a AccionesItem) ─────────────

void _alternarLike(_PaginaBusquedaState st, String id, [ItemFeed? item]) {
  if (item != null) AccionesItem.alternarLike(st.context, item);
}

void _iniciarDescarga(_PaginaBusquedaState st, ItemFeed item) =>
    AccionesItem.iniciarDescarga(st.context, item);

void _iniciarDescargaLote(_PaginaBusquedaState st, ItemFeed item) =>
    AccionesItem.iniciarDescargaLote(st.context, item);

void _borrarTrack(_PaginaBusquedaState st, ItemFeed item) =>
    AccionesItem.borrarTrack(st.context, item);

void _borradoLote(_PaginaBusquedaState st, ItemFeed item) =>
    AccionesItem.borrarLote(st.context, item);

void _exportarPlaylist(_PaginaBusquedaState st, ItemFeed item) =>
    AccionesItem.exportarPlaylist(st.context, item);

void _mostrarInfo(BuildContext context, ItemFeed item) =>
    AccionesItem.mostrarInfo(context, item);

void _mostrarMas(BuildContext context, ItemFeed item) =>
    AccionesItem.mostrarMas(context, item);