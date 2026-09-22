// ─────────────────────────────────────────────────────────────
// busqueda_intento.dart — PART de busqueda_bloc.dart: ejecución de
// UN intento de búsqueda en streaming (init + poll hasta que el
// backend reporta `done`), con la emisión de resultados apenas
// llega el primer lote, la tolerancia a polls caídos y el fallback
// a búsqueda no-streaming cuando el streaming no está disponible.
// Se conecta con: busqueda_bloc.dart (misma library) + backend_go.
// Parte del flujo: búsqueda (EjecutarBusqueda → resultados).
// ─────────────────────────────────────────────────────────────

part of '../base/busqueda_bloc.dart';

/// Corre un intento de búsqueda en streaming (init + poll hasta `done`).
///
/// NO re-lanza la búsqueda. Antes había tres reintentos que competían con la
/// congestión del puente nativo (primera búsqueda de la sesión, proveedor
/// colgado), y dos de ellos re-ejecutaban TODOS los proveedores: con eso una
/// query se hacía dos veces y el usuario veía el doble de espera. El backend ya
/// acota cada proveedor por tiempo y cierra siempre la sesión con `done`, así
/// que la ventana de poll no se queda a medias por un proveedor lento.
/// Lo único que se reintenta es un poll que se cayó (el RPC, no la búsqueda).
Future<void> _intentarBusqueda(
  BlocBusqueda bloc,
  EjecutarBusqueda event,
  Emitter<EstadoBusqueda> emit,
) async {
  try {
    var gen = await bloc._backend.searchStreaming(
      query: event.query,
      source: event.fuente,
      type: event.tipo,
      limit: event.limite,
    );

    // gen == 0 significa que el backend NO arrancó la búsqueda (registry sin
    // inicializar o payload inválido): no hay nada corriendo, así que reintentar
    // el init no duplica trabajo de proveedores. Cubre la carrera de "init
    // todavía en vuelo" al abrir la búsqueda por primera vez.
    if (gen == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (bloc.isClosed) return;
      gen = await bloc._backend.searchStreaming(
        query: event.query,
        source: event.fuente,
        type: event.tipo,
        limit: event.limite,
      );
    }
    bloc._generacionStream = gen;

    if (gen == 0) {
      // Streaming realmente no disponible — cae a búsqueda no-streaming.
      await _terminarBusqueda(
        bloc,
        event.query,
        event.fuente,
        event.tipo,
        event.limite,
        emit,
      );
      return;
    }

    var ultimoEmitido = 0;
    var ultimosItems = <ItemFeed>[];
    // Tope de sondeo (~13s): holgura amplia sobre el techo del backend (4s).
    // Es un TOPE, no un reintento: al vencer se muestra lo parcial que llegó.
    const maxPolls = 160;
    var fallosPoll = 0;

    for (var i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (bloc.isClosed) return;

      final poll = await bloc._backend.getSearchStreamResults();

      // Un poll caído (RPC del puente) NO es el fin de la búsqueda: la sesión
      // sigue corriendo en Go. Se tolera una racha corta y se sigue sondeando.
      if (poll.fallo) {
        if (++fallosPoll >= 5) {
          _log.w(
            '[busqueda] poll caído ${fallosPoll}x para '
            '${event.fuente} — se muestra lo recibido',
          );
          break;
        }
        continue;
      }
      fallosPoll = 0;

      if (poll.generation == bloc._generacionStream) {
        if (poll.items.length > ultimoEmitido) {
          ultimoEmitido = poll.items.length;
          ultimosItems = poll.items;
          // Oculta el spinner apenas llega el PRIMER lote de resultados — no
          // espera a que todos los proveedores terminen. Hace la búsqueda
          // sentir instantánea mientras el resto sigue llegando en background.
          emit(
            bloc.state.copiarCon(
              resultados: poll.items,
              cargando: false,
              haBuscado: true,
            ),
          );
        }

        if (poll.done) {
          // Vacío porque NINGUNA fuente pudo responder (error de sesión, fuente
          // desconocida, cooldown o techo de tiempo): eso NO es "sin
          // resultados". Se emite el código de error —la UI ya tiene su panel
          // con reintento— y no se cachea como vacío, para que el próximo
          // intento vuelva a preguntar de verdad.
          if (poll.vacioPorFallo) {
            _log.w(
              '[busqueda] ninguna fuente respondió para "${event.query}" '
              '(${poll.fallidas.join(', ')})',
            );
            emit(
              bloc.state.copiarCon(
                resultados: const [],
                cargando: false,
                haBuscado: true,
                error: ErrorBusqueda.fallo,
                fuenteError: event.fuente.isNotEmpty
                    ? event.fuente
                    : poll.fallidas.first,
              ),
            );
            return;
          }
          await _cachearYFinalizar(
            bloc,
            event.query,
            event.fuente,
            event.tipo,
            event.limite,
            poll.items,
            emit,
          );
          return;
        }
        continue;
      }

      // Generación MÁS NUEVA: este intento fue reemplazado (el usuario ya
      // escribió otra cosa) y esos resultados le pertenecen a la búsqueda
      // nueva. Se abandona sin tocar la UI.
      if (poll.generation > bloc._generacionStream) return;

      // Generación MÁS VIEJA (0 = el backend perdió la sesión, p. ej. reinicio
      // del proceso): no va a haber más resultados. Se sale a mostrar lo que
      // llegó en vez de dejar el spinner esperando al watchdog.
      _log.w(
        '[busqueda] sesión de streaming inválida (gen ${poll.generation} '
        '< ${bloc._generacionStream}) — se muestra lo recibido',
      );
      break;
    }

    // Tope agotado, racha de fallos o sesión perdida: muestra lo parcial. Un
    // timeout NO es un "sin resultados" real, así que no se cachea como final
    // (haría que el próximo intento devuelva al instante con nada).
    emit(
      bloc.state.copiarCon(
        resultados: ultimosItems,
        cargando: false,
        haBuscado: true,
      ),
    );
  } catch (e) {
    debugPrint('[busqueda_intento] $e');
    emit(
      bloc.state.copiarCon(
        cargando: false,
        error: ErrorBusqueda.fallo,
        fuenteError: event.fuente,
      ),
    );
  }
}
