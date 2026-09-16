// ─────────────────────────────────────────────────────────────
// cola_orden_aleatorio.dart — PART de cubit_cola.dart. Orden
// ALEATORIO de la cola (shuffle) y la tecla de repetición.
//
// Por qué existe aparte: el azar de la cola tiene reglas propias y no
// triviales — se baraja UNA vez, se recorre una vez y después manda la
// repetición. Antes vivía mezclado con siguiente/anterior, y con
// shuffle sin repetición la cola nunca terminaba (elegía un índice al
// azar en cada avance y podía repetir el mismo tema).
//
// Se conecta con: cubit_cola.dart (misma library) +
// cola_navegacion.dart (se apoya en este mixin).
// Parte del flujo: reproducción (shuffle y modo de repetición).
// ─────────────────────────────────────────────────────────────

part of 'cubit_cola.dart';

/// Orden aleatorio de la cola y ciclo de repetición.
mixin ColaOrdenAleatorio on Cubit<EstadoCola> {
  /// Permutación que se está recorriendo y posición actual dentro de ella.
  ///
  /// El azar solo decide el ORDEN: se recorre la permutación una vez y al
  /// agotarse manda la repetición (sin repeat = se termina; con repeat = se
  /// vuelve a barajar y sigue).
  List<int> _ordenShuffle = [];
  int _posShuffle = -1;

  /// ¿El orden guardado sigue siendo válido para la cola actual?
  bool _ordenValido = false;

  /// Invalida el orden: se vuelve a barajar en el próximo avance. Se llama
  /// cuando cambia la lista (nuevo contexto, agregar/quitar/reordenar) y al
  /// prender/apagar shuffle.
  void _invalidarOrdenShuffle() {
    _ordenValido = false;
  }

  void alternarShuffle() {
    // Al prender/apagar se baraja de nuevo: el orden viejo pertenece a la
    // configuración anterior.
    _invalidarOrdenShuffle();
    emit(state.copiarCon(shuffle: !state.shuffle));
  }

  /// Fija shuffle on/off a un valor específico (desde controles del SO).
  void setShuffle(bool valor) {
    if (state.shuffle != valor) {
      _invalidarOrdenShuffle();
      emit(state.copiarCon(shuffle: valor));
    }
  }

  /// Ciclo pedido de la tecla de repetición: sin marcar (una vez) → repetir
  /// TODA la cola → repetir UNA canción (el "1") → sin marcar.
  void ciclarModoRepeticion() {
    const orden = [
      ModoRepeticion.ninguno,
      ModoRepeticion.todos,
      ModoRepeticion.uno,
    ];
    final siguiente = (orden.indexOf(state.modoRepeticion) + 1) % orden.length;
    emit(state.copiarCon(modoRepeticion: orden[siguiente]));
  }

  /// Avanza dentro del orden aleatorio y devuelve el índice a reproducir, o -1
  /// si la cola se agotó (sin repetición). Rearma el orden cuando hace falta:
  /// al entrar en shuffle, cuando cambió la lista o al terminar una vuelta con
  /// repetición activa.
  int _avanzarEnOrden(int actual) {
    final rearmar = !_ordenValido || _ordenShuffle.length != state.tracks.length;
    if (rearmar) {
      _ordenShuffle = _permutacion(actual);
      _posShuffle = 0;
      _ordenValido = true;
      // El track actual ya suena: el "siguiente" es el próximo del orden.
      _posShuffle = 1;
      return _ordenShuffle.length > 1 ? _ordenShuffle[_posShuffle] : actual;
    }
    _posShuffle++;
    if (_posShuffle < _ordenShuffle.length) return _ordenShuffle[_posShuffle];
    // Se terminó la vuelta: solo la repetición vuelve a empezar.
    if (state.modoRepeticion == ModoRepeticion.todos ||
        state.modoRepeticion == ModoRepeticion.uno) {
      _ordenShuffle = _permutacion(-1);
      _posShuffle = 0;
      return _ordenShuffle.first;
    }
    return -1;
  }

  /// Permutación de los índices de la cola. Con [primero] >= 0 ese índice va
  /// adelante (es el que ya está sonando), así el arranque no repite el tema
  /// actual ni pierde la primera posición.
  List<int> _permutacion(int primero) {
    final indices = List<int>.generate(state.tracks.length, (i) => i)..shuffle();
    if (primero < 0 || !indices.contains(primero)) return indices;
    final inicio = indices.indexOf(primero);
    final ordenado = <int>[indices[inicio]];
    // El resto conserva el azar, pero el que suena va primero.
    ordenado.addAll(indices.where((i) => i != primero));
    return ordenado;
  }

}
