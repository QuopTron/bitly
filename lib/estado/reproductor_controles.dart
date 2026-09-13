// ─────────────────────────────────────────────────────────────
// reproductor_controles.dart — PART de cubit_reproductor.dart:
// controles del reproductor: reproducir/pausar, seek, volumen,
// velocidad, siguiente/anterior y los fades suaves (fade-in tras
// cada open, fade-out del crossfade con cancelación).
// Se conecta con: reproductor_preload_media.dart (misma library).
// Parte del flujo: reproducción (controles UI + notificación).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Controles del reproductor. Mixin aplicado en CubitReproductor.
mixin ReproductorControles on ReproductorPreloadMedia {
  void reproducir() => _player.reproducir();

  void pausar() => _player.pausar();

  void alternarReproduccion() {
    if (state.estaReproduciendo) {
      _player.pausar();
    } else {
      _player.reproducir();
    }
  }

  Future<void> buscar(Duration posicion) async {
    // Si el crossfade-out estaba bajando el volumen (últimos 1.5s de la
    // canción) y el usuario busca hacia atrás, la canción sonaría muda el
    // resto del tema — restaurar el volumen del usuario YA.
    _cancelarCrossfadeOut();
    await _player.buscar(posicion);
  }

  Future<void> buscarAProgreso(double fraccion) async {
    final dur = state.duracion;
    if (dur.inMilliseconds > 0) {
      _cancelarCrossfadeOut();
      await _player.buscar(
        Duration(
          milliseconds: (dur.inMilliseconds * fraccion.clamp(0.0, 1.0)).round(),
        ),
      );
    }
  }

  /// Cancela un crossfade-out en curso y restaura el volumen del usuario en
  /// mpv + state. Un fade-out interrumpido (seek atrás, pausa, error) que no
  /// llegara a completarse dejaría el volumen real del player en ~0 y la
  /// canción muda hasta que abriera el siguiente track.
  void _cancelarCrossfadeOut() {
    if (!_crossfadingOut) return;
    _crossfadingOut = false;
    _player.ponerVolumen(_volumenUsuario.clamp(0.0, 1.0));
    if (!isClosed) emit(state.copiarCon(volumen: _volumenUsuario));
  }

  void siguiente() => _queueCubit.siguiente();

  void anterior() => _queueCubit.anterior();

  void setVolumen(double vol) {
    // El estado y la interfaz de audio usan 0.0–1.0; la conversión a la
    // escala de cada motor (mpv: 0–100) la hace la implementación.
    final v = vol.clamp(0.0, 1.0);
    _volumenUsuario = v;
    _player.ponerVolumen(v);
    emit(state.copiarCon(volumen: v));
  }

  /// Fade-in suave tras cada apertura: sube de silencio al volumen del
  /// usuario en ~110ms. Pequeño a propósito — crossfades largos sobre el
  /// switch local↔stream arriesgan gaps audibles y latencia extra de arranque.
  Future<void> _fadeInAudio() async {
    // Siempre restaurar el volumen del USUARIO, no state.volumen que pudo
    // quedar en 0 por un fade-out que _fadeVolumen ya no escribe.
    final objetivo = _volumenUsuario.clamp(0.0, 1.0);
    if (objetivo <= 0.001) return;
    const pasos = 8;
    for (var i = 1; i <= pasos; i++) {
      _player.ponerVolumen(objetivo * i / pasos);
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }
    _player.ponerVolumen(objetivo);
    if (!isClosed) emit(state.copiarCon(volumen: objetivo));
  }

  /// Transiciona el volumen de mpv a [hasta] (0.0–1.0) en [duracion],
  /// partiendo del volumen del usuario.
  Future<void> _fadeVolumen(double hasta, Duration duracion) async {
    if (isClosed) return;
    final gen = _generacionOpen; // capturar la generación actual
    const pasos = 20;
    final pasoMs = duracion.inMilliseconds ~/ pasos;
    final desde = _volumenUsuario.clamp(0.0, 1.0);
    final destino = hasta.clamp(0.0, 1.0);
    for (var i = 1; i <= pasos; i++) {
      // Abortar si un track nuevo abrió mientras corría este crossfade — el
      // fade viejo no debe pelear con _fadeInAudio del track nuevo.
      if (isClosed || _generacionOpen != gen) return;
      _player.ponerVolumen(desde + (destino - desde) * (i / pasos));
      await Future.delayed(Duration(milliseconds: pasoMs));
    }
  }

  void setVelocidad(double velocidad) {
    final r = velocidad.clamp(0.5, 2.0);
    _player.ponerVelocidad(r);
    emit(state.copiarCon(velocidad: r));
  }
}
