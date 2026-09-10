// ─────────────────────────────────────────────────────────────
// reproductor_listener_cola.dart — PART de cubit_reproductor.dart:
// listener de la cola (cuando cambia el track actual abre el nuevo,
// ignorando ediciones irrelevantes; cola vacía = parar y restaurar
// volumen) y el cierre del cubit (`close`, hook de disposal del
// framework): cancela listeners, limpia archivos temp, libera el
// notifier de video y descarta el player mpv.
// Se conecta con: reproductor_player_setup.dart (misma library).
// Parte del flujo: reproducción (sync cola ↔ player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Listener de cola y cierre. Mixin aplicado en CubitReproductor.
mixin ReproductorListenerCola on ReproductorPlayerSetup {
  /// Reacción al cambio de perfil de rendimiento — la implementación concreta
  /// vive en ReproductorInit (arriba en la cadena); declaración para close().
  void _onPerfilCambio();

  /// Escucha la cola: cuando cambia el track actual (o se fuerza re-open),
  /// abre el nuevo track. Ignora ediciones de cola irrelevantes.
  void _listenQueue() {
    _subCola = _queueCubit.stream.listen((estadoCola) {
      if (estadoCola.tieneActual && estadoCola.actual != null) {
        if (!_listo) {
          _trackPendiente = estadoCola.actual;
          return;
        }
        final actual = estadoCola.actual!;
        final key = '${actual.id}|${actual.source}';
        // Skip ediciones no relacionadas (addNext/addToEnd/shuffle/repeat/
        // reorder) mientras el mismo track es actual — reabrirlo aquí
        // reinicia la canción y corre con el avance real. Solo reabrir cuando
        // el track actual cambió, el anterior completó (repeat-one re-emite
        // el mismo índice a propósito), o el actual está en error (re-tap de
        // un track fallido debe reintentarlo).
        if (key == _claveTrackAbierto &&
            !_forzarReopen &&
            state.estadoReproduccion != EstadoReproduccion.error) {
          return;
        }
        _forzarReopen = false;
        unawaited(_openTrack(actual));
      } else if (!estadoCola.tieneActual) {
        // Serializado: el stop no debe pisar un open en vuelo (crash de
        // media_kit "Callback invoked after it has been deleted").
        unawaited(_enColaPlayer(() => _player.stop()));
        // Restaurar el volumen real de mpv también — el fade-out antes del
        // final del último track pudo dejarlo en 0.
        try {
          _player.setVolume((_volumenUsuario.clamp(0.0, 1.0)) * 100);
        } catch (_) {}
        emit(EstadoAudioReproductor(volumen: _volumenUsuario));
      }
    });
  }

  /// Cierre del cubit (lo llama BlocProvider al descartarlo): cancela los
  /// listeners, borra los archivos temp de stream, libera el notifier de
  /// video y descarta el player mpv. Mantiene el nombre `close` porque es el
  /// hook de disposal del framework — renombrarlo rompería la limpieza.
  @override
  Future<void> close() async {
    if (_subPerfil != null) {
      di.sl<ValueNotifier<PerfilRendimiento>>().removeListener(_onPerfilCambio);
    }
    await _subPosicion?.cancel();
    await _subDuracion?.cancel();
    await _subCompletado?.cancel();
    await _subPlaying?.cancel();
    await _subError?.cancel();
    await _subCola?.cancel();
    // Limpiar todos los archivos temp de stream.
    for (final id in _archivosTempStream.toList()) {
      await _limpiarArchivoTemp(id);
    }
    videoPrecargadoListo.dispose();
    await _player.dispose();
    return super.close();
  }
}