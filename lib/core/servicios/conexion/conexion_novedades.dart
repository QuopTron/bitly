// ─────────────────────────────────────────────────────────────
// conexion_novedades.dart — Qué es "algo nuevo" en la burbuja CONEXIÓN y
// el mininumerito que lo cuenta.
//
// Dos cosas cuentan como novedad, espejo del cofre de Apariencia:
//   · la PRUEBA de 9 horas, mientras esté disponible y sin usar (es un
//     regalo, y es lo que el usuario free todavía no tocó);
//   · un APARATO declarado pero SIN VINCULAR: existe en la lista, pide su
//     lugar, y todavía no se conectó.
//
// Las novedades se marcan como vistas al abrir la pestaña (son avisos, no
// reclamos): si no, el mininumerito quedaría encendido para siempre por un
// aparato que hoy no se puede emparejar.
//
// El notifier vive acá para que la burbuja y el aviso de adentro muestren
// siempre el mismo número. No conoce la inyección ni la caché: el valor lo
// escribe quien ya tiene el estado (la hoja de Ajustes).
//
// Se conecta con: servicio_conexion (arma las novedades) + la fila de
// burbujas y la pestaña Conexión.
// Parte del flujo: Ajustes → Conexión.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../modelos/usuario/dispositivo_conectado.dart';

/// De qué tipo es la novedad: cambia el texto que se muestra, no la cuenta.
enum TipoNovedadConexion {
  /// La prueba de 9 horas está disponible y sin arrancar.
  prueba,

  /// Un aparato declarado que todavía no se vinculó.
  aparatoPendiente,
}

/// Una novedad concreta de la conexión.
@immutable
class NovedadConexion {
  /// Identificador estable ('prueba' o el id del aparato): es lo que se
  /// guarda cuando el usuario ya la vio.
  final String id;

  final TipoNovedadConexion tipo;

  /// Nombre del aparato, solo para las de tipo [TipoNovedadConexion.aparatoPendiente].
  final String aparato;

  /// Tipo del aparato: es el respaldo cuando el nombre quedó vacío, así el
  /// aviso nunca muestra un hueco ("«» está sin vincular").
  final TipoDispositivo? tipoAparato;

  const NovedadConexion({
    required this.id,
    required this.tipo,
    this.aparato = '',
    this.tipoAparato,
  });
}

/// Cuántas novedades de Conexión siguen sin verse. Lo escribe la hoja de
/// Ajustes al abrirse y lo pinta el mininumerito de la burbuja.
final ValueNotifier<int> novedadesConexion = ValueNotifier<int>(0);
