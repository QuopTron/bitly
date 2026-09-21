// ─────────────────────────────────────────────────────────────
// motivos_descarga.dart — Clasifica el error crudo de una descarga
// (texto técnico que devuelve Go/el proveedor) en dos cosas que la app
// puede usar sin mostrar ese texto al usuario:
//
//   1. un CÓDIGO estable de motivo, que la UI traduce con l10n;
//   2. si el fallo se puede reintentar SOLO o si necesita al usuario.
//
// Por qué existe: la tarjeta de fallo interpolaba el mensaje crudo del
// backend ("Motivo: <texto de Go>"), que sale en español aunque la app
// esté en inglés. Clasificando, la UI muestra un motivo entendible y el
// texto crudo queda solo en el log.
//
// Al mismo tiempo, hay cortes que reintentar no arregla nunca —sin
// espacio, carpeta sin permiso, sesión por verificar—: repetirlos solo
// gasta datos y repite el mismo aviso.
//
// Se conecta con: descargas_cola(_reintento).dart, descargas_poll_fallido
// .dart y avisos_descarga_armado.dart.
// Parte del flujo: descargas (reintento en sitio y aviso de fallo).
// ─────────────────────────────────────────────────────────────

/// Códigos de motivo de fallo. Son estables y neutros de idioma: la UI los
/// traduce con `StringsDescargas.motivoDescarga`.
class MotivosDescarga {
  MotivosDescarga._();

  static const espacio = 'espacio';
  static const permiso = 'permiso';
  static const verificacion = 'verificacion';
  static const premium = 'premium';
  static const carpeta = 'carpeta';
  static const red = 'red';
  static const desconocido = 'desconocido';

  /// La descarga "terminó" pero no dejó un archivo reproducible.
  static const sinArchivo = 'sin_archivo';

  /// El backend nunca reportó el fin de la descarga (p.ej. timeout).
  static const sinFin = 'sin_fin';
}

/// Marcas del error crudo agrupadas por código. Las cinco primeras piden
/// algo del usuario; `red` sí se reintenta. Coinciden con las que usa el
/// backend Go (orchestrator_errors.go) para clasificar escritura y
/// verificación.
const Map<String, List<String>> _marcasPorMotivo = {
  MotivosDescarga.espacio: ['no space left', 'disk full', 'enospc'],
  MotivosDescarga.permiso: [
    'permission denied',
    'eacces',
    'read-only file system',
    'erofs',
    'input/output error',
  ],
  MotivosDescarga.verificacion: [
    'verification_required',
    'verification required',
    'captcha',
    'signed session',
    'session expired',
    'http 428',
    'status 428',
  ],
  MotivosDescarga.premium: ['prueba gratis', 'requieren premium'],
  MotivosDescarga.carpeta: ['carpeta de descargas'],
  MotivosDescarga.red: [
    'sin conexión',
    'offline',
    'timeout',
    'timed out',
    'connection reset',
    'network',
    'dns',
  ],
};

/// Código del motivo según [mensaje]. Un mensaje vacío o sin marcas cae a
/// `desconocido`: la UI nunca debe quedarse sin explicación.
String claveMotivoDescarga(String? mensaje) {
  if (mensaje == null || mensaje.trim().isEmpty) {
    return MotivosDescarga.desconocido;
  }
  final m = mensaje.toLowerCase();
  for (final grupo in _marcasPorMotivo.entries) {
    for (final marca in grupo.value) {
      if (m.contains(marca)) return grupo.key;
    }
  }
  return MotivosDescarga.desconocido;
}

/// Todos los códigos válidos, para reconocer un valor que YA es código.
const Set<String> _codigosConocidos = {
  MotivosDescarga.espacio,
  MotivosDescarga.permiso,
  MotivosDescarga.verificacion,
  MotivosDescarga.premium,
  MotivosDescarga.carpeta,
  MotivosDescarga.red,
  MotivosDescarga.desconocido,
  MotivosDescarga.sinArchivo,
  MotivosDescarga.sinFin,
};

/// Normaliza lo que quedó guardado en el estado: si ya es un código lo deja
/// igual, y si es el mensaje crudo del backend lo clasifica. Así el aviso al
/// usuario nunca depende de qué escribió cada rama.
String normalizarMotivoDescarga(String? valor) {
  final v = (valor ?? '').trim();
  if (_codigosConocidos.contains(v)) return v;
  return claveMotivoDescarga(v);
}

/// ¿Vale la pena reintentar [mensaje] sin intervención del usuario?
///
/// Un mensaje vacío se considera reintentable: sin motivo declarado, lo
/// prudente es un intento más (escala la calidad y cambia de fuente) antes
/// de dejar la canción en rojo. Lo mismo con los motivos que no piden nada
/// al usuario (red, desconocido).
bool falloDescargaReintentable(String? mensaje) {
  final clave = claveMotivoDescarga(mensaje);
  return clave == MotivosDescarga.red || clave == MotivosDescarga.desconocido;
}
