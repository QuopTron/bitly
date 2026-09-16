// ─────────────────────────────────────────────────────────────
// compartido_recibido.dart — Un ítem que otra persona te compartió:
// los datos del enlace (emisor, canción, ISRC, carátula) más cuándo
// llegó.
//
// Se guarda en los ajustes como JSON, así que la serialización es
// explícita y tolerante: si un campo viene raro, no se pierde la
// entrada entera.
//
// Se conecta con: servicio_historial_compartidos (serializa) y la
// sección de Ajustes que lo lista.
// Parte del flujo: enlace recibido → historial "quién te compartió qué".
// ─────────────────────────────────────────────────────────────

import 'datos_compartido.dart';

/// Un compartido recibido, con su fecha de llegada.
class CompartidoRecibido {
  final DatosCompartido datos;
  final DateTime fecha;

  const CompartidoRecibido({required this.datos, required this.fecha});

  /// Clave para no repetir la misma canción del mismo emisor.
  String get clave => '${datos.emisor}|${datos.isrc.isNotEmpty ? datos.isrc : datos.nombre}';

  Map<String, dynamic> aJson() => {
        ...datos.aJson(),
        'ts': fecha.millisecondsSinceEpoch,
      };

  factory CompartidoRecibido.desdeJson(Map<String, dynamic> json) {
    final crudo = json['ts'];
    final ms = crudo is int ? crudo : int.tryParse('$crudo') ?? 0;
    return CompartidoRecibido(
      datos: DatosCompartido.desdeJson(json),
      fecha: DateTime.fromMillisecondsSinceEpoch(
        ms > 0 ? ms : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
