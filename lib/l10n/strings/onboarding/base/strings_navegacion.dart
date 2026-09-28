// ─────────────────────────────────────────────────────────────
// strings_navegacion.dart — Textos de navegación de la Home: las
// pestañas de la barra flotante (celular) y de la lateral (PC).
// Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `nav`) y
// barra_navegacion_flotante / barra_navegacion_lateral.
// Parte del flujo: Home (navegación entre secciones).
//
// (Acá vivían `preparando` y `preparandoAviso`, el aviso del overlay
// "Preparando tus fuentes…": ese overlay nunca llegaba a verse —nadie pasaba
// `preparando: true`— y se borró junto con sus textos.)
// ─────────────────────────────────────────────────────────────

class StringsNavegacion {
  final String buscar;
  final String inicio;
  final String miEspacio;
  final String continuar;

  const StringsNavegacion({
    required this.buscar,
    required this.inicio,
    required this.miEspacio,
    required this.continuar,
  });

  /// Etiquetas de las 3 pestañas, en el MISMO orden que las barras.
  List<String> get pestanas => [buscar, inicio, miEspacio];

  static const es = StringsNavegacion(
    buscar: 'Buscar',
    inicio: 'Inicio',
    miEspacio: 'Mi Espacio',
    continuar: 'Continuar',
  );

  static const en = StringsNavegacion(
    buscar: 'Search',
    inicio: 'Home',
    miEspacio: 'My Space',
    continuar: 'Continue',
  );
}
