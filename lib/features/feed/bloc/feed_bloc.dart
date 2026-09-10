// ─────────────────────────────────────────────────────────────
// feed_bloc.dart — Bloc del feed de inicio: registra los eventos
// (cargar, descargar ítem, cambiar fuente) y delega la carga con
// restauración de cache + refresh a feed_cache.dart. La fuente
// válida se calcula a partir de las secciones que devuelve Go.
// Se conecta con: backend Go (getHomeFeed) + CacheFeed +
// CacheAjustes (username del setup).
// Parte del flujo: feed de inicio (bloc de la vista).
// ─────────────────────────────────────────────────────────────

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart';
import '../../../core/backend_go/contrato_backend.dart';
import '../../../core/cache/cache_ajustes.dart';
import '../../../core/cache/cache_feed.dart';
import '../../../core/modelos/seccion_feed.dart';
import 'feed_estado.dart';
import 'feed_evento.dart';

part 'feed_cache.dart';

/// Bloc del feed: carga con cache offline + refresh en background.
class BlocFeed extends Bloc<EventoFeed, EstadoFeed> {
  final BackendService _backend;

  BlocFeed(this._backend) : super(const EstadoFeed()) {
    on<CargarFeed>((event, emit) => _cargarFeed(this, event, emit));
    on<DescargarItem>(_descargarItem);
    on<FuenteFeedCambiada>(
      (event, emit) => emit(state.copiarCon(fuenteSeleccionada: event.fuente)),
    );
  }

  /// Calcula la mejor fuente válida según las secciones obtenidas.
  String _fuenteValida(List<SeccionFeed> secciones, String preferida) {
    final disponibles = <String>{};
    for (final s in secciones) {
      if (s.source.isNotEmpty) disponibles.add(s.source);
    }
    return disponibles.contains(preferida)
        ? preferida
        : (disponibles.isNotEmpty ? disponibles.first : '');
  }

  Future<void> _descargarItem(
      DescargarItem event, Emitter<EstadoFeed> emit) async {
    try {
      await _backend.downloadItem(event.itemId);
    } catch (_) {
      // Silencioso: downloadItem guarda el ítem para procesarlo después.
    }
  }
}