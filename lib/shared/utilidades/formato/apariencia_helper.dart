// apariencia_helper.dart — Helper BASE de las preferencias de DISEÑO: leerlas
// desde cualquier widget y cambiarlas desde Ajustes. Evita que cada archivo
// importe el notifier + la caché.
//
// Los valores salen de `ValueNotifier<PreferenciasApariencia>` (registrado en
// la inyección y cargado al arrancar), así tocar un control en Ajustes
// repinta la app entera sin reiniciar.
//
// Lo que se ajusta se reparte en dos helpers, para que cada archivo haga una
// sola cosa: apariencia_espacios_helper.dart (cards y grillas) y
// apariencia_barras_helper.dart (navbar, miniplayer y las paletas del cofre).

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/cache/reproduccion/reproduccion_stats.dart';
import '../../../core/modelos/usuario/catalogo_disenos_barra_lista.dart';
import '../../../core/modelos/usuario/preferencias_apariencia.dart';

/// Acceso a las preferencias de diseño del usuario.
class AparienciaHelper {
  AparienciaHelper._();

  /// Preferencias actuales.
  static PreferenciasApariencia actual(BuildContext context) =>
      sl<ValueNotifier<PreferenciasApariencia>>().value;

  /// Notifier global (para escuchar cambios con ValueListenableBuilder).
  static ValueNotifier<PreferenciasApariencia> notifier() =>
      sl<ValueNotifier<PreferenciasApariencia>>();

  /// Cuántos REGALOS del cofre se pueden abrir ahora y todavía no se
  /// abrieron. Lo mantiene [refrescarRegalos] y lo pinta el mininumerito de
  /// Ajustes; vive acá para que la burbuja y el cofre nunca muestren números
  /// distintos.
  static final ValueNotifier<int> regalos = ValueNotifier<int>(0);

  /// Recalcula [regalos] leyendo las horas de escucha y la versión de la app.
  /// Es best-effort: si algo falla deja el número como estaba (nunca rompe la
  /// apertura de Ajustes).
  static Future<void> refrescarRegalos() async {
    try {
      final stats = await sl<ReproduccionStats>().getStatsUsuario();
      final pkg = await PackageInfo.fromPlatform();
      // Mismo dato que usan los niveles: el tiempo escuchado total.
      final horas = stats.totalTiempoReproducidoMs ~/ 3600000;
      final actuales = notifier().value.regalosVistos.toSet();
      regalos.value =
          regalosDisponibles(
            horas: horas,
            version: versionEnNumero(pkg.version),
            vistos: actuales,
          ).length;
    } catch (e) {
      debugPrint('[Apariencia] no se pudo contar los regalos: $e');
    }
  }

  /// Guarda las preferencias nuevas (repinta y persiste).
  static void cambiar(BuildContext context, PreferenciasApariencia prefs) {
    notifier().value = prefs;
    sl<CacheAjustes>().guardarPreferenciasApariencia(prefs);
  }

  /// Vuelve al diseño de fábrica.
  static void restablecer(BuildContext context) =>
      cambiar(context, PreferenciasApariencia.deFabrica);
}
