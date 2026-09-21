// ─────────────────────────────────────────────────────────────
// app_localizations_inicializar.dart — PART de app_localizations.dart: elige
// el bloque de textos (es/en) de cada área de la app.
//
// Va aparte porque es la parte que CRECE: cada área nueva suma una línea acá y
// ninguna en el archivo principal. Es una extensión (misma library), así que
// puede llenar los `late final` de AppLocalizations sin exponerlos.
//
// Se conecta con: app_localizations.dart (la clase) + strings/.
// Parte del flujo: presentación (textos de toda la app).
// ─────────────────────────────────────────────────────────────

part of 'app_localizations.dart';

/// Carga de textos por idioma.
extension InicializacionTextos on AppLocalizations {
  /// Llena cada área con su bloque en el idioma de [locale] (es por defecto).
  void inicializarTextos(Locale locale) {
    final isEn = locale.languageCode == 'en';
    splash = isEn ? StringsSplash.en : StringsSplash.es;
    setup = isEn ? StringsSetup.en : StringsSetup.es;
    tutorial = isEn ? StringsTutorial.en : StringsTutorial.es;
    tutorialInteractivo =
        isEn ? StringsTutorialInteractivo.en : StringsTutorialInteractivo.es;
    red = isEn ? StringsRed.en : StringsRed.es;
    estadisticas = isEn ? StringsEstadisticas.en : StringsEstadisticas.es;
    descargas = isEn ? StringsDescargas.en : StringsDescargas.es;
    apariencia = isEn ? StringsApariencia.en : StringsApariencia.es;
    aparienciaEstilo =
        isEn ? StringsAparienciaEstilo.en : StringsAparienciaEstilo.es;
    cofre = isEn ? StringsCofrePaletas.en : StringsCofrePaletas.es;
    ajustes = isEn ? StringsAjustes.en : StringsAjustes.es;
    google = isEn ? StringsConexionGoogle.en : StringsConexionGoogle.es;
    soulseek = isEn ? StringsSoulseek.en : StringsSoulseek.es;
    cache = isEn ? StringsCache.en : StringsCache.es;
    nav = isEn ? StringsNavegacion.en : StringsNavegacion.es;
    reproductor = isEn ? StringsReproductor.en : StringsReproductor.es;
    verificacion = isEn ? StringsVerificacion.en : StringsVerificacion.es;
    update = isEn ? StringsActualizacion.en : StringsActualizacion.es;
    biblioteca = isEn ? StringsBiblioteca.en : StringsBiblioteca.es;
    niveles = isEn ? StringsNiveles.en : StringsNiveles.es;
    acciones = isEn ? StringsAcciones.en : StringsAcciones.es;
    oauth = isEn ? StringsOAuth.en : StringsOAuth.es;
    servicio = isEn ? StringsServicio.en : StringsServicio.es;
    fechas = isEn ? StringsFechas.en : StringsFechas.es;
    premium = isEn ? StringsPremium.en : StringsPremium.es;
    letras = isEn ? StringsLetras.en : StringsLetras.es;
    conexion = isEn ? StringsConexion.en : StringsConexion.es;
    novedadesConexion =
        isEn ? StringsConexionNovedades.en : StringsConexionNovedades.es;
    redConexion = isEn ? StringsConexionRed.en : StringsConexionRed.es;
    traspasoConexion = isEn ? StringsTraspaso.en : StringsTraspaso.es;
    rescate = isEn ? StringsRescate.en : StringsRescate.es;
  }
}
