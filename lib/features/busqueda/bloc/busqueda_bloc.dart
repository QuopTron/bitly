// ─────────────────────────────────────────────────────────────
// busqueda_bloc.dart — Bloc de búsqueda: registra los eventos
// (query/fuente/tipo/recientes/config) y delega el streaming a
// busqueda_intento.dart y la finalización/verificación a
// busqueda_verificacion.dart. El cache en memoria y helpers viven
// en busqueda_cache.dart. Al construirse carga las recientes y la
// config de búsqueda por fuente desde Go.
// Se conecta con: backend_go + CacheBusqueda + ServicioVerificacion
// + constantes_fuente + modelos (ItemFeed, ConfigBusquedaFuente).
// Parte del flujo: búsqueda (bloc de la vista de búsqueda).
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../core/cache/almacenes/cache_busqueda.dart';
import '../../../core/modelos/feed/item_feed.dart';
import '../../../core/servicios/verificacion/servicio_verificacion.dart';
import '../../../shared/constantes/constantes_fuente.dart';
import 'busqueda_estado.dart';
import 'busqueda_evento.dart';

part 'busqueda_cache.dart';
part 'busqueda_intento.dart';
part 'busqueda_verificacion.dart';

part 'busqueda_globales.dart';

/// Bloc de búsqueda: streaming + cache + recientes + config por fuente.
class BlocBusqueda extends Bloc<EventoBusqueda, EstadoBusqueda> {
  final BackendService _backend;
  final CacheBusqueda _cacheBusqueda;

  final Map<String, DateTime> _ultimoIntentoVerificacion = {};
  static const _cooldownVerificacion = Duration(minutes: 5);
  final Map<String, _BusquedaCacheada> _cacheResultados = {};
  static const _ttlBusqueda = Duration(minutes: 5);
  static const _ttlVacio = Duration(seconds: 6); // vacíos = corto
  static const _maxEntradasCache = 40;

  int _generacionStream = 0;

  BlocBusqueda(this._backend, this._cacheBusqueda)
      : super(const EstadoBusqueda()) {
    _cargarRecientes();
    _cargarConfigBusqueda();

    on<ConfigBusquedaCargada>((event, emit) {
      emit(state.copiarCon(configBusqueda: event.config));
    });

    on<QueryBusquedaCambiada>((event, emit) {
      emit(state.copiarCon(query: event.query));
    });

    on<FuenteBusquedaCambiada>((event, emit) {
      emit(state.copiarCon(fuente: event.fuente));
    });

    on<TipoBusquedaCambiado>((event, emit) {
      emit(state.copiarCon(tipo: event.tipo));
    });

    on<EjecutarBusqueda>((event, emit) async {
      emit(state.copiarCon(
        cargando: true,
        error: null,
        query: event.query,
        fuente: event.fuente,
      ));

      final clave =
          _claveCache(event.query, event.fuente, event.tipo, event.limite);
      final hit = _cacheResultados[clave];
      if (hit != null) {
        final ttl = hit.resultados.isEmpty ? _ttlVacio : _ttlBusqueda;
        if (DateTime.now().difference(hit.en) < ttl) {
          emit(state.copiarCon(
            resultados: hit.resultados,
            cargando: false,
            haBuscado: true,
            busquedasRecientes:
                _agregarReciente(state.busquedasRecientes, event.query),
          ));
          return;
        }
        _cacheResultados.remove(clave);
      }

      await _intentarBusqueda(this, event, emit, permitirReintento: true);
    });

    on<AgregarBusquedaReciente>((event, emit) {
      final recientes = _agregarReciente(state.busquedasRecientes, event.query);
      unawaited(_cacheBusqueda.guardarBusquedaReciente(event.query));
      emit(state.copiarCon(busquedasRecientes: recientes));
    });

    on<LimpiarBusquedasRecientes>((event, emit) {
      unawaited(_cacheBusqueda.limpiarBusquedasRecientes());
      emit(state.copiarCon(busquedasRecientes: const []));
    });

    on<QuitarBusquedaReciente>((event, emit) {
      final recientes = List<String>.from(state.busquedasRecientes)
        ..remove(event.query);
      unawaited(_cacheBusqueda.quitarBusquedaReciente(event.query));
      emit(state.copiarCon(busquedasRecientes: recientes));
    });

    on<BusquedasRecientesCargadas>((event, emit) {
      emit(state.copiarCon(busquedasRecientes: event.busquedas));
    });

    on<LimpiarBusqueda>((event, emit) {
      emit(state.copiarCon(
        query: '',
        resultados: const [],
        cargando: false,
        error: null,
        haBuscado: false,
      ));
    });

    // Watchdog de la página: corta el spinner cuando un intento se pasó del
    // tope de espera. No borra resultados ya recibidos (parciales sí valen):
    // solo deja de mostrar carga y marca que ya se buscó.
    on<FinalizarBusquedaForzada>((event, emit) {
      if (!state.cargando) return;
      emit(state.copiarCon(cargando: false, haBuscado: true));
    });
  }

  void _cargarRecientes() {
    _cacheBusqueda.getBusquedasRecientes().then((busquedas) {
      if (!isClosed) add(BusquedasRecientesCargadas(busquedas));
    });
  }

  void _cargarConfigBusqueda() {
    _backend.getSearchConfig().then((lista) {
      if (isClosed) return;
      add(ConfigBusquedaCargada({
        for (final c in lista) c.source: c,
      }));
    }).catchError((_) {});
  }
}