// ─────────────────────────────────────────────────────────────
// servicio_conexion_reglas.dart — Las REGLAS de la cuenta: quién puede
// meter y sacar aparatos, y por qué no puede.
//
// Van aparte del servicio para que cada archivo haga una sola cosa: el
// servicio guarda y lee; acá está el criterio. Las reglas devuelven un
// MOTIVO en forma de código (`MotivoConexion`), nunca un texto: el texto
// lo arma la UI con la l10n, así el aviso se ve en el idioma del usuario.
//
// Las tres reglas del dueño:
//   1. Solo el DUEÑO mete y saca (los demás miran).
//   2. Para SACAR un aparato ya vinculado, ese aparato tiene que estar
//      conectado en ese momento: si no, se cortaría a alguien que capaz
//      ni está en la casa y no se enteraría.
//   3. Un aparato declarado pero SIN vincular se puede sacar siempre: no
//      hay nada que cortar.
//
// Se conecta con: servicio_conexion.dart (el estado) + la burbuja
// Conexión de Ajustes (que redacta el motivo con la l10n).
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

import '../../modelos/usuario/dispositivo_conectado.dart';
import 'servicio_conexion.dart';

/// Por qué una acción no se puede hacer. El texto vive en la l10n.
enum MotivoConexion {
  /// Este aparato no es el dueño de la cuenta.
  noEsDueno,

  /// El cupo del plan está lleno (free 1 / premium 4).
  cupoLleno,

  /// El aparato a sacar no está conectado ahora mismo.
  noConectado,

  /// Es el aparato en el que estás: no te podés sacar a vos mismo.
  esEste,
}

/// Consultas de permiso sobre el estado del servicio.
extension ReglasConexion on ServicioConexion {
  /// ¿Este aparato puede meter uno nuevo? Devuelve el motivo si no.
  MotivoConexion? motivoParaAgregar() {
    if (esteDispositivo?.esDueno != true) return MotivoConexion.noEsDueno;
    if (lugaresLibres <= 0) return MotivoConexion.cupoLleno;
    return null;
  }

  /// ¿Se puede sacar [d]? Devuelve el motivo si no.
  MotivoConexion? motivoParaQuitar(DispositivoConectado d) {
    if (esteDispositivo?.esDueno != true) return MotivoConexion.noEsDueno;
    if (d.id == idPropio) return MotivoConexion.esEste;
    // Sacar a alguien conectado es cortarlo en el momento (regla 2): si el
    // aparato ya no está en línea, se lo puede sacar sin más.
    if (d.vinculado && !d.enLineaEn(DateTime.now().millisecondsSinceEpoch)) {
      return MotivoConexion.noConectado;
    }
    return null;
  }

  /// Atajo: ¿se puede agregar?
  bool get puedeAgregar => motivoParaAgregar() == null;

  /// Atajo: ¿se puede sacar [d]?
  bool puedeQuitar(DispositivoConectado d) => motivoParaQuitar(d) == null;

  /// ¿Hay lugar para el cupo completo? Es lo que ofrece la prueba de 9 h.
  bool get cupoCompletoDisponible =>
      !esPremium && trialSirve && lugaresLibres > 0;
}
