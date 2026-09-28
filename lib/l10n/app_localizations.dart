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
import 'strings/ajustes/base/strings_ajustes.dart';
import 'strings/conexion/sesiones/strings_conexion_google.dart';
import 'strings/reproduccion/descargas/strings_soulseek.dart';
import 'strings/sistema/datos/strings_cache.dart';
import 'strings/onboarding/base/strings_navegacion.dart';
import 'strings/reproduccion/base/strings_reproductor.dart';
import 'strings/sistema/app/strings_verificacion.dart';
import 'strings/sistema/app/strings_actualizacion.dart';
import 'strings/comun/strings_biblioteca.dart';
import 'strings/sistema/datos/strings_niveles.dart';
import 'strings/comun/strings_acciones.dart';
import 'strings/conexion/sesiones/strings_oauth.dart';
import 'strings/reproduccion/base/strings_servicio.dart';
import 'strings/comun/strings_fechas.dart';
import 'strings/sistema/app/strings_premium.dart';
import 'strings/ajustes/apariencia/strings_apariencia.dart';
import 'strings/ajustes/apariencia/strings_apariencia_estilo.dart';
import 'strings/ajustes/apariencia/strings_acciones_rapidas.dart';
import 'strings/ajustes/apariencia/strings_fuentes.dart';
import 'strings/ajustes/apariencia/strings_fuentes_idiomas.dart';
import 'strings/ajustes/apariencia/strings_vistas.dart';
import 'strings/ajustes/apariencia/strings_vistas_idiomas.dart';
import 'strings/ajustes/cofre/strings_cofre_paletas.dart';
import 'strings/ajustes/cofre/strings_cofre_paletas_idiomas.dart';
import 'strings/reproduccion/descargas/strings_descargas.dart';
import 'strings/reproduccion/base/strings_letras.dart';
import 'strings/sistema/info/strings_info_cancion.dart';
import 'strings/sistema/datos/strings_estadisticas.dart';
import 'strings/conexion/red/strings_red.dart';
import 'strings/onboarding/pasos/strings_splash.dart';
import 'strings/onboarding/base/strings_setup.dart';
import 'strings/onboarding/pasos/strings_tutorial.dart';
import 'strings/conexion/sesiones/strings_conexion.dart';
import 'strings/conexion/sesiones/strings_conexion_novedades.dart';
import 'strings/conexion/red/strings_conexion_red.dart';
import 'strings/conexion/red/strings_conexion_red_progreso.dart';
import 'strings/reproduccion/descargas/strings_rescate.dart';
import 'strings/reproduccion/descargas/strings_pool_qobuz.dart';
import 'strings/fiesta/strings_fiesta.dart';
import 'strings/onboarding/pasos/strings_tutorial_interactivo.dart';

// Los strings de setup/toda la app se reexportan: quien usa AppLocalizations
// puede tipar `StringsSetup` sin importar el archivo de strings a mano.
export 'strings/onboarding/base/strings_setup.dart';
// Los textos de Apariencia se exportan igual: la pestaña de diseño los tipa
// como StringsApariencia sin importar el archivo a mano.
export 'strings/ajustes/apariencia/strings_apariencia.dart';
// Los textos del estilo visual y los componentes se exportan igual.
export 'strings/ajustes/apariencia/strings_apariencia_estilo.dart';
// Y los de la burbuja de acciones rápidas (StringsAccionesRapidas).
export 'strings/ajustes/apariencia/strings_acciones_rapidas.dart';
// Y los del cofre de paletas (StringsCofrePaletas).
export 'strings/ajustes/cofre/strings_cofre_paletas.dart';
// Y los datos de sus dos idiomas (cofreEs / cofreEn).
export 'strings/ajustes/cofre/strings_cofre_paletas_idiomas.dart';
// Y los de la tipografía (StringsFuentes), con sus dos idiomas.
export 'strings/ajustes/apariencia/strings_fuentes.dart';
export 'strings/ajustes/apariencia/strings_fuentes_idiomas.dart';
// Y los del diseño por vista (StringsVistas), con sus dos idiomas.
export 'strings/ajustes/apariencia/strings_vistas.dart';
export 'strings/ajustes/apariencia/strings_vistas_idiomas.dart';
// Los textos del menú de Ajustes se exportan igual (StringsAjustes).
export 'strings/ajustes/base/strings_ajustes.dart';
// Los de la conexión con Google también (StringsConexionGoogle).
export 'strings/conexion/sesiones/strings_conexion_google.dart';
// Los de Soulseek también (StringsSoulseek).
export 'strings/reproduccion/descargas/strings_soulseek.dart';
// Los de la caché de streaming también (StringsCache).
export 'strings/sistema/datos/strings_cache.dart';
// Los de navegación y arranque también (StringsNavegacion).
export 'strings/onboarding/base/strings_navegacion.dart';
// Los del reproductor también (StringsReproductor).
export 'strings/reproduccion/base/strings_reproductor.dart';
// Los de verificación, actualización y biblioteca local también.
export 'strings/sistema/app/strings_verificacion.dart';
export 'strings/sistema/app/strings_actualizacion.dart';
export 'strings/comun/strings_biblioteca.dart';
// Los de los niveles de escucha también (StringsNiveles).
export 'strings/sistema/datos/strings_niveles.dart';
// Los de las acciones de ítem también (StringsAcciones).
export 'strings/comun/strings_acciones.dart';
// Los de OAuth, mensajes de servicio y fechas también.
export 'strings/conexion/sesiones/strings_oauth.dart';
export 'strings/reproduccion/base/strings_servicio.dart';
export 'strings/comun/strings_fechas.dart';
// Los de la validación premium también (StringsPremium).
export 'strings/sistema/app/strings_premium.dart';
// Los textos del karaoke (traducción) se exportan igual.
export 'strings/reproduccion/base/strings_letras.dart';
export 'strings/sistema/info/strings_info_cancion.dart';
// Los de la burbuja Conexión también (StringsConexion).
export 'strings/conexion/sesiones/strings_conexion.dart';
// Y los del aviso de novedades (StringsConexionNovedades).
export 'strings/conexion/sesiones/strings_conexion_novedades.dart';
// Y los del vínculo entre aparatos de la misma red (StringsConexionRed).
export 'strings/conexion/red/strings_conexion_red.dart';
// Y los del avance/cancelación del traspaso (StringsTraspaso).
export 'strings/conexion/red/strings_conexion_red_progreso.dart';
// Y los del modo fiesta (varios aparatos como un solo parlante).
export 'strings/fiesta/strings_fiesta.dart';
// Y los del rescate sin pérdida (StringsRescate).
export 'strings/reproduccion/descargas/strings_rescate.dart';
// Y los del estado del pool de Qobuz (StringsPoolQobuz).
export 'strings/reproduccion/descargas/strings_pool_qobuz.dart';

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
  late final StringsAccionesRapidas accionesRapidas;
  late final StringsInfoCancion infoCancion;
  late final StringsCofrePaletas cofre;
  late final StringsFuentes fuentes;
  late final StringsVistas vistas;
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
  late final StringsPoolQobuz poolQobuz;
  late final StringsFiesta fiesta;

  /// El bloque de textos se elige por idioma (es/en) en la inicialización.
  AppLocalizations(this.locale) {
    inicializarTextos(locale);
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();
}
