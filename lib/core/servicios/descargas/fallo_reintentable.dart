// ─────────────────────────────────────────────────────────────
// fallo_reintentable.dart — Decide si un fallo de descarga se puede
// reintentar SOLO (otra vez, con otra calidad/fuente) o si necesita al
// usuario antes de intentar nada.
//
// Por qué existe: el poll marcaba los tracks fallidos como
// "interrumpido" y la cola avanzaba sin reintentar, así que una
// canción que fallaba por red o por un proveedor caído quedaba en rojo
// para siempre aunque otro intento hubiera funcionado. Al mismo tiempo
// hay cortes que reintentar no arregla nunca —sin espacio, carpeta sin
// permiso, sesión por verificar—: repetirlos solo gasta datos y repite
// el mismo aviso.
//
// Se conecta con: descargas_poll_fallido.dart y descargas_cola_track
// .dart (deciden el reintento en sitio de la cola FIFO).
// Parte del flujo: descargas (reintento en sitio).
// ─────────────────────────────────────────────────────────────

/// Marcas de un fallo que necesita al usuario: repetirlo sin cambiar nada
/// daría el mismo resultado. Coinciden con las que usa el backend Go
/// (orchestrator_errors.go) para clasificar escritura y verificación.
const List<String> _marcasNecesitanUsuario = [
  'no space left',
  'disk full',
  'enospc',
  'permission denied',
  'eacces',
  'read-only file system',
  'erofs',
  'input/output error',
  'verification_required',
  'verification required',
  'captcha',
  'signed session',
  'session expired',
  'http 428',
  'status 428',
  'prueba gratis',
  'requieren premium',
  'carpeta de descargas',
];

/// ¿Vale la pena reintentar [mensaje] sin intervención del usuario?
///
/// Un mensaje vacío se considera reintentable: sin motivo declarado, lo
/// prudente es un intento más (escala la calidad y cambia de fuente) antes
/// de dejar la canción en rojo.
bool falloDescargaReintentable(String? mensaje) {
  if (mensaje == null || mensaje.trim().isEmpty) return true;
  final m = mensaje.toLowerCase();
  for (final marca in _marcasNecesitanUsuario) {
    if (m.contains(marca)) return false;
  }
  return true;
}
