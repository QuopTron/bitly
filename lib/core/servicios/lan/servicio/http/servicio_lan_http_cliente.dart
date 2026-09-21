// ─────────────────────────────────────────────────────────────
// servicio_lan_http_cliente.dart — PART de servicio_lan.dart: la plomería
// HTTP del lado que pide (pedir un JSON corto, firmar el pedido y juntar el
// cuerpo de un archivo).
//
// Va aparte para que servicio_lan_cliente quede con lo que el usuario ve
// (vincular, traer catálogo, copiar) y no con los detalles de las conexiones.
// Todos los tiempos están acotados: si el otro aparato no contesta, no se
// queda esperando para siempre.
//
// Se conecta con: servicio_lan_cliente.dart (misma library) + lan_protocolo.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_lan.dart';

/// Pedidos HTTP contra el mini-servidor del otro aparato.
extension HttpClienteLan on ServicioLan {
  /// Pide un JSON corto al otro aparato (null si falla o no autoriza).
  Future<Map<String, dynamic>?> _pedirJson(
    String metodo,
    String ruta,
    ParLan par, {
    Map<String, dynamic>? cuerpo,
    Duration? espera,
    bool conToken = true,
  }) async {
    try {
      final cliente =
          io.HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final pedido = await cliente.openUrl(
        metodo,
        Uri.parse('http://${par.host}:${par.puerto}$ruta'),
      );
      if (conToken) _conToken(pedido);
      if (cuerpo != null) {
        pedido.headers.contentType = io.ContentType.json;
        pedido.write(jsonEncode(cuerpo));
      }
      final respuesta = await pedido.close().timeout(
        espera ?? const Duration(seconds: 15),
      );
      final texto = await utf8.decoder.bind(respuesta).join();
      if (respuesta.statusCode != io.HttpStatus.ok) {
        // Queda dicho en el log: si el otro aparato no autoriza, hay que
        // volver a vincular, y eso se ve acá.
        debugPrint('[Lan] $ruta contestó ${respuesta.statusCode}');
        return null;
      }
      final json = jsonDecode(texto);
      return json is Map<String, dynamic> ? json : null;
    } catch (e) {
      debugPrint('[Lan] falló $ruta en ${par.nombre}: $e');
      return null;
    }
  }

  /// Firma el pedido con la identidad y el TOKEN PROPIO.
  ///
  /// Se manda el token de este aparato, no el del otro: el otro guardó el
  /// nuestro cuando nos aceptó, y es eso lo que valida que el pedido sea
  /// nuestro. Mandarle su propio token no probaría nada.
  void _conToken(io.HttpClientRequest pedido) {
    pedido.headers.set('x-bitly-id', _idPropio);
    pedido.headers.set('x-bitly-token', _token);
  }

  /// Los bytes de un archivo del otro aparato (null si no lo tiene o falló).
  /// Sirve para el audio, la carátula y la letra: es el mismo pedido.
  Future<List<int>?> _traerBytes(ParLan par, String ruta) async {
    try {
      final cliente =
          io.HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final pedido = await cliente.openUrl(
        'GET',
        Uri.parse('http://${par.host}:${par.puerto}$ruta'),
      );
      _conToken(pedido);
      final respuesta = await pedido.close();
      if (respuesta.statusCode != io.HttpStatus.ok) {
        // Se descarta el cuerpo para no dejar la conexión colgada. Es normal:
        // no toda canción tiene carátula ni letra.
        await respuesta.drain<void>();
        return null;
      }
      return await _juntarBytes(respuesta);
    } catch (e) {
      debugPrint('[Lan] no se pudo traer $ruta: $e');
      return null;
    }
  }

  /// Junta el cuerpo de a pedazos: un FLAC entero no entra cómodo en memoria
  /// de una sola lectura.
  Future<List<int>> _juntarBytes(io.HttpClientResponse respuesta) async {
    final bytes = <int>[];
    await for (final pedazo in respuesta) {
      bytes.addAll(pedazo);
    }
    return bytes;
  }
}
