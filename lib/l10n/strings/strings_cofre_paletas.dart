// ─────────────────────────────────────────────────────────────
// strings_cofre_paletas.dart — Textos del COFRE DE DISEÑOS de Ajustes →
// Apariencia → Barras: el título, el estado de cada diseño ("En uso",
// "Usar", cuántas horas faltan o con qué versión llega) y su nombre.
//
// Los nombres se resuelven por ID con un MAPA por idioma: el catálogo es
// puro (forma, color y condiciones) y el texto vive acá, así un idioma nuevo
// no obliga a tocar el modelo ni un switch.
//
// Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `cofre`) y el
// cofre de settings_sheet_appearance_barras_cofre.
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

class StringsCofrePaletas {
  /// Título del espacio.
  final String titulo;

  /// Ayuda corta: qué es el cofre.
  final String ayuda;

  /// Botón que abre el submodal del cofre.
  final String abrir;

  /// Botón que lo cierra.
  final String listo;

  /// Estado del diseño que ya está puesto en la barra.
  final String enUso;

  /// Acción de un diseño que ya se puede usar.
  final String usar;

  /// Cuando no queda ningún regalo por abrir.
  final String todoVisto;

  /// Encabezado de los regalos por abrir.
  final String regalosTitulo;

  /// Título de la sección de formas y adornos.
  final String seccionDisenos;

  /// Título de la sección de paletas de color.
  final String seccionColores;

  /// Nombre de cada diseño del catálogo, por id (ver
  /// catalogo_disenos_barra_lista). Un id que no esté cae a sí mismo.
  final Map<String, String> nombres;

  const StringsCofrePaletas({
    required this.titulo,
    required this.ayuda,
    required this.abrir,
    required this.listo,
    required this.enUso,
    required this.usar,
    required this.todoVisto,
    required this.regalosTitulo,
    required this.seccionDisenos,
    required this.seccionColores,
    required this.nombres,
  });

  /// "Tenés 2 regalos por abrir".
  String regalos(int n) =>
      n == 1 ? 'Tenés 1 regalo por abrir' : 'Tenés $n regalos por abrir';

  /// "Se abre con 50 h de escucha".
  String horas(int horas) => 'Se abre con $horas h de escucha';

  /// "Llega con la versión 0.9.23".
  String llegaConVersion(String version) => 'Llega con la versión $version';

  /// "Viene con la v1.0.0" — el regalo que ya trae la app.
  String vieneCon(String version) => 'Viene con la v$version';

  /// Nombre del diseño [id] (formas y paletas del catálogo).
  String nombre(String id) => nombres[id] ?? id;

  /// Textos en español (idioma primario).
  static const es = StringsCofrePaletas(
    titulo: 'Cofre de diseños',
    ayuda:
        'Formas (recto, pastilla, contorno) y paletas de color para el navbar y el miniplayer. Se abren con las horas que escuchás y con las actualizaciones de la app.',
    abrir: 'Abrir el cofre',
    listo: 'Listo',
    enUso: 'En uso',
    usar: 'Usar',
    todoVisto: 'Ya abriste todos los regalos disponibles.',
    regalosTitulo: 'Regalos',
    seccionDisenos: 'Diseños',
    seccionColores: 'Colores',
    nombres: {
      'esquinas_rectas': 'Recto',
      'muy_redondeada': 'Muy redondeado',
      'pastilla': 'Pastilla',
      'filosa': 'Filoso',
      'contorno_marcado': 'Contorno marcado',
      'sin_contorno': 'Sin contorno',
      'olas': 'Olas',
      'sticker_destello': 'Destello',
      'sticker_nota': 'Nota',
      'paleta_regalo_100': 'Vidrio de fábrica',
      'paleta_aurora': 'Aurora',
      'paleta_atardecer': 'Atardecer',
      'paleta_menta': 'Menta',
      'paleta_oceano': 'Océano',
      'paleta_oro': 'Oro',
      'paleta_rosa': 'Rosa',
      'paleta_nocturno': 'Nocturno',
      'paleta_fuego': 'Fuego',
    },
  );

  /// Textos en inglés.
  static const en = StringsCofrePaletas(
    titulo: 'Design chest',
    ayuda:
        'Shapes (square, pill, outline) and colour palettes for the navbar and the miniplayer. They open with the hours you listen and with app updates.',
    abrir: 'Open the chest',
    listo: 'Done',
    enUso: 'In use',
    usar: 'Use',
    todoVisto: 'You already opened every available gift.',
    regalosTitulo: 'Gifts',
    seccionDisenos: 'Designs',
    seccionColores: 'Colours',
    nombres: {
      'esquinas_rectas': 'Square',
      'muy_redondeada': 'Very rounded',
      'pastilla': 'Pill',
      'filosa': 'Sharp',
      'contorno_marcado': 'Bold outline',
      'sin_contorno': 'No outline',
      'olas': 'Waves',
      'sticker_destello': 'Sparkle',
      'sticker_nota': 'Note',
      'paleta_regalo_100': 'Factory glass',
      'paleta_aurora': 'Aurora',
      'paleta_atardecer': 'Sunset',
      'paleta_menta': 'Mint',
      'paleta_oceano': 'Ocean',
      'paleta_oro': 'Gold',
      'paleta_rosa': 'Pink',
      'paleta_nocturno': 'Nocturne',
      'paleta_fuego': 'Fire',
    },
  );
}
