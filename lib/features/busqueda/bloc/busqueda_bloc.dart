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

import '../../../core/backend_go/contrato_backend.dart';
import '../../../core/cache/cache_busqueda.dart';
import '../../../core/modelos/item_feed.dart';
import '../../../core/servicios/servicio_verificacion.dart';
import '../../../shared/constantes/constantes_fuente.dart';
import 'busqueda_estado.dart';
import 'busqueda_evento.dart';

part 'busqueda_cache.dart';
part 'busqueda_intento.dart';
part 'busqueda_verificacion.dart';

final _log = Logger();

/// Fuentes cuyas BÚSQUEDAS requieren sesión firmada (el registry de
/// ServicioVerificacion es la fuente de verdad): qobuz-web da 403 y amazon
/// devuelve 0 sin verificar; tidal-web también pide sesión. Deezer/pandora
/// buscan anónimo — vacío ahí es rate-limit o "sin resultados", nunca un
/// problema de sesión.
final _fuentesVerificarAlVacio = <String>{
  ...ServicioVerificacion.fuentesSesionFirmada,
}..removeAll(const {'deezer', 'pandora'});

/// Resultado de intentar verificar una fuente con sesión firmada.
enum _ResultadoVerificacion { verificada, noNecesaria, fallida }

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