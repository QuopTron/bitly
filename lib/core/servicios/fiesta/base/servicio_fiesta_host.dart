// ─────────────────────────────────────────────────────────────
// servicio_fiesta_host.dart — PART de servicio_fiesta.dart: el aparato que
// MANDA la fiesta.
//
// Armar la fiesta no cambia nada del reproductor: este aparato sigue sonando
// como siempre y, además, empieza a publicar qué suena (GET /fiesta/estado) y
// a servir ese mismo audio a los invitados (GET /fiesta/audio). El estado se
// arma EN EL MOMENTO de cada pregunta, así que nunca queda una posición vieja
// dando vueltas.
//
// Un invitado entra con POST /fiesta/unirse (queda en la lista de "los que
// están sonando") y sale con POST /fiesta/salir; si se corta la red, deja de
// aparecer solo, porque cada pregunta cuenta como latido.
//
// Se conecta con: servicio_fiesta.dart (misma library) + fiesta_estado.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'servicio_fiesta.dart';

/// Arma el estado que se publica a partir de la foto del reproductor.
///
/// Es una función suelta (y no un método) para poder probarla con una foto
/// inventada, sin abrir el player ni levantar una red.
FiestaEstado estadoDeInstantanea(InstantaneaFiesta foto) {
  final track = foto.track;
  final url = foto.url ?? '';
  // Sin pista o sin audio abierto no hay nada que prestar: los invitados ven
  // el estado vacío y esperan (mejor eso que un 404 y un error en pantalla).
  if (track == null || url.isEmpty) {
    return FiestaEstado(
      sonando: false,
      posicionMs: foto.posicion.inMilliseconds,
      enMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
  return FiestaEstado(
    // La identidad de la pista es su ISRC (o el id si no hay): es lo que
    // permite al invitado saber si cambió de canción.
    clave: (track.isrc ?? '').isNotEmpty ? track.isrc! : track.id,
    titulo: track.name,
    artista: track.artists ?? '',
    album: track.albumName ?? '',
    duracionMs: track.durationMs ?? 0,
    posicionMs: foto.posicion.inMilliseconds,
    enMs: DateTime.now().millisecondsSinceEpoch,
    sonando: foto.sonando,
  );
}

/// El lado del que manda: armar, cortar y recibir invitados.
extension HostFiesta on ServicioFiesta {
  /// Arma la fiesta en este aparato (no toca lo que está sonando).
  ///
  /// Devuelve false si no hay nada puesto: sin canción no hay parlante que
  /// armar, y avisar acá evita que los invitados se conecten a un silencio.
  Future<bool> armar() async {
    final foto = _instantanea();
    if (foto.track == null || (foto.url ?? '').isEmpty) return false;
    final identidad = await _identidad();
    _idPropio = identidad.$1;
    _nombre = identidad.$2;
    _anfitrion = null;
    _oyentes.clear();
    juntos.value = [_nombre];
    fallo.value = null;
    modo.value = ModoFiesta.host;
    estadoActualFiesta(this); // valida que el estado se arme bien antes de publicar
    return true;
  }

  /// Corta la fiesta: este aparato vuelve a ser uno solo.
  Future<void> cortar() async {
    if (!esHost) return;
    _oyentes.clear();
    juntos.value = const [];
    ajustando.value = false;
    modo.value = ModoFiesta.apagado;
  }

  /// Un invitado avisa que se suma: queda en la lista y recibe el estado.
  Future<void> _recibirUnion(io.HttpRequest pedido) async {
    final cuerpo = await utf8.decoder.bind(pedido).join();
    var nombre = '';
    try {
      final json = jsonDecode(cuerpo);
      if (json is Map<String, dynamic>) {
        nombre = json['nombre'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('[Fiesta] unión ilegible: $e');
    }
    final id = idDeFiesta(pedido);
    if (id.isNotEmpty) {
      _oyentes[id] = (
        nombre: nombre,
        vistoMs: DateTime.now().millisecondsSinceEpoch,
      );
      limpiarOyentesFiesta(this);
    }
    await responderJsonFiesta(pedido, estadoActualFiesta(this).aJson());
  }

  /// Un invitado avisa que se va (si no avisa, la lista lo saca sola).
  Future<void> _recibirSalida(io.HttpRequest pedido) async {
    final id = idDeFiesta(pedido);
    if (id.isNotEmpty) _oyentes.remove(id);
    limpiarOyentesFiesta(this);
    await responderJsonFiesta(pedido, const {'estado': 'ok'});
  }
}
