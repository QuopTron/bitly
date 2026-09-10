// ─────────────────────────────────────────────────────────────
// busqueda_intento.dart — PART de busqueda_bloc.dart: ejecución de
// UN intento de búsqueda en streaming (init + poll hasta terminar
// o expirar la ventana). Incluye el reintento silencioso del primer
// resultado vacío (congestión del puente nativo / sesión fría de la
// fuente), la emisión de resultados apenas llega el primer lote y
// el fallback a búsqueda no-streaming cuando el backend no soporta.
// Se conecta con: busqueda_bloc.dart (misma library) + backend_go.
// Parte del flujo: búsqueda (EjecutarBusqueda → resultados).
// ─────────────────────────────────────────────────────────────

part of 'busqueda_bloc.dart';

/// Corre un intento de búsqueda en streaming (init + poll hasta terminar).
/// [permitirReintento] true para el intento del usuario: si la ventana de
/// poll expira SIN resultados y el backend nunca dijo "done", se re-corre una
/// vez — el primer intento a menudo compite con la congestión RPC de arranque
/// del puente nativo (feed, pre-warm de streams, verificación de sesión se
/// serializan en un solo thread) y un "sin resultados" ahí es un falso
/// negativo que hace ver muerta la PRIMERA búsqueda de la sesión, mientras la
/// segunda funciona.
Future<void> _intentarBusqueda(
  BlocBusqueda bloc,
  EjecutarBusqueda event,
  Emitter<EstadoBusqueda> emit, {
  required bool permitirReintento,
}) async {
  try {
    final inicioIntento = DateTime.now();
    var gen = await bloc._backend.searchStreaming(
      query: event.query,
      source: event.fuente,
      type: event.tipo,
      limit: event.limite,
    );
    bloc._generacionStream = gen;

    // Si el init del streaming falló, reintentar una vez tras un breve delay
    // (el puente nativo puede haber estado ocupado con un RPC previo).
    if (gen == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (bloc.isClosed) return;
      gen = await bloc._backend.searchStreaming(
        query: event.query,
        source: event.fuente,
        type: event.tipo,
        limit: event.limite,
      );
      bloc._generacionStream = gen;
    }

    if (gen == 0) {
      // Streaming realmente no disponible — cae a búsqueda no-streaming.
      await _terminarBusqueda(
          bloc, event.query, event.fuente, event.tipo, event.limite, emit);
      return;
    }

    var ultimoEmitido = 0;
    var ultimosItems = <ItemFeed>[];
    const maxPolls = 160; // ~16s por intento; el reintento cubre el resto.
    var backendTermino = false;
    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (bloc.isClosed) return;

      try {
        final poll = await bloc._backend.getSearchStreamResults();
        if (poll.generation != bloc._generacionStream) return;

        if (poll.items.length > ultimoEmitido) {
          ultimoEmitido = poll.items.length;
          ultimosItems = poll.items;
          // Oculta el spinner apenas llega el PRIMER lote de resultados — no
          // espera a que todos los proveedores terminen. Hace la búsqueda
          // sentir instantánea mientras el resto sigue llegando en background.
          emit(bloc.state.copiarCon(
            resultados: poll.items,
            cargando: false,
            haBuscado: true,
          ));
        }

        if (poll.done) {
          backendTermino = true;
          final elapsedMs =
              DateTime.now().difference(inicioIntento).inMilliseconds;
          final fuenteUnica = event.fuente.isNotEmpty && event.fuente != 'all';
          // Respuesta vacía rápida en el primer intento = falso negativo por
          // sesión fría (ver doc de [_intentarBusqueda]). Re-corre una vez
          // tras un beat para que el warm-up de la fuente aterrice antes.
          if (poll.items.isEmpty &&
              permitirReintento &&
              fuenteUnica &&
              elapsedMs < 3500 &&
              !bloc.isClosed) {
            _log.i('[busqueda] Primer resultado vacío rápido para '
                '${event.fuente} (${elapsedMs}ms) — reintentando');
            await Future<void>.delayed(const Duration(milliseconds: 350));
            if (bloc.isClosed) return;
            await _intentarBusqueda(bloc, event, emit, permitirReintento: false);
            return;
          }
          await _cachearYFinalizar(
              bloc,
              event.query,
              event.fuente,
              event.tipo,
              event.limite,
              poll.items,
              emit);
          return;
        }
      } catch (_) {
        break;
      }
    }

    if (!backendTermino && ultimosItems.isEmpty && permitirReintento && !bloc.isClosed) {
      // Ventana expirada con NADA y el backend nunca dijo done: el primer
      // intento compitió por congestión (o el backend solo necesitaba
      // calentar). Reintenta desde cero — para entonces la cola del puente ya
      // drenó y este intento termina a velocidad normal.
      _log.i('[busqueda] Ventana expirada sin resultados para '
          '${event.fuente} — reintentando');
      await _intentarBusqueda(bloc, event, emit, permitirReintento: false);
      return;
    }

    // La ventana de poll terminó antes de que el backend reportara done
    // (proveedor lento). Muestra lo que llegó. Un timeout NO es un "sin
    // resultados" real: no cachear el parcial como final (haría que el
    // próximo intento devuelva al instante con nada).
    emit(bloc.state.copiarCon(
      resultados: ultimosItems,
      cargando: false,
      haBuscado: true,
    ));
  } catch (e) {
    emit(bloc.state.copiarCon(
      cargando: false,
      error: e.toString(),
    ));
  }
}