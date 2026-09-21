// ─────────────────────────────────────────────────────────────
// servicio_fiesta_invitado.dart — PART de servicio_fiesta.dart: el aparato que
// SIGUE la fiesta.
//
// El invitado no resuelve ninguna canción: le pide al host su audio
// (/fiesta/audio) y su estado (/fiesta/estado) por la red local. Cada segundo y
// medio vuelve a preguntar, recalcula su desfase contra el reloj del host
// (mitad del viaje de ida y vuelta) y, si la canción va corrida más de lo que
// se tolera, se pone en el segundo que corresponde.
//
// Tiene su PROPIO motor de audio: el reproductor de la app queda pausado
// mientras dura la fiesta, así no se mezclan las dos reproducciones.
//
// Se conecta con: servicio_fiesta.dart (misma library) + el motor de fiesta.
// Parte del flujo: reproductor → modo fiesta → unirme.
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_fiesta.dart';

/// El lado del que sigue la fiesta (y sus dos llamadas al host).
extension InvitadoFiesta on ServicioFiesta {
  /// Se suma a la fiesta de [anfitrion] (un aparato ya vinculado).
  ///
  /// Devuelve false cuando el host no contesta o no tiene nada sonando: en ese
  /// caso no se queda a medias, se vuelve a apagado.
  Future<bool> unirse(ParLan anfitrion) async {
    _anfitrion = anfitrion;
    _desfaseMs = 0;
    _mejorIdaVueltaMs = 1 << 30;
    _claveActual = '';
    final identidad = await _identidad();
    _idPropio = identidad.$1;
    _nombre = identidad.$2;
    fallo.value = null;
    // El audio que va a sonar es el del host: el de acá se calla.
    _pausarLocal();
    final estado = await avisarUnionFiesta(anfitrion);
    if (estado == null || !estado.hayPista) {
      fallo.value = estado == null ? 'sinHost' : 'sinAudio';
      _anfitrion = null;
      modo.value = ModoFiesta.apagado;
      return false;
    }
    modo.value = ModoFiesta.invitado;
    juntos.value = [anfitrion.nombre, _nombre];
    ultimoEstado.value = estado;
    await _aplicar(estado);
    _latido?.cancel();
    _latido = Timer.periodic(
      const Duration(milliseconds: latidoFiestaMs),
      (_) => unawaited(_preguntar()),
    );
    return true;
  }

  /// Sale de la fiesta (avisa al host y suelta su motor de audio).
  Future<void> salir() async {
    _latido?.cancel();
    _latido = null;
    final host = _anfitrion;
    _anfitrion = null;
    if (host != null) unawaited(avisarSalidaFiesta(host));
    await _player?.dispose();
    _player = null;
    _claveActual = '';
    modo.value = ModoFiesta.apagado;
    juntos.value = const [];
    ajustando.value = false;
  }

  /// Una vuelta más: pregunta cómo va, ajusta el desfase y corrige.
  Future<void> _preguntar() async {
    final host = _anfitrion;
    if (host == null || modo.value != ModoFiesta.invitado) return;
    final estado = await pedirEstadoFiesta(host);
    if (estado == null) {
      // Tres preguntas seguidas sin respuesta = el host se fue.
      _fallos++;
      if (_fallos >= 3) {
        fallo.value = 'sinHost';
        await salir();
      }
      return;
    }
    _fallos = 0;
    ultimoEstado.value = estado;
    await _aplicar(estado);
  }

  /// Deja al invitado sonando como el host: misma canción, mismo segundo.
  Future<void> _aplicar(FiestaEstado estado) async {
    if (!estado.hayPista) return;
    final player = _player;
    if (player == null || _claveActual != estado.clave) {
      await _abrir(estado);
      return;
    }
    if (estado.sonando != player.reproduciendo) {
      if (estado.sonando) {
        await player.reproducir();
      } else {
        await player.pausar();
      }
    }
    if (!estado.sonando) return;
    final esperada = estado.posicionEsperadaMs(
      DateTime.now().millisecondsSinceEpoch,
      _desfaseMs,
    );
    if (!estado.hayDeriva(player.posicion.inMilliseconds, esperada)) return;
    ajustando.value = true;
    await player.buscar(Duration(milliseconds: esperada));
    ajustando.value = false;
  }

  /// Abre (o reabre) el audio del host y lo deja en el segundo que va.
  Future<void> _abrir(FiestaEstado estado) async {
    final host = _anfitrion;
    if (host == null) return;
    final player = _player ?? crearReproductorFiesta();
    if (player == null) {
      fallo.value = 'sinAudio';
      await salir();
      return;
    }
    _player = player;
    _claveActual = estado.clave;
    // El parámetro cambia con la canción: el motor abre una URL distinta y no
    // se queda con el audio anterior.
    final url =
        'http://${host.host}:${host.puerto}/fiesta/audio'
        '?p=${Uri.encodeComponent(estado.clave)}';
    try {
      await player.abrir(url);
      await player.buscar(
        Duration(
          milliseconds: estado.posicionEsperadaMs(
            DateTime.now().millisecondsSinceEpoch,
            _desfaseMs,
          ),
        ),
      );
      if (estado.sonando) await player.reproducir();
    } catch (e) {
      debugPrint('[Fiesta] no se pudo abrir el audio del host: $e');
      fallo.value = 'sinAudio';
    }
  }
}
