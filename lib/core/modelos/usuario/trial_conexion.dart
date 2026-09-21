// ─────────────────────────────────────────────────────────────
// trial_conexion.dart — La PRUEBA de 9 horas de la conexión
// multi-dispositivo para los usuarios free.
//
// Cuenta tiempo de CALENDARIO desde que el usuario la activa, igual que la
// prueba de descargas free que ya tiene la app: se arranca una vez, corre
// sola y a las 9 horas termina. Se eligió eso y no "horas de uso" porque la
// conexión multi todavía no existe (el vínculo entre aparatos es el paso
// siguiente): con tiempo de uso, el reloj no tendría quién lo moviera y la
// prueba quedaría abierta para siempre.
//
// El "ahora" lo pasa quien consulta (milisegundos) en vez de leer la hora
// este archivo: así la prueba se testea sin depender del reloj real.
//
// Se conecta con: conexion_almacen (lo guarda) + servicio_conexion (lo
// consulta) + la burbuja Conexión de Ajustes.
// Parte del flujo: Ajustes → Conexión (prueba de la multi-conexión).
// ─────────────────────────────────────────────────────────────

/// Estado de la prueba de la conexión multi-dispositivo.
class TrialConexion {
  /// Cuánto dura la prueba: 9 horas.
  static const int totalMs = 9 * 60 * 60 * 1000;

  /// Cuándo se activó, en milisegundos desde la época. 0 = nunca.
  final int iniciadoMs;

  const TrialConexion({this.iniciadoMs = 0});

  /// ¿El usuario la arrancó alguna vez?
  bool get activo => iniciadoMs > 0;

  /// Cuánto queda a las [ahoraMs], en milisegundos.
  int msRestantesEn(int ahoraMs) {
    if (!activo) return totalMs;
    final resto = totalMs - (ahoraMs - iniciadoMs);
    return resto < 0 ? 0 : resto;
  }

  /// ¿La prueba está sirviendo AHORA? (arrancada y con tiempo).
  bool sirveEn(int ahoraMs) => activo && msRestantesEn(ahoraMs) > 0;

  /// ¿Ya se agotó?
  bool terminadaEn(int ahoraMs) => activo && msRestantesEn(ahoraMs) <= 0;

  /// Arranca la prueba (si ya estaba arrancada, no la reinicia: nadie puede
  /// ganar 9 horas nuevas apretando de nuevo).
  TrialConexion iniciar(int ahoraMs) =>
      activo ? this : TrialConexion(iniciadoMs: ahoraMs);

  /// Horas y minutos que quedan, ya separados para redactar ("8 h 40 m").
  (int horas, int minutos) restanteEnHorasMinutos(int ahoraMs) {
    final total = msRestantesEn(ahoraMs) ~/ 60000;
    return (total ~/ 60, total % 60);
  }

  Map<String, dynamic> aJson() => {'iniciadoMs': iniciadoMs};

  factory TrialConexion.desdeJson(Map<String, dynamic> json) =>
      TrialConexion(iniciadoMs: (json['iniciadoMs'] as num?)?.toInt() ?? 0);
}
