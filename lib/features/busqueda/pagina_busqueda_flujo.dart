// ─────────────────────────────────────────────────────────────
// pagina_busqueda_flujo.dart — PART de pagina_busqueda.dart:
// flujo de búsqueda de la página — carga y guarda la fuente
// persistida, el despacho de búsquedas (con el debounce de 150ms),
// y los handlers de cambio de fuente/tipo/texto y limpieza. El
// despacho calcula el id de filtro del manifest y el límite por
// categoría antes de emitir EjecutarBusqueda.
// Se conecta con: pagina_busqueda.dart (misma library) +
// busqueda_bloc + cache_ajustes.
// Parte del flujo: búsqueda (interacción del usuario).
// ─────────────────────────────────────────────────────────────

part of 'pagina_busqueda.dart';

/// Carga la fuente persistida (o la primera disponible) y la activa.
Future<void> _cargarFuentePersistida(_PaginaBusquedaState st) async {
  final bloc = st.context.read<BlocBusqueda>();
  final guardada = await sl<CacheAjustes>().getAjuste(_PaginaBusquedaState._prefKey);
  final fuentes = _fuentesBusqueda(bloc.state);
  if (st.mounted) {
    st._aplicar(() {
      st._fuente = (guardada != null && guardada.isNotEmpty)
          ? guardada
          : (fuentes.isNotEmpty ? fuentes.keys.first : '');
    });
    bloc.add(FuenteBusquedaCambiada(st._fuente));
  }
}

Future<void> _guardarFuentePersistida(_PaginaBusquedaState st, String fuente) async {
  await sl<CacheAjustes>().guardarAjuste(_PaginaBusquedaState._prefKey, fuente);
}

/// Despacha EjecutarBusqueda con el filtro y límite de la categoría activa.
void _despacharBusqueda(_PaginaBusquedaState st, String q) {
  final filterId = _idFiltroActivo(st);
  st.context.read<BlocBusqueda>().add(EjecutarBusqueda(
        query: q,
        fuente: st._fuente,
        tipo: filterId ?? 'tracks',
        limite: filterId == null ? 25 : _limiteParaTipo(st._tipo!),
      ));
}

/// Ejecuta la búsqueda si hay texto en el campo.
void _ejecutarBusqueda(_PaginaBusquedaState st) {
  final q = st._controlador.text.trim();
  if (q.isEmpty) return;
  _despacharBusqueda(st, q);
}

/// Envío explícito (Enter / acción del teclado): un enlace de música se
/// resuelve y se reproduce; cualquier otro texto se busca normalmente.
Future<void> _enviarBusqueda(_PaginaBusquedaState st, String texto) async {
  final q = texto.trim();
  if (q.isEmpty) return;
  st._debounce?.cancel();
  if (ServicioEnlaces.enlaceEnTexto(q) != null) {
    await _resolverEnlace(st, q);
    return;
  }
  _despacharBusqueda(st, q);
}

/// Resuelve un enlace pegado/compartido: Go elige la extensión según su
/// manifest y devuelve el ítem, que se encola y suena de inmediato.
///
/// Nunca busca la URL como texto: buscar "https://open.spotify.com/track/..."
/// devolvía resultados que no tenían nada que ver con la canción del enlace.
/// Si la fuente no puede resolverlo, se avisa al usuario.
Future<void> _resolverEnlace(_PaginaBusquedaState st, String texto) async {
  final enlace = ServicioEnlaces.enlaceEnTexto(texto);
  if (enlace == null) return;
  if (st.mounted) st._aplicar(() => st._buscando = true);
  final resuelto = await ServicioEnlaces.instance.resolver(enlace);
  if (!st.mounted) return;
  st._aplicar(() => st._buscando = false);
  if (resuelto == null) {
    st.context.read<BlocBusqueda>().add(const LimpiarBusqueda());
    _mostrarAviso(st, AppLocalizations.of(st.context).setup.linkResolveFailed);
    return;
  }
  sl<CubitCola>().reproducirConContexto(resuelto.paraReproducir, resuelto.item);
  _limpiarBusqueda(st);
}

/// Aviso breve sin bloquear la vista (el enlace no se pudo resolver).
void _mostrarAviso(_PaginaBusquedaState st, String mensaje) {
  ScaffoldMessenger.maybeOf(st.context)?.showSnackBar(
    SnackBar(content: Text(mensaje), duration: const Duration(seconds: 5)),
  );
}

/// Cambia la fuente, valida la categoría y re-busca.
void _onFuenteCambiada(_PaginaBusquedaState st, String fuente) {
  st._aplicar(() {
    st._fuente = fuente;
    final state = st.context.read<BlocBusqueda>().state;
    if (st._tipo == null ||
        !_fuenteTieneCategoria(state, fuente, st._tipo!)) {
      st._tipo = 'tracks';
    }
  });
  _guardarFuentePersistida(st, fuente);
  st.context.read<BlocBusqueda>().add(FuenteBusquedaCambiada(fuente));
  _ejecutarBusqueda(st);
}

/// Cambia la categoría activa y re-consulta el backend.
void _onTipoCambiado(_PaginaBusquedaState st, String? tipo) {
  st._aplicar(() => st._tipo = tipo);
  _ejecutarBusqueda(st);
}

/// Debounce sobre el texto; vacío limpia la búsqueda.
///
/// Un enlace de música NO se busca como texto: se resuelve (Go elige la
/// extensión) y se reproduce. Antes, pegar un enlace disparaba una búsqueda de
/// la URL completa y aparecían resultados basura que no eran esa canción.
void _onTextoCambiado(_PaginaBusquedaState st, String valor) {
  st._debounce?.cancel();
  final q = valor.trim();
  if (q.isEmpty) {
    st._aplicar(() => st._buscando = false);
    st.context.read<BlocBusqueda>().add(const LimpiarBusqueda());
    return;
  }
  st._aplicar(() => st._buscando = true);
  if (ServicioEnlaces.enlaceEnTexto(q) != null) {
    // Espera un poco más que una búsqueda: al pegar, el texto se completa de
    // golpe, pero al escribir el enlace a mano evita resolver cada tecla.
    st._debounce = Timer(const Duration(milliseconds: 400), () {
      if (!st.mounted) return;
      _resolverEnlace(st, q);
    });
    return;
  }
  st._debounce = Timer(const Duration(milliseconds: 150), () {
    if (!st.mounted) return;
    _despacharBusqueda(st, q);
  });
}

/// Limpia el campo y el estado de búsqueda.
void _limpiarBusqueda(_PaginaBusquedaState st) {
  st._debounce?.cancel();
  st._controlador.clear();
  st.context.read<BlocBusqueda>().add(const LimpiarBusqueda());
}

/// Re-ejecuta una búsqueda reciente tocada en el historial.
void _repetirBusqueda(_PaginaBusquedaState st, String q) {
  st._controlador.text = q;
  _onTextoCambiado(st, q);
}