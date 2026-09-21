// ─────────────────────────────────────────────────────────────
// servicio_lan_http.dart — PART de servicio_lan.dart: el mini-servidor que
// este aparato abre en la red local para prestar su biblioteca.
//
//   POST /lan/pair       → pedir vínculo (lo decide el usuario)
//   Todo lo demás (catálogo, audio, carátula y letra) va a _servirRecurso, en
//   servicio_lan_http_recursos.dart.
//
// Nada se entrega sin un aparato ya vinculado: hace falta su id y su token.
//
// Se conecta con: servicio_lan.dart (misma library) + lan_protocolo.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// El mini-servidor de este aparato.
extension HttpLan on ServicioLan {
  /// Atiende un pedido. Ningún error de un aparato ajeno puede voltear el
  /// vínculo: se contesta y se sigue.
  Future<void> _manejarPedido(io.HttpRequest pedido) async {
    final ruta = pedido.uri.path;
    try {
      if (pedido.method == 'POST' && ruta == '/lan/pair') {
        await _recibirSolicitud(pedido);
        return;
      }
      if (!_autorizado(pedido)) {
        await _responderJson(pedido, io.HttpStatus.unauthorized, 'token');
        return;
      }
      if (pedido.method == 'GET' && ruta.startsWith('/lan/')) {
        await _servirRecurso(pedido, ruta);
        return;
      }
      await _responderJson(pedido, io.HttpStatus.notFound, 'ruta');
    } catch (e) {
      debugPrint('[Lan] pedido fallido: $e');
      try {
        pedido.response.statusCode = io.HttpStatus.internalServerError;
        await pedido.response.close();
      } catch (_) {
        // El otro aparato cortó: no hay nada que contestar.
      }
    }
  }

  /// ¿Trae el id y el token de un aparato ya vinculado?
  bool _autorizado(io.HttpRequest pedido) {
    final id = pedido.headers.value('x-bitly-id');
    final token = pedido.headers.value('x-bitly-token');
    if (id == null) return false;
    for (final p in _lista) {
      if (p.vinculado && p.id == id && tokenValido(token, p.token)) return true;
    }
    return false;
  }

  /// Alguien pide vincularse: lo decide el usuario, y con su respuesta se
  /// cierra el pedido (así el otro aparato sabe si quedó vinculado).
  Future<void> _recibirSolicitud(io.HttpRequest pedido) async {
    final cuerpo = await utf8.decoder.bind(pedido).join();
    final par = _leerSolicitud(cuerpo, pedido);
    if (par == null) {
      await _responderJson(pedido, io.HttpStatus.badRequest, 'solicitud');
      return;
    }
    // Ya vinculado: no se vuelve a preguntar (el otro perdió la lista).
    if (_lista.any((p) => p.id == par.id && p.vinculado)) {
      await _responderJson(pedido, io.HttpStatus.ok, 'token', {
        'token': _token,
      });
      return;
    }
    solicitudVinculo.value = par;
    _decision = Completer<bool>();
    final aceptado = await _decision!.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
    _decision = null;
    solicitudVinculo.value = null;
    if (!aceptado) {
      await _responderJson(pedido, io.HttpStatus.forbidden, 'rechazado');
      return;
    }
    await _responderJson(pedido, io.HttpStatus.ok, 'token', {'token': _token});
  }

  /// Lee el pedido de vínculo (null si viene incompleto).
  ParLan? _leerSolicitud(String cuerpo, io.HttpRequest pedido) {
    try {
      final json = jsonDecode(cuerpo);
      if (json is! Map<String, dynamic>) return null;
      final par = ParLan(
        id: json['id'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        host: pedido.connectionInfo?.remoteAddress.address ?? '',
        puerto: (json['puerto'] as num?)?.toInt() ?? 0,
        token: json['token'] as String? ?? '',
        ultimaVezMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (par.id.isEmpty || par.id == _idPropio || !par.vinculado) return null;
      return par;
    } catch (_) {
      return null;
    }
  }

  /// Contesta JSON corto (ok o el motivo del rechazo).
  Future<void> _responderJson(
    io.HttpRequest pedido,
    int codigo,
    String clave, [
    Map<String, dynamic> extra = const {},
  ]) async {
    pedido.response.statusCode = codigo;
    pedido.response.headers.contentType = io.ContentType.json;
    pedido.response.write(jsonEncode({'estado': clave, ...extra}));
    await pedido.response.close();
  }
}
