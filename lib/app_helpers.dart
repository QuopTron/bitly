// ─────────────────────────────────────────────────────────────
// app_helpers.dart — Soporte de la app raíz (BitlyApp): agrupa los
// notificadores globales de ajustes (idioma, tema, estilo y
// preferencias), carga los ajustes guardados y reproduce los
// enlaces/deep links ya resueltos.
// Se conecta con: app.dart + inyeccion + cache_ajustes +
// servicio_enlaces + cubit_cola + router.
// Parte del flujo: arranque + llegada de enlaces compartidos.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/inyeccion.dart' as di;
import 'core/cache/almacenes/cache_ajustes.dart';
import 'core/modelos/resultado_enlace.dart';
import 'core/servicios/compartir/datos_compartido.dart';
import 'core/servicios/compartir/servicio_compartir.dart';
import 'core/modelos/usuario/estilo_visual.dart';
import 'core/modelos/usuario/preferencias_estilo.dart';
import 'core/plataforma/sistema/servicio_deep_link.dart';
import 'core/servicios/proveedores/servicio_enlaces.dart';
import 'estado/cola/cubit_cola.dart';
import 'router/route_names.dart';

part 'app_helpers_compartido.dart';

/// Agrupa los notificadores globales de ajustes resueltos desde el inyector,
/// con el alta y baja de listeners en un solo lugar.
class NotificadoresAjustesApp {
  NotificadoresAjustesApp()
      : locale = di.sl<ValueNotifier<Locale>>(),
        themeMode = di.sl<ValueNotifier<ThemeMode>>(),
        estiloVisual = di.sl<ValueNotifier<EstiloVisual>>(),
        preferenciasEstilo = di.sl<ValueNotifier<PreferenciasEstilo>>();

  final ValueNotifier<Locale> locale;
  final ValueNotifier<ThemeMode> themeMode;
  final ValueNotifier<EstiloVisual> estiloVisual;
  final ValueNotifier<PreferenciasEstilo> preferenciasEstilo;

  Iterable<Listenable> get _todos =>
      [locale, themeMode, estiloVisual, preferenciasEstilo];

  /// Registra el mismo callback en los cuatro notificadores.
  void suscribir(VoidCallback onCambio) {
    for (final n in _todos) {
      n.addListener(onCambio);
    }
  }

  /// Quita el callback de los cuatro notificadores.
  void liberar(VoidCallback onCambio) {
    for (final n in _todos) {
      n.removeListener(onCambio);
    }
  }
}

/// Carga tema/idioma/estilo/preferencias guardados y actualiza los notificadores.
Future<void> cargarAjustesGuardadosApp({
  required NotificadoresAjustesApp ajustes,
  required bool Function() estaMontado,
}) async {
  try {
    final cache = di.sl<CacheAjustes>();
    final temaGuardado = await cache.getAjuste('theme_mode');
    if (temaGuardado != null && estaMontado()) {
      ajustes.themeMode.value =
          temaGuardado == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
    final localeGuardado = await cache.getAjuste('locale');
    if (localeGuardado != null && estaMontado()) {
      ajustes.locale.value = Locale(localeGuardado);
    }
    final estiloGuardado = await cache.getEstiloVisual();
    if (estiloGuardado != null && estaMontado()) {
      ajustes.estiloVisual.value = EstiloVisualExt.desdeClave(estiloGuardado);
    }
    final prefsGuardadas = await cache.getPreferenciasEstilo();
    if (estaMontado()) ajustes.preferenciasEstilo.value = prefsGuardadas;
  } catch (e) {
    debugPrint("[App] $e");
  }
}

/// Reproduce un enlace ya resuelto: encola sus tracks y, si el usuario no está
/// en una pantalla de arranque, lo lleva al home para ver el miniplayer.
///
/// El `go` va SOLO si no estamos ya en el home: Buscar, Inicio y Mi Espacio
/// viven DENTRO de `/home` (el miniplayer es un slot del shell, se ve en las
/// tres), así que navegar cuando ya estamos ahí no aportaba nada y sí podía
/// tirar abajo lo que el usuario tenía abierto encima (detalle, reproductor).
///
/// Todo el cuerpo va protegido: esto corre desde el listener de enlaces
/// (evento asíncrono de la raíz), así que una excepción acá se perdería como
/// error no manejado y podía dejar la carta abierta o el router a medio
/// navegar (la app parecía trabada). Si algo falla, se cierra la carta igual.
void reproducirEnlaceApp({
  required ResultadoEnlace resuelto,
  required GoRouter router,
  required VoidCallback limpiarLink,
}) {
  limpiarLink();
  try {
    di.sl<CubitCola>().reproducirConContexto(
      resuelto.paraReproducir,
      resuelto.item,
    );
  } catch (e) {
    debugPrint('[Enlaces] no se pudo encolar el compartido: $e');
    return;
  }
  String ruta;
  try {
    ruta = router.routerDelegate.currentConfiguration.uri.path;
  } catch (_) {
    // Router todavía sin resolver (arranque): la cola ya quedó cargada y el
    // miniplayer aparece solo cuando el home se monte.
    return;
  }
  final enArranque =
      ruta.isEmpty || ruta == RouteNames.splash.path || ruta == RouteNames.setup.path;
  if (enArranque || ruta == RouteNames.home.path) return;
  try {
    router.go(RouteNames.home.path);
  } catch (e) {
    debugPrint('[Enlaces] no se pudo ir al home: $e');
  }
}

