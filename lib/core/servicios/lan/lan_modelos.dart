// ─────────────────────────────────────────────────────────────
// lan_modelos.dart — Los dos datos del vínculo entre aparatos en la red
// local: un PAR (otro aparato) y una CANCIÓN de su catálogo.
//
// Modelos puros: sin sockets, sin disco y sin JSON de red adentro (eso vive
// en lan_protocolo). Así el vínculo se puede testear sin levantar nada.
//
// Un par VINCULADO guarda el token del otro aparato: es lo que autoriza a
// pedirle su catálogo y sus archivos. Un par solo DESCUBIERTO no tiene
// token, así que puede verse en la lista pero todavía no se le puede pedir
// nada.
//
// Se conecta con: lan_protocolo (los convierte a/desde JSON) +
// servicio_lan (los guarda y los usa) + la pestaña Conexión.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

// La canción del catálogo del otro aparato vive aparte (lan_cancion) y se
// reexporta: quien importa este archivo tiene los dos modelos a mano.
export 'lan_cancion.dart';

/// Otro aparato de la red local.
class ParLan {
  /// Identificador estable del otro aparato (el mismo que usa Conexión).
  final String id;

  /// Nombre que muestra: el que declaró ese aparato.
  final String nombre;

  /// IP por la que se lo vio.
  final String host;

  /// Puerto de su mini-servidor de biblioteca.
  final int puerto;

  /// Token del otro aparato. Vacío = descubierto pero NO vinculado: se lo ve,
  /// no se le puede pedir nada hasta que los dos se acepten.
  final String token;

  /// Última vez que se lo escuchó (milisegundos desde la época).
  final int ultimaVezMs;

  const ParLan({
    required this.id,
    required this.nombre,
    required this.host,
    required this.puerto,
    this.token = '',
    this.ultimaVezMs = 0,
  });

  /// ¿Ya hay confianza con este aparato?
  bool get vinculado => token.isNotEmpty;

  ParLan copiarCon({
    String? nombre,
    String? host,
    int? puerto,
    String? token,
    int? ultimaVezMs,
  }) => ParLan(
    id: id,
    nombre: nombre ?? this.nombre,
    host: host ?? this.host,
    puerto: puerto ?? this.puerto,
    token: token ?? this.token,
    ultimaVezMs: ultimaVezMs ?? this.ultimaVezMs,
  );

  /// ¿Se lo escuchó hace poco? (margen amplio: la red avisa cada 5 s).
  bool enLineaEn(int ahoraMs, {int margenMs = 20000}) =>
      ultimaVezMs > 0 && (ahoraMs - ultimaVezMs) < margenMs;

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'host': host,
    'puerto': puerto,
    'token': token,
    'ultimaVezMs': ultimaVezMs,
  };

  factory ParLan.desdeJson(Map<String, dynamic> json) => ParLan(
    id: json['id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    host: json['host'] as String? ?? '',
    puerto: (json['puerto'] as num?)?.toInt() ?? 0,
    token: json['token'] as String? ?? '',
    ultimaVezMs: (json['ultimaVezMs'] as num?)?.toInt() ?? 0,
  );
}
