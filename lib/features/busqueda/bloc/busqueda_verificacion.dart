// ─────────────────────────────────────────────────────────────
// busqueda_verificacion.dart — PART de busqueda_bloc.dart:
// finalización de una búsqueda — búsqueda combinada no-streaming,
// chequeo de sesión firmada (fuente vacía + requiere verificación
// → WebView con cooldown de 5min), cache con TTL (vacío = corto)
// y emisión final con la reciente persistida. Se conecta con la
// misma library + backend_go + ServicioVerificacion + CacheBusqueda.
// Parte del flujo: búsqueda (finalización + verificación).
// ─────────────────────────────────────────────────────────────

part of 'busqueda_bloc.dart';

/// Búsqueda combinada no-streaming contra el backend.
Future<List<ItemFeed>> _buscarTodo(
  BlocBusqueda bloc,
  String query,
  String fuente,
  String tipo,
  int limite,
) async {
  try {
    return await bloc._backend.search(
      query: query,
      source: fuente,
      type: tipo,
      limit: limite,
    );
  } catch (e) {
    _log.w('[busqueda] Búsqueda combinada falló para $fuente: $e');
    return const [];
  }
}

/// ¿La sesión firmada de la fuente está usable? Ante error asume que sí.
Future<bool> _sesionFuenteUsable(BlocBusqueda bloc, String fuente) async {
  try {
    final estado = await bloc._backend.getSignedSessionStatus(fuente);
    return estado.autenticado;
  } catch (_) {
    return true;
  }
}

/// Cachea el resultado (LRU + TTL según vacío) y emite el estado final.
Future<void> _cachearYFinalizar(
  BlocBusqueda bloc,
  String query,
  String fuente,
  String tipo,
  int limite,
  List<ItemFeed> resultados,
  Emitter<EstadoBusqueda> emit,
) async {
  final clave = _claveCache(query, fuente, tipo, limite);

  if (resultados.isEmpty && _fuentesVerificarAlVacio.contains(fuente)) {
    final ultimo = bloc._ultimoIntentoVerificacion[fuente];
    final enCooldown = ultimo != null &&
        DateTime.now().difference(ultimo) < BlocBusqueda._cooldownVerificacion;
    final sesionUsable = await _sesionFuenteUsable(bloc, fuente);
    if (!enCooldown && !sesionUsable) {
      bloc._ultimoIntentoVerificacion[fuente] = DateTime.now();
      _log.i('[busqueda] Fuente $fuente vacía — intentando verificación');
      switch (await _verificarFuente(bloc, fuente)) {
        case _ResultadoVerificacion.verificada:
          _log.i('[busqueda] Verificación OK — reintentando búsqueda');
          resultados = await _buscarTodo(bloc, query, fuente, tipo, limite);
        case _ResultadoVerificacion.fallida:
          emit(bloc.state.copiarCon(
            cargando: false,
            haBuscado: true,
            error: 'Verificación requerida para ${nombreFuente(fuente)}. '
                'Ábrela desde Configuración y reintenta.',
          ));
          return;
        case _ResultadoVerificacion.noNecesaria:
          break;
      }
    }
  }

  if (bloc._cacheResultados.length >= BlocBusqueda._maxEntradasCache) {
    _expulsarVieja(bloc._cacheResultados);
  }
  bloc._cacheResultados[clave] = _BusquedaCacheada(resultados, DateTime.now());

  final recientes = _agregarReciente(bloc.state.busquedasRecientes, query);
  unawaited(bloc._cacheBusqueda.guardarBusquedaReciente(query));
  emit(bloc.state.copiarCon(
    resultados: resultados,
    cargando: false,
    haBuscado: true,
    busquedasRecientes: recientes,
  ));
}

/// Búsqueda de fallback cuando el streaming no está disponible.
Future<void> _terminarBusqueda(
  BlocBusqueda bloc,
  String query,
  String fuente,
  String tipo,
  int limite,
  Emitter<EstadoBusqueda> emit,
) async {
  try {
    final resultados = await _buscarTodo(bloc, query, fuente, tipo, limite);
    await _cachearYFinalizar(
        bloc, query, fuente, tipo, limite, resultados, emit);
  } catch (e) {
    emit(bloc.state.copiarCon(
      cargando: false,
      error: e.toString(),
    ));
  }
}

/// Abre el WebView de verificación de la fuente y completa el grant con Go.
Future<_ResultadoVerificacion> _verificarFuente(
  BlocBusqueda bloc,
  String fuente,
) async {
  try {
    final url = await bloc._backend.getPendingVerificationUrl(fuente);
    if (url.isEmpty) return _ResultadoVerificacion.noNecesaria;

    final servicio = ServicioVerificacion();
    if (!servicio.estaListo) {
      _log.w('[busqueda] ServicioVerificacion no inicializado');
      return _ResultadoVerificacion.fallida;
    }

    // NUNCA abrir el modal solo desde una búsqueda: intento silencioso + aviso
    // con acción "Verificar" si el challenge exige humano.
    final ok = await servicio.verificarFuenteNoIntrusiva(
      fuente,
      nombreFuente(fuente),
      url,
    );
    return ok ? _ResultadoVerificacion.verificada : _ResultadoVerificacion.fallida;
  } catch (e) {
    _log.e('[busqueda] Error de verificación para $fuente: $e');
    return _ResultadoVerificacion.fallida;
  }
}