// ─────────────────────────────────────────────────────────────
// notificaciones_tuerca.dart — El mininumerito de la TUERCA (el acceso a
// Ajustes): cuántas cosas hay para ver y de qué tipo son.
//
// Junta en un solo número lo que vive repartido por la app:
//   · los REGALOS del cofre de diseños (Apariencia),
//   · las NOVEDADES de Conexión (la prueba de 9 h y los aparatos sin vincular),
//   · y la ACTUALIZACIÓN de la app, si hay una más nueva.
//
// Además deja saber QUÉ tipo hay ([hayPremio] / [hayActualizacion]): así la
// tuerca puede avisar con el color del premio o con el de la versión, en vez
// de un número sin explicación.
//
// Es best-effort: si la consulta de versión falla (sin internet, por
// ejemplo), el número sale igual con lo que hay adentro de la app.
//
// Se conecta con: apariencia_helper (regalos) + conexion_novedades +
// update_service + la tuerca del perfil.
// Parte del flujo: Mi Espacio → tuerca → Ajustes.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../../core/servicios/conexion/novedades/conexion_novedades.dart';
import '../../../shared/utilidades/formato/apariencia/base/apariencia_helper.dart';
import '../update/base/update_service.dart';

/// Cuántas cosas hay sin ver (el número del mininumerito).
final ValueNotifier<int> notificacionesTuerca = ValueNotifier<int>(0);

/// Hay un PREMIO esperando (un regalo del cofre): el aviso va con su color.
final ValueNotifier<bool> hayPremio = ValueNotifier<bool>(false);

/// Hay una VERSIÓN nueva de la app para bajar.
final ValueNotifier<bool> hayActualizacion = ValueNotifier<bool>(false);

var _enganchado = false;

/// Recalcula el número. Se llama al abrir la app y cada vez que cambian los
/// regalos o las novedades de Conexión (los escucha una sola vez).
Future<void> refrescarNotificacionesTuerca() async {
  if (!_enganchado) {
    _enganchado = true;
    AparienciaHelper.regalos.addListener(_recontar);
    novedadesConexion.addListener(_recontar);
  }
  try {
    hayActualizacion.value = await UpdateService().checkForUpdate() != null;
  } catch (e) {
    debugPrint('[Tuerca] no se pudo ver si hay versión nueva: $e');
  }
  _recontar();
}

/// Suma lo de adentro de la app con la versión nueva.
void _recontar() {
  final premios = AparienciaHelper.regalos.value;
  hayPremio.value = premios > 0;
  notificacionesTuerca.value =
      premios + novedadesConexion.value + (hayActualizacion.value ? 1 : 0);
}
