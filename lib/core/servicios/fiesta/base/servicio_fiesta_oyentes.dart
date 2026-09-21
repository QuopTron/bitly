// ─────────────────────────────────────────────────────────────
// servicio_fiesta_oyentes.dart — PART de servicio_fiesta.dart: los ayudantes
// del router (contestar JSON) y la lista de LOS QUE ESTÁN SONANDO.
//
// La lista se arma sola: cada pregunta de un invitado cuenta como latido, así
// que un aparato que se va (o pierde la red) desaparece de la lista sin que
// nadie lo saque a mano. Se usan funciones sueltas que reciben el servicio
// porque el router las llama desde otro archivo.
//
// Se conecta con: servicio_fiesta.dart (misma library).
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

part of 'servicio_fiesta.dart';

/// Contesta el JSON que espera el otro aparato.
Future<void> responderJsonFiesta(
  io.HttpRequest pedido,
  Map<String, dynamic> cuerpo,
) async {
  pedido.response.statusCode = io.HttpStatus.ok;
  pedido.response.headers.contentType = io.ContentType.json;
  pedido.response.write(jsonEncode(cuerpo));
  await pedido.response.close();
}

/// El id del aparato que hizo el pedido (viene en las cabeceras del vínculo).
String idDeFiesta(io.HttpRequest pedido) =>
    pedido.headers.value('x-bitly-id') ?? '';

/// Anota que el aparato que pregunta sigue sonando.
void anotarOyenteFiesta(ServicioFiesta fiesta, io.HttpRequest pedido) {
  final id = idDeFiesta(pedido);
  if (id.isEmpty) return;
  final previo = fiesta._oyentes[id];
  fiesta._oyentes[id] = (
    nombre: previo?.nombre ?? '',
    vistoMs: DateTime.now().millisecondsSinceEpoch,
  );
  limpiarOyentesFiesta(fiesta);
}

/// Saca de la lista a quien dejó de preguntar (se fue o se cortó la red).
///
/// El margen son seis latidos: perder uno o dos por una red cargada no puede
/// sacar de la fiesta a un aparato que sigue sonando.
void limpiarOyentesFiesta(ServicioFiesta fiesta) {
  final ahora = DateTime.now().millisecondsSinceEpoch;
  fiesta._oyentes.removeWhere(
    (_, o) => ahora - o.vistoMs > latidoFiestaMs * 6,
  );
  fiesta.juntos.value = [
    fiesta._nombre,
    for (final o in fiesta._oyentes.values)
      if (o.nombre.isNotEmpty) o.nombre,
  ];
}

/// El estado que se publica AHORA (se arma en el momento: nunca queda viejo).
FiestaEstado estadoActualFiesta(ServicioFiesta fiesta) =>
    estadoDeInstantanea(fiesta._instantanea());
