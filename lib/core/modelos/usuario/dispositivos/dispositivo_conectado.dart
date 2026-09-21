// ─────────────────────────────────────────────────────────────
// dispositivo_conectado.dart — Modelo de un DISPOSITIVO de la cuenta
// (el celu, la PC, la TV y uno extra) para la burbuja Conexión de
// Ajustes.
//
// Modelo puro: sin widgets ni I/O. Cada dispositivo tiene un tipo, un
// nombre, y dos banderas que NO son lo mismo:
//   dueño     → el que manda: es el único que puede meter y sacar
//   vinculado → el que ya se emparejó alguna vez y puede conectarse
//
// Un dispositivo declarado pero todavía sin emparejar queda en
// `vinculado == false`: existe en la lista (el dueño reservó su lugar)
// pero no está conectado, así que no se lo puede "sacar" como si
// estuviera en línea.
//
// Se conecta con: servicio_conexion.dart (lo guarda y lo usa) + la
// burbuja Conexión de Ajustes.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

/// Qué tipo de aparato es. Se usa para el icono y para el nombre por
/// defecto; el usuario después lo puede renombrar.
enum TipoDispositivo {
  pc('pc'),
  celu('celu'),
  tv('tv'),
  extra('extra');

  final String clave;
  const TipoDispositivo(this.clave);

  /// Convierte una clave guardada (una clave desconocida cae en `extra`).
  static TipoDispositivo desdeClave(String? clave) {
    for (final t in TipoDispositivo.values) {
      if (t.clave == clave) return t;
    }
    return TipoDispositivo.extra;
  }
}

/// Un dispositivo de la cuenta.
class DispositivoConectado {
  /// Identificador estable del aparato (sobrevive a reinicios).
  final String id;

  /// Nombre que ve el usuario ("Celu de Pablo", "PC del cuarto").
  final String nombre;

  final TipoDispositivo tipo;

  /// ¿Es el aparato que manda? Solo uno de los cuatro lo es.
  final bool esDueno;

  /// ¿Ya se emparejó? Sin esto no cuenta como conectado.
  final bool vinculado;

  /// Última vez que se lo vio, en milisegundos desde la época (0 = nunca).
  final int ultimaVezMs;

  const DispositivoConectado({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.esDueno = false,
    this.vinculado = false,
    this.ultimaVezMs = 0,
  });

  /// Copia con los campos indicados cambiados.
  DispositivoConectado copiarCon({
    String? nombre,
    TipoDispositivo? tipo,
    bool? esDueno,
    bool? vinculado,
    int? ultimaVezMs,
  }) => DispositivoConectado(
    id: id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    esDueno: esDueno ?? this.esDueno,
    vinculado: vinculado ?? this.vinculado,
    ultimaVezMs: ultimaVezMs ?? this.ultimaVezMs,
  );

  /// ¿Está en línea ahora? Emparejado no es lo mismo que en línea: para
  /// eso hace falta que [ServicioConexion] lo haya visto hace poco.
  bool enLineaEn(int ahoraMs, {int margenMs = 2 * 60 * 1000}) =>
      vinculado && ultimaVezMs > 0 && (ahoraMs - ultimaVezMs) < margenMs;

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'tipo': tipo.clave,
    'esDueno': esDueno,
    'vinculado': vinculado,
    'ultimaVezMs': ultimaVezMs,
  };

  factory DispositivoConectado.desdeJson(Map<String, dynamic> json) =>
      DispositivoConectado(
        id: json['id'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        tipo: TipoDispositivo.desdeClave(json['tipo'] as String?),
        esDueno: json['esDueno'] == true,
        vinculado: json['vinculado'] == true,
        ultimaVezMs: (json['ultimaVezMs'] as num?)?.toInt() ?? 0,
      );
}
