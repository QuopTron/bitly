// ─────────────────────────────────────────────────────────────
// strings_navegacion.dart — Textos de navegación y arranque: las
// pestañas de la Home (barra flotante y lateral) y el overlay de
// "Preparando fuentes". Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `nav`) y
// barra_navegacion_* / home_movil_overlay.
// Parte del flujo: Home (navegación entre secciones).
// ─────────────────────────────────────────────────────────────

class StringsNavegacion {
  final String buscar;
  final String inicio;
  final String miEspacio;
  final String preparando;
  final String preparandoAviso;
  final String continuar;

  const StringsNavegacion({
    required this.buscar,
    required this.inicio,
    required this.miEspacio,
    required this.preparando,
    required this.preparandoAviso,
    required this.continuar,
  });

  /// Etiquetas de las 3 pestañas, en el MISMO orden que las barras.
  List<String> get pestanas => [buscar, inicio, miEspacio];

  static const es = StringsNavegacion(
    buscar: 'Buscar',
    inicio: 'Inicio',
    miEspacio: 'Mi Espacio',
    preparando: 'Preparando tus fuentes de música…',
    preparandoAviso: 'Si una fuente pide verificación, se abrirá al usarla.',
    continuar: 'Continuar',
  );

  static const en = StringsNavegacion(
    buscar: 'Search',
    inicio: 'Home',
    miEspacio: 'My Space',
    preparando: 'Preparing your music sources…',
    preparandoAviso:
        'If a source asks for verification, it will open when used.',
    continuar: 'Continue',
  );
}
