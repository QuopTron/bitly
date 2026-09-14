// ─────────────────────────────────────────────────────────────
// pagina_busqueda_flujo.dart — PART de pagina_busqueda.dart:
// flujo de búsqueda de la página — carga y guarda la fuente
// persistida, el despacho de búsquedas (con la pausa de escritura
// de _pausaEscritura),
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
  final guardada =
      await sl<CacheAjustes>().getAjuste(_PaginaBusquedaState._prefKey);
  if (!st.mounted) return;
  final fuentes = _fuentesBusqueda(bloc.state);
  // Solo se restaura una fuente que SIGA siendo buscable. Una instalación
  // vieja pudo guardar "Todas" (id vacío) o un proveedor de respaldo que ya no
  // se ofrece: restaurarlo dejaría la búsqueda apuntando a una fuente fantasma
  // y el usuario vería resultados de Internet Archive sin haberla elegido.
  final valida = (guardada != null && fuentes.containsKey(guardada))
      ? guardada
      : null;
  final elegida =
      valida ?? (fuentes.isNotEmpty ? fuentes.keys.first : '');
  st._aplicar(() => st._fuente = elegida);
  bloc.add(FuenteBusquedaCambiada(elegida));
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
/// QUÉ SE ARREGLA ACÁ. Con 150ms cada tecla de una escritura pausada disparaba
/// una búsqueda completa: quien escribe despacio (o piensa a mitad del título)
/// veía resultados de medio título, y la ventana de red del backend se gastaba
/// en consultas que quedaban obsoletas al siguiente carácter. Ahora se espera a
/// que el usuario REALMENTE termine: [_pausaEscritura] se reinicia con cada
/// cambio, así que mientras siga tecleando no hay ninguna consulta en vuelo, y
/// el reloj empieza a contar en la última tecla. Con el teclado móvil se evita
/// además consultar a mitad de una composición IME (acentos, emoji, japonés),
/// donde el texto del controlador todavía está incompleto.
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
  // Composición IME en curso: el texto todavía no es lo que el usuario quiso
  // escribir. Se espera al próximo cambio (que llega cuando cierra el IME).
  final valorControlador = st._controlador.value;
  if (valorControlador.composing.isValid && !valorControlador.composing.isCollapsed) {
    return;
  }
  st._aplicar(() => st._buscando = true);
  if (ServicioEnlaces.enlaceEnTexto(q) != null) {
    // Misma pausa que una búsqueda: al pegar el texto se completa de golpe,
    // pero al escribir el enlace a mano evita resolver cada tecla.
    st._debounce = Timer(_pausaEscritura, () {
      if (!st.mounted) return;
      _resolverEnlace(st, q);
    });
    return;
  }
  st._debounce = Timer(_pausaEscritura, () {
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
///
/// Consulta YA (sin la pausa de escritura): el usuario no está tecleando, tocó
/// un resultado del historial — hacerlo esperar 650ms para volver a escribir lo
/// mismo se sentiría roto.
void _repetirBusqueda(_PaginaBusquedaState st, String q) {
  st._debounce?.cancel();
  st._controlador.text = q;
  st._aplicar(() => st._buscando = true);
  _despacharBusqueda(st, q);
}