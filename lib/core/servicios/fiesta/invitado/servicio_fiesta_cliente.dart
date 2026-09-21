// ─────────────────────────────────────────────────────────────
// servicio_fiesta_cliente.dart — PART de servicio_fiesta.dart: las tres
// llamadas que el invitado le hace al host y la calibración del reloj.
//
// Son tres y todas devuelven el estado del host: unirse (para quedar en la
// lista), estado (la pregunta de cada latido) y salir. Van por HTTP en la red
// local, con el id y el token del vínculo ya hecho entre los dos aparatos.
//
// La parte fina es el RELOJ: en cada respuesta el host dice a qué hora publicó
// lo que suena, y acá se estima la diferencia contra nuestro reloj usando la
// mitad del viaje de ida y vuelta. Se conserva la medición del viaje más corto,
// que es la menos contaminada por una red cargada.
//
// Se conecta con: servicio_fiesta.dart (misma library) + fiesta_estado.
// Parte del flujo: reproductor → modo fiesta → unirme.
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_fiesta.dart';

/// Las llamadas del invitado a la fiesta del host.
extension ClienteFiesta on ServicioFiesta {
  /// Avisa que se suma: el host lo anota y le devuelve el estado.
  Future<FiestaEstado?> avisarUnionFiesta(ParLan host) =>
      llamarFiesta(this, host, 'unirse', cuerpo: {'nombre': _nombre});

  /// El estado actual del host (mide el viaje para calibrar el desfase).
  Future<FiestaEstado?> pedirEstadoFiesta(ParLan host) =>
      llamarFiesta(this, host, 'estado');

  /// Avisa que se va (si no avisa, la lista del host lo saca sola).
  Future<FiestaEstado?> avisarSalidaFiesta(ParLan host) =>
      llamarFiesta(this, host, 'salir');
}

/// Una llamada al host: devuelve su estado (null si no contestó).
Future<FiestaEstado?> llamarFiesta(
  ServicioFiesta fiesta,
  ParLan host,
  String ruta, {
  Map<String, String>? cuerpo,
}) async {
  final base = 'http://${host.host}:${host.puerto}/fiesta/$ruta';
  final cabeceras = {
    'x-bitly-id': fiesta._idPropio,
    'x-bitly-token': host.token,
    if (cuerpo != null) 'content-type': 'application/json',
  };
  final antes = DateTime.now().millisecondsSinceEpoch;
  try {
    final respuesta = await (cuerpo == null
            ? http.get(Uri.parse(base), headers: cabeceras)
            : http.post(
                Uri.parse(base),
                headers: cabeceras,
                body: jsonEncode(cuerpo),
              ))
        .timeout(const Duration(seconds: 6));
    final despues = DateTime.now().millisecondsSinceEpoch;
    if (respuesta.statusCode != 200) return null;
    final json = jsonDecode(respuesta.body);
    if (json is! Map<String, dynamic>) return null;
    final estado = FiestaEstado.desdeJson(json);
    if (estado.enMs > 0) {
      final viaje = despues - antes;
      if (viaje <= fiesta._mejorIdaVueltaMs) {
        fiesta._mejorIdaVueltaMs = viaje;
        fiesta._desfaseMs = estado.enMs - (antes + despues) ~/ 2;
      }
    }
    return estado;
  } catch (e) {
    debugPrint('[Fiesta] el host no contestó ($ruta): $e');
    return null;
  }
}
