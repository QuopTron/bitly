// ─────────────────────────────────────────────────────────────
// servicio_lan_descubrimiento.dart — PART de servicio_lan.dart: encontrar a
// los otros aparatos de la red sin saber sus IPs.
//
// Se manda un anuncio a la dirección de difusión cada pocos segundos y se
// escucha el mismo puerto: así dos aparatos que nunca se vieron se encuentran
// solos. Se ignoran los anuncios de otros programas (van firmados) y los
// propios, que también se escuchan a sí mismos.
//
// La difusión NO autentica nada: solo dice "estoy acá y me llamo así". Pedir
// el catálogo sigue necesitando el token del vínculo.
//
// Se conecta con: servicio_lan.dart (misma library) + lan_protocolo.
// Parte del flujo: Ajustes → Conexión → aparatos en tu red.
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_lan.dart';

/// Anuncio y escucha de vecinos en la red local.
extension DescubrimientoLan on ServicioLan {
  /// Abre el socket de difusión y arranca el saludo periódico.
  Future<void> _abrirDifusion() async {
    final socket = await io.RawDatagramSocket.bind(
      io.InternetAddress.anyIPv4,
      puertoDescubrimiento,
      // Dos apps en la misma máquina (o un test) tienen que poder escuchar.
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    _difusion = socket;
    socket.listen(_alEscucharVecino, onError: _ignorarErrorDeRed);
    _saludar();
    _latido = Timer.periodic(const Duration(seconds: 5), (_) => _saludar());
  }

  /// Cierra el socket y el latido (se llama al apagar el vínculo).
  void _cerrarDifusion() {
    _latido?.cancel();
    _latido = null;
    try {
      _difusion?.close();
    } catch (e) {
      debugPrint('[Lan] no se pudo cerrar la difusión: $e');
    }
    _difusion = null;
  }

  /// Manda quién soy a toda la red.
  void _saludar() {
    final socket = _difusion;
    if (socket == null || _idPropio.isEmpty || _puerto <= 0) return;
    try {
      socket.send(
        utf8.encode(
          armarAnuncio(id: _idPropio, nombre: _nombre, puerto: _puerto),
        ),
        io.InternetAddress('255.255.255.255'),
        puertoDescubrimiento,
      );
    } catch (e) {
      debugPrint('[Lan] no se pudo saludar: $e');
    }
  }

  /// Llegó algo por la difusión: si es del vínculo, se lo anota.
  void _alEscucharVecino(io.RawSocketEvent evento) {
    final socket = _difusion;
    if (socket == null || evento != io.RawSocketEvent.read) return;
    final datagrama = socket.receive();
    if (datagrama == null) return;
    final anuncio = leerAnuncio(
      utf8.decode(datagrama.data, allowMalformed: true),
      idPropio: _idPropio,
    );
    if (anuncio == null) return;
    final visto = anuncio.copiarCon(
      host: datagrama.address.address,
      ultimaVezMs: DateTime.now().millisecondsSinceEpoch,
    );
    // Un vecino nuevo se guarda; los siguientes saludos solo refrescan la
    // hora, así la difusión no escribe en la base cada cinco segundos.
    if (anotarVecino(visto)) unawaited(guardarPares());
  }
}
