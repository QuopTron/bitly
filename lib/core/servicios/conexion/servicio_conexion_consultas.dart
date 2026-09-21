// ─────────────────────────────────────────────────────────────
// servicio_conexion_consultas.dart — PART de servicio_conexion.dart: los
// getters de consulta sobre el estado (qué aparatos hay, cuál manda, cuánto
// cupo queda).
//
// Van como extensión (y no dentro de la clase) para que el archivo del
// servicio quede con una sola responsabilidad: el estado y lo que lo
// cambia. Al ser parte de la MISMA library, la extensión ve los campos
// privados, así que no hay que exponerlos.
//
// Se conecta con: servicio_conexion.dart (misma library) +
// dispositivo_conectado + trial_conexion.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

part of 'servicio_conexion.dart';

/// Consultas de solo lectura del estado de la conexión.
extension ConsultasConexion on ServicioConexion {
  /// Dispositivos de la cuenta, en el orden guardado.
  List<DispositivoConectado> get dispositivos => _dispositivos;

  /// La prueba de 9 horas.
  TrialConexion get trial => _trial;

  /// ¿Este aparato es premium?
  bool get esPremium => _premium;

  /// ¿Ya se cargó del disco?
  bool get cargado => _cargado;

  /// El id de ESTE aparato (para saber cuál de la lista es "este").
  String get idPropio => _idPropio;

  /// El aparato que manda, o null si todavía no hay ninguno.
  DispositivoConectado? get dueno {
    for (final d in _dispositivos) {
      if (d.esDueno) return d;
    }
    return null;
  }

  /// El aparato en el que corre esta copia de la app.
  DispositivoConectado? get esteDispositivo {
    for (final d in _dispositivos) {
      if (d.id == _idPropio) return d;
    }
    return null;
  }

  /// ¿La prueba de 9 h está sirviendo en este momento?
  bool get trialSirve => _trial.sirveEn(DateTime.now().millisecondsSinceEpoch);

  /// Cupo permitido AHORA: premium y la prueba de 9 h habilitan los 4.
  int get cupo => _premium || trialSirve ? cupoPremium : cupoFree;

  /// Las novedades que todavía no se vieron: el mininumerito de la burbuja y
  /// el aviso de la pestaña salen de acá, así nunca muestran números
  /// distintos. Un aparato vinculado, o el propio, ya no son novedad.
  List<NovedadConexion> get novedades => [
    if (!_premium && !_trial.activo)
      const NovedadConexion(id: 'prueba', tipo: TipoNovedadConexion.prueba),
    for (final d in _dispositivos)
      if (!d.vinculado)
        NovedadConexion(
          id: d.id,
          tipo: TipoNovedadConexion.aparatoPendiente,
          aparato: d.nombre,
          tipoAparato: d.tipo,
        ),
  ].where((n) => !_vistas.contains(n.id)).toList(growable: false);

  /// Cuántas novedades hay sin ver (el número del mininumerito).
  int get novedadesNuevas => novedades.length;

  /// Lugares libres.
  int get lugaresLibres {
    final libres = cupo - _dispositivos.length;
    return libres < 0 ? 0 : libres;
  }
}
