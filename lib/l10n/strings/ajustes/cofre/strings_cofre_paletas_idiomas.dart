// ─────────────────────────────────────────────────────────────
// strings_cofre_paletas_idiomas.dart — Las dos instancias del cofre de
// diseños: español (primario) e inglés.
//
// Va aparte de strings_cofre_paletas.dart (que describe la clase) para que
// cada archivo siga chico: acá están los datos de los dos idiomas, incluidos
// los nombres de los diseños que son de un aparato (tv_*, pc_*, movil_*).
//
// Se conecta con: strings_cofre_paletas.dart (la clase) +
// app_localizations_inicializar.dart (elige una).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

import 'strings_cofre_paletas.dart';

/// Textos en español (idioma primario).
const cofreEs = StringsCofrePaletas(
  titulo: 'Cofre de diseños',
  ayuda:
      'Formas (recto, pastilla, contorno), adornos y paletas de color para el navbar y el miniplayer. Cada aparato tiene los suyos: la TV ofrece los de pantalla grande y el celular los del pulgar. Se abren con las horas que escuchás y con las actualizaciones.',
  abrir: 'Abrir el cofre',
  listo: 'Listo',
  enUso: 'En uso',
  usar: 'Usar',
  todoVisto: 'Ya abriste todos los regalos disponibles.',
  regalosTitulo: 'Regalos',
  seccionDisenos: 'Diseños',
  seccionColores: 'Colores',
  tplUnRegalo: 'Tenés 1 regalo por abrir',
  tplRegalos: 'Tenés %n regalos por abrir',
  tplHoras: 'Se abre con %n h de escucha',
  tplVersion: 'Llega con la versión %v',
  tplViene: 'Viene con la v%v',
  tplAparato: 'Diseños para tu %a',
  nombres: {
    // Formas y contornos (de todos los aparatos).
    'esquinas_rectas': 'Recto',
    'muy_redondeada': 'Muy redondeado',
    'pastilla': 'Pastilla',
    'filosa': 'Filoso',
    'contorno_marcado': 'Contorno marcado',
    'sin_contorno': 'Sin contorno',
    // Adornos.
    'olas': 'Olas',
    'sticker_destello': 'Destello',
    'sticker_nota': 'Nota',
    // De la TV.
    'tv_panel': 'Panel',
    'tv_marco': 'Marco',
    'tv_cine': 'Cine',
    // De la PC.
    'pc_fina': 'Fina',
    'pc_cristal': 'Cristal',
    'pc_neon': 'Neón',
    // Del celular.
    'movil_redonda': 'Redonda',
    'movil_pegada': 'Pegada',
    'movil_jade': 'Jade',
    // Colores de todos los aparatos.
    'paleta_regalo_100': 'Vidrio de fábrica',
    // Los cálidos de fábrica: los primeros que se pueden aplicar.
    'paleta_ambar': 'Ámbar',
    'paleta_terracota': 'Terracota',
    'paleta_aurora': 'Aurora',
    'paleta_atardecer': 'Atardecer',
    'paleta_menta': 'Menta',
    'paleta_oceano': 'Océano',
    'paleta_oro': 'Oro',
    'paleta_rosa': 'Rosa',
    'paleta_nocturno': 'Nocturno',
    'paleta_fuego': 'Fuego',
    'paleta_mandarina': 'Mandarina',
    'paleta_coral': 'Coral',
    'paleta_miel': 'Miel',
    'paleta_cobre': 'Cobre',
    'paleta_ocaso': 'Ocaso',
    'paleta_glaciar': 'Glaciar',
    'paleta_selva': 'Selva',
    'paleta_brasas': 'Brasas',
  },
);

/// Textos en inglés.
const cofreEn = StringsCofrePaletas(
  titulo: 'Design chest',
  ayuda:
      'Shapes (square, pill, outline), decorations and colour palettes for the navbar and the miniplayer. Every device has its own: the TV gets the big-screen ones and the phone the thumb ones. They open with the hours you listen and with app updates.',
  abrir: 'Open the chest',
  listo: 'Done',
  enUso: 'In use',
  usar: 'Use',
  todoVisto: 'You already opened every available gift.',
  regalosTitulo: 'Gifts',
  seccionDisenos: 'Designs',
  seccionColores: 'Colours',
  tplUnRegalo: 'You have 1 gift to open',
  tplRegalos: 'You have %n gifts to open',
  tplHoras: 'Opens with %n h of listening',
  tplVersion: 'Arrives with version %v',
  tplViene: 'Comes with v%v',
  tplAparato: 'Designs for your %a',
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
    'tv_panel': 'Panel',
    'tv_marco': 'Frame',
    'tv_cine': 'Cinema',
    'pc_fina': 'Slim',
    'pc_cristal': 'Glass',
    'pc_neon': 'Neon',
    'movil_redonda': 'Round',
    'movil_pegada': 'Flush',
    'movil_jade': 'Jade',
    'paleta_regalo_100': 'Factory glass',
    // Factory warm colours: the first ones that can be applied.
    'paleta_ambar': 'Amber',
    'paleta_terracota': 'Terracotta',
    'paleta_aurora': 'Aurora',
    'paleta_atardecer': 'Sunset',
    'paleta_menta': 'Mint',
    'paleta_oceano': 'Ocean',
    'paleta_oro': 'Gold',
    'paleta_rosa': 'Pink',
    'paleta_nocturno': 'Nocturne',
    'paleta_fuego': 'Fire',
    'paleta_mandarina': 'Tangerine',
    'paleta_coral': 'Coral',
    'paleta_miel': 'Honey',
    'paleta_cobre': 'Copper',
    'paleta_ocaso': 'Dusk',
    'paleta_glaciar': 'Glacier',
    'paleta_selva': 'Jungle',
    'paleta_brasas': 'Embers',
  },
);
