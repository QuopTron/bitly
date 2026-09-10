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
  void reproducir() => _player.play();

  void pausar() => _player.pause();

  void alternarReproduccion() {
    if (state.estaReproduciendo) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  Future<void> buscar(Duration posicion) async {
    // Si el crossfade-out estaba bajando el volumen (últimos 1.5s de la
    // canción) y el usuario busca hacia atrás, la canción sonaría muda el
    // resto del tema — restaurar el volumen del usuario YA.
    _cancelarCrossfadeOut();
    await _player.seek(posicion);
  }

  Future<void> buscarAProgreso(double fraccion) async {
    final dur = state.duracion;
    if (dur.inMilliseconds > 0) {
      _cancelarCrossfadeOut();
      await _player.seek(
        Duration(
          milliseconds:
              (dur.inMilliseconds * fraccion.clamp(0.0, 1.0)).round(),
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
    try {
      _player.setVolume((_volumenUsuario.clamp(0.0, 1.0)) * 100);
    } catch (_) {}
    if (!isClosed) emit(state.copiarCon(volumen: _volumenUsuario));
  }

  void siguiente() => _queueCubit.siguiente();

  void anterior() => _queueCubit.anterior();

  void setVolumen(double vol) {
    // El estado guarda 0.0–1.0 pero media_kit pasa el valor directo a la
    // propiedad `volume` de mpv, que es 0–100 (default 100). Sin el ×100 la
    // app reproducía a ~1% — técnicamente "reproduciendo" pero inaudible.
    final v = vol.clamp(0.0, 1.0);
    _volumenUsuario = v;
    _player.setVolume(v * 100);
    emit(state.copiarCon(volumen: v));
  }

  /// Fade-in suave tras cada [_player.open]: sube de silencio al volumen del
  /// usuario en ~110ms. Pequeño a propósito — crossfades largos sobre el
  /// switch local↔stream arriesgan gaps audibles y latencia extra de arranque.
  Future<void> _fadeInAudio() async {
    // Siempre restaurar el volumen del USUARIO, no state.volumen que pudo
    // quedar en 0 por un fade-out que _fadeVolumen ya no escribe.
    final objetivo = _volumenUsuario.clamp(0.0, 1.0);
    if (objetivo <= 0.001) return;
    const pasos = 8;
    // Convertir el objetivo 0–1 a la escala 0–100 de mpv, si no el fade
    // termina en volume=1 (1%) y el playback es inaudible.
    final objetivo100 = objetivo * 100;
    try {
      for (var i = 1; i <= pasos; i++) {
        await _player.setVolume(objetivo100 * i / pasos);
        await Future<void>.delayed(const Duration(milliseconds: 14));
      }
      await _player.setVolume(objetivo100);
    } catch (_) {
      // Nunca dejar que un fade cosmético falle la reproducción.
    }
    if (!isClosed) emit(state.copiarCon(volumen: objetivo));
  }

  /// Transiciona el volumen de mpv a [hasta] (0.0–1.0) en [duracion],
  /// partiendo del volumen del usuario.
  Future<void> _fadeVolumen(double hasta, Duration duracion) async {
    if (isClosed) return;
    final gen = _generacionOpen; // capturar la generación actual
    const pasos = 20;
    final pasoMs = duracion.inMilliseconds ~/ pasos;
    final desde100 = _volumenUsuario * 100;
    final hasta100 = hasta * 100;
    for (var i = 1; i <= pasos; i++) {
      // Abortar si un track nuevo abrió mientras corría este crossfade — el
      // fade viejo no debe pelear con _fadeInAudio del track nuevo.
      if (isClosed || _generacionOpen != gen) return;
      final v = desde100 + (hasta100 - desde100) * (i / pasos);
      _player.setVolume(v.clamp(0, 100));
      await Future.delayed(Duration(milliseconds: pasoMs));
    }
  }

  void setVelocidad(double velocidad) {
    final r = velocidad.clamp(0.5, 2.0);
    if (r == 1.0) {
      _player.setRate(1.0);
    } else {
      _player.setRate(r);
    }
    emit(state.copiarCon(velocidad: r));
  }
}