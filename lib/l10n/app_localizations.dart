// ─────────────────────────────────────────────────────────────
// app_localizations.dart — AppLocalizations: agrupa todos los strings
// localizados de la app (setup, splash, red, tutorial, ajustes...) y expone el
// acceso por contexto y la selección de idioma (es/en).
//
// Acá viven los CAMPOS y el acceso; la carga de cada bloque de textos está en
// app_localizations_inicializar.dart y el delegate de Flutter en
// app_localizations_delegate.dart (así este archivo no crece con cada idioma
// nuevo).
//
// Se conecta con: strings/ (todos los archivos de strings).
// Parte del flujo: presentación (textos de toda la app).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'strings/strings_ajustes.dart';
import 'strings/strings_conexion_google.dart';
import 'strings/strings_soulseek.dart';
import 'strings/strings_cache.dart';
import 'strings/strings_navegacion.dart';
import 'strings/strings_reproductor.dart';
import 'strings/strings_verificacion.dart';
import 'strings/strings_actualizacion.dart';
import 'strings/strings_biblioteca.dart';
import 'strings/strings_niveles.dart';
import 'strings/strings_acciones.dart';
import 'strings/strings_oauth.dart';
import 'strings/strings_servicio.dart';
import 'strings/strings_fechas.dart';
import 'strings/strings_premium.dart';
import 'strings/strings_apariencia.dart';
import 'strings/strings_apariencia_estilo.dart';
import 'strings/strings_cofre_paletas.dart';
import 'strings/strings_descargas.dart';
import 'strings/strings_letras.dart';
import 'strings/strings_estadisticas.dart';
import 'strings/strings_red.dart';
import 'strings/strings_splash.dart';
import 'strings/strings_setup.dart';
import 'strings/strings_tutorial.dart';
import 'strings/strings_conexion.dart';
import 'strings/strings_conexion_novedades.dart';
import 'strings/strings_conexion_red.dart';
import 'strings/strings_conexion_red_progreso.dart';
import 'strings/strings_rescate.dart';
import 'strings/strings_tutorial_interactivo.dart';

// Los strings de setup/toda la app se reexportan: quien usa AppLocalizations
// puede tipar `StringsSetup` sin importar el archivo de strings a mano.
export 'strings/strings_setup.dart';
// Los textos de Apariencia se exportan igual: la pestaña de diseño los tipa
// como StringsApariencia sin importar el archivo a mano.
export 'strings/strings_apariencia.dart';
// Los textos del estilo visual y los componentes se exportan igual.
export 'strings/strings_apariencia_estilo.dart';
// Y los del cofre de paletas (StringsCofrePaletas).
export 'strings/strings_cofre_paletas.dart';
// Los textos del menú de Ajustes se exportan igual (StringsAjustes).
export 'strings/strings_ajustes.dart';
// Los de la conexión con Google también (StringsConexionGoogle).
export 'strings/strings_conexion_google.dart';
// Los de Soulseek también (StringsSoulseek).
export 'strings/strings_soulseek.dart';
// Los de la caché de streaming también (StringsCache).
export 'strings/strings_cache.dart';
// Los de navegación y arranque también (StringsNavegacion).
export 'strings/strings_navegacion.dart';
// Los del reproductor también (StringsReproductor).
export 'strings/strings_reproductor.dart';
// Los de verificación, actualización y biblioteca local también.
export 'strings/strings_verificacion.dart';
export 'strings/strings_actualizacion.dart';
export 'strings/strings_biblioteca.dart';
// Los de los niveles de escucha también (StringsNiveles).
export 'strings/strings_niveles.dart';
// Los de las acciones de ítem también (StringsAcciones).
export 'strings/strings_acciones.dart';
// Los de OAuth, mensajes de servicio y fechas también.
export 'strings/strings_oauth.dart';
export 'strings/strings_servicio.dart';
export 'strings/strings_fechas.dart';
// Los de la validación premium también (StringsPremium).
export 'strings/strings_premium.dart';
// Los textos del karaoke (traducción) se exportan igual.
export 'strings/strings_letras.dart';
// Los de la burbuja Conexión también (StringsConexion).
export 'strings/strings_conexion.dart';
// Y los del aviso de novedades (StringsConexionNovedades).
export 'strings/strings_conexion_novedades.dart';
// Y los del vínculo entre aparatos de la misma red (StringsConexionRed).
export 'strings/strings_conexion_red.dart';
// Y los del avance/cancelación del traspaso (StringsTraspaso).
export 'strings/strings_conexion_red_progreso.dart';
// Y los del rescate sin pérdida (StringsRescate).
export 'strings/strings_rescate.dart';

part 'app_localizations_inicializar.dart';
part 'app_localizations_delegate.dart';

class AppLocalizations {
  final Locale locale;
  late final StringsSplash splash;
  late final StringsSetup setup;
  late final StringsTutorial tutorial;
  late final StringsTutorialInteractivo tutorialInteractivo;
  late final StringsRed red;
  late final StringsEstadisticas estadisticas;
  late final StringsDescargas descargas;
  late final StringsApariencia apariencia;
  late final StringsAparienciaEstilo aparienciaEstilo;
  late final StringsCofrePaletas cofre;
  late final StringsAjustes ajustes;
  late final StringsConexionGoogle google;
  late final StringsSoulseek soulseek;
  late final StringsCache cache;
  late final StringsNavegacion nav;
  late final StringsReproductor reproductor;
  late final StringsVerificacion verificacion;
  late final StringsActualizacion update;
  late final StringsBiblioteca biblioteca;
  late final StringsNiveles niveles;
  late final StringsAcciones acciones;
  late final StringsOAuth oauth;
  late final StringsServicio servicio;
  late final StringsFechas fechas;
  late final StringsPremium premium;
  late final StringsLetras letras;
  late final StringsConexion conexion;
  late final StringsConexionNovedades novedadesConexion;
  late final StringsConexionRed redConexion;
  late final StringsTraspaso traspasoConexion;
  late final StringsRescate rescate;

  /// El bloque de textos se elige por idioma (es/en) en la inicialización.
  AppLocalizations(this.locale) {
    inicializarTextos(locale);
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();
}
