// ─────────────────────────────────────────────────────────────
// cola_navegacion.dart — PART de cubit_cola.dart. Navegación de la
// cola: siguiente/anterior (con historial real en shuffle) y saltar a
// índice. El orden aleatorio vive en cola_orden_aleatorio.dart.
// Se conecta con: EstadoCola (mismo library).
// Parte del flujo: reproducción (controles del player/miniplayer).
// ─────────────────────────────────────────────────────────────

part of 'cubit_cola.dart';

/// Navegación de la cola. Mixin aplicado en CubitCola.
mixin ColaNavegacion on ColaOrdenAleatorio {
  /// Índices de tracks reproducidos previamente (registrados con shuffle
  /// activo) para que `anterior()` vuelva al track REAL que sonó antes en vez
  /// de uno aleatorio. Acotado para evitar crecimiento infinito; se limpia
  /// cuando la cola se reemplaza con un contexto nuevo.
  final List<int> _historial = [];

  /// Avanza al siguiente track. Devuelve true si hay track para reproducir,
  /// false si la cola se agotó (sin más tracks y sin repeat).
  ///
  /// Repeat-one NO se maneja aquí a propósito: re-emitir el mismo índice
  /// produce un estado idéntico que bloc ≥ 9 descarta silenciosamente, así
  /// que el replay al terminar la canción lo hace CubitReproductor reabriendo
  /// el track directamente. Por eso un toque MANUAL de "siguiente" con
  /// repeat-one activo avanza a otra canción (como Spotify) en vez de
  /// quedarse atascado en un emit que nadie recibe.
  bool siguiente() {
    if (state.tracks.isEmpty) return false;
    final desde = state.indiceActual;
    int siguienteIndice;
    if (state.shuffle) {
      if (desde >= 0) {
        _historial.add(desde);
        if (_historial.length > 100) _historial.removeAt(0);
      }
      if (state.tracks.length <= 1) {
        // Una sola canción en shuffle no puede "elegir otra". Con repeat-all
        // el replay lo maneja el player en EOF; sin repeat la cola se agota.
        if (state.modoRepeticion == ModoRepeticion.todos) {
          emit(state.copiarCon(indiceActual: desde));
          return true;
        }
        emit(state.copiarCon(indiceActual: -1));
        return false;
      }
      final avanzado = _avanzarEnOrden(desde);
      if (avanzado < 0) return false;
      emit(state.copiarCon(indiceActual: avanzado));
      return true;
    } else {
      siguienteIndice = desde + 1;
      if (siguienteIndice >= state.tracks.length) {
        if (state.modoRepeticion == ModoRepeticion.todos) {
          siguienteIndice = 0;
        } else {
          emit(state.copiarCon(indiceActual: -1));
          return false; // cola agotada
        }
      }
    }
    emit(state.copiarCon(indiceActual: siguienteIndice));
    return true;
  }

  void anterior() {
    if (state.tracks.isEmpty || !state.tieneActual) return;
    if (state.shuffle) {
      // Con shuffle, "anterior" vuelve al track que realmente sonó antes
      // (historial) en lugar de saltar a un índice aleatorio. Además se mueve
      // el cursor del orden: volver atrás y avanzar de nuevo debe caer en el
      // MISMO siguiente, no en otro al azar.
      while (_historial.isNotEmpty) {
        final ultimo = _historial.removeLast();
        if (ultimo >= 0 && ultimo < state.tracks.length && ultimo != state.indiceActual) {
          final pos = _ordenShuffle.indexOf(ultimo);
          if (pos >= 0) _posShuffle = pos;
          emit(state.copiarCon(indiceActual: ultimo));
          return;
        }
      }
      // Sin historial (arranque): se queda en el primer lugar del orden.
      if (_ordenShuffle.isNotEmpty) {
        _posShuffle = 0;
        emit(state.copiarCon(indiceActual: _ordenShuffle.first));
        return;
      }
      emit(state.copiarCon(indiceActual: _indiceAleatorio()));
      return;
    }
    final previo = state.indiceActual - 1;
    if (previo < 0) {
      if (state.modoRepeticion == ModoRepeticion.todos) {
        emit(state.copiarCon(indiceActual: state.tracks.length - 1));
      } else {
        emit(state.copiarCon(indiceActual: 0));
      }
    } else {
      emit(state.copiarCon(indiceActual: previo));
    }
  }

  void irA(int index) {
    if (index < 0 || index >= state.tracks.length) return;
    emit(state.copiarCon(indiceActual: index));
  }

  /// Fija el modo de repetición desde los controles del SO.
  void setModoRepeticionStr(String mode) {
    final ModoRepeticion siguiente;
    switch (mode) {
      case 'one':
        siguiente = ModoRepeticion.uno;
      case 'all':
        siguiente = ModoRepeticion.todos;
      default:
        siguiente = ModoRepeticion.ninguno;
    }
    if (state.modoRepeticion != siguiente) {
      emit(state.copiarCon(modoRepeticion: siguiente));
    }
  }

  int _indiceAleatorio() {
    if (state.tracks.length <= 1) return 0;
    int idx;
    do {
      idx = Random().nextInt(state.tracks.length);
    } while (idx == state.indiceActual);
    return idx;
  }
}