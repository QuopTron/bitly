// ─────────────────────────────────────────────────────────────
// escalado_calidad.dart — Lógica PURA del escalado de calidad de los
// reintentos de descarga: cuando una canción falla, el reintento baja
// UN escalón (sin pérdida → 320 → 128) en vez de pedir siempre lo
// mismo. Nunca sube: pedir mejor calidad que la configurada gastaría
// datos del usuario sin que lo haya pedido.
// Se conecta con: descargas_cola_reintento.dart (usa esta función).
// Parte del flujo: descargas (reintento en sitio de la cola FIFO).
// ─────────────────────────────────────────────────────────────

/// Escalones de calidad, de mejor a peor. El índice es el "escalón": 0 =
/// sin pérdida, 1 = MP3 320, 2 = MP3 128.
const List<String> escalonesCalidadDescarga = ['FLAC', 'MP3_320', 'MP3_128'];

/// Escalón de una calidad pedida/por defecto.
int escalonDeCalidad(String calidad) {
  final c = calidad.toUpperCase();
  if (c.contains('MP3_320') || c.contains('320')) return 1;
  if (c.contains('MP3_128') || c.contains('128') || c.contains('LOW')) return 2;
  return 0; // FLAC / LOSSLESS / HI_RES / desconocido → el mejor
}

/// Calidad a pedir en el intento [intento] (1 = el primero, el pedido por el
/// usuario). Devuelve null para el primer intento cuando no hay una calidad
/// forzada: null significa "usá la calidad de los ajustes de descarga".
String? calidadParaIntento({
  required String? forzada,
  required String calidadAjustes,
  required int intento,
}) {
  if (intento <= 1) return forzada;
  final objetivo = escalonDeCalidad(forzada ?? calidadAjustes) + (intento - 1);
  final limitado = objetivo.clamp(0, escalonesCalidadDescarga.length - 1);
  // En el primer escalón no se fuerza nada: se respeta lo que pida la app.
  return limitado == 0 ? forzada : escalonesCalidadDescarga[limitado];
}
