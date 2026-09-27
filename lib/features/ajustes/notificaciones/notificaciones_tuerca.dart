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

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/plataforma/actualizacion/actualizacion_servicio.dart';
import '../../../core/servicios/conexion/novedades/conexion_novedades.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/formato/apariencia/base/apariencia_helper.dart';
import '../update/base/update_info.dart';
import '../update/base/update_service.dart';

/// Versión que YA se avisó por notificación. Sin esto el aviso de "hay una
/// versión nueva" volvería a aparecer en cada apertura de la app.
const _claveVersionAvisada = 'update_version_avisada';

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
    final info = await UpdateService().checkForUpdate();
    hayActualizacion.value = info != null;
    if (info != null) await _avisarVersionNueva(info);
  } catch (e) {
    debugPrint('[Tuerca] no se pudo ver si hay versión nueva: $e');
  }
  _recontar();
}

/// Avisa por la barra de notificaciones que hay una versión nueva, una sola vez
/// por versión, y de paso limpia los APKs de versiones viejas que hayan quedado
/// bajados.
///
/// Es best-effort de punta a punta: sin internet, sin permiso de
/// notificaciones o fuera de Android, no hace nada y la app sigue igual (el
/// numerito de la tuerca es el que avisa in-app).
Future<void> _avisarVersionNueva(UpdateInfo info) async {
  if (!ActualizacionServicio.soportado) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_claveVersionAvisada) == info.version) return;
    // El l10n sin árbol de widgets: la notificación la dibuja Android, así que
    // los textos se resuelven acá con el locale del sistema.
    final loc = await AppLocalizations.delegate.load(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    await ActualizacionServicio.enviarTextos(loc);
    await ActualizacionServicio.notificar(
      version: info.version,
      texto: loc.update.nuevaVersion(info.version),
    );
    await prefs.setString(_claveVersionAvisada, info.version);
    // Ya que estamos: los APKs de versiones anteriores no sirven más y solo
    // ocupan lugar (y confunden al instalador).
    await ActualizacionServicio.limpiarAntiguas(conservar: info.version);
  } catch (e) {
    debugPrint('[Tuerca] no se pudo avisar la versión nueva: $e');
  }
}

/// Suma lo de adentro de la app con la versión nueva.
void _recontar() {
  final premios = AparienciaHelper.regalos.value;
  hayPremio.value = premios > 0;
  notificacionesTuerca.value =
      premios + novedadesConexion.value + (hayActualizacion.value ? 1 : 0);
}
