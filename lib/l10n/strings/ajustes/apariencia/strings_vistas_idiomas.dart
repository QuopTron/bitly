// ─────────────────────────────────────────────────────────────
// strings_vistas_idiomas.dart — Las dos instancias de los textos de DISEÑO POR
// VISTA: español (primario) e inglés.
//
// Va aparte de strings_vistas.dart (que describe la clase) para que cada
// archivo siga chico.
//
// Se conecta con: strings_vistas.dart (la clase) +
// app_localizations_inicializar.dart (elige una).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

import 'strings_vistas.dart';

/// Textos en español (idioma primario).
const vistasEs = StringsVistas(
  titulo: 'Diseño por vista',
  ayuda:
      'Cada pantalla puede verse distinto: elegí una y cambiale la letra, el color de sus tarjetas, el redondeo o cuánto aire tiene. Lo que no toques lo hereda del estilo de arriba, así que la app nunca queda desarmada.',
  heredar: 'Heredar',
  heredado: 'Heredado',
  propio: 'Propio',
  restablecer: 'Restablecer esta vista',
  restablecida: 'Listo: esta vista volvió al diseño general.',
  sinCambios: 'Esta vista todavía no tiene nada propio: se ve como el resto.',
  tipografia: 'Tipografía',
  radio: 'Redondeo de las tarjetas',
  densidad: 'Aire entre las cosas',
  columnas: 'Columnas de la grilla',
  ejeColor: 'Color',
  ejeLetra: 'Letra',
  ejeForma: 'Forma',
  ejeAire: 'Aire',
  ejeGrilla: 'Grilla',
  cofre: 'Color de las tarjetas',
  cofreAyuda:
      'Las tarjetas de ESTA pantalla se tiñen con esta paleta. Las de las demás no se tocan.',
  cofreCover: 'El cover',
  automatico: 'Automático',
  bajandoTipografia: 'Bajando la tipografía de esta vista…',
  sinTipografia: 'No se pudo bajar esa tipografía: esta vista usa la de la app.',
  nombres: _nombres,
  tplTocadas: 'Pantallas con diseño propio: %n',
);

/// Textos en inglés.
const vistasEn = StringsVistas(
  titulo: 'Design per screen',
  ayuda:
      'Every screen can look different: pick one and change its typeface, the colour of its cards, how rounded they are or how much air it has. Whatever you leave alone is inherited from the style above, so the app never falls apart.',
  heredar: 'Inherit',
  heredado: 'Inherited',
  propio: 'Custom',
  restablecer: 'Reset this screen',
  restablecida: 'Done: this screen is back to the general design.',
  sinCambios: 'This screen has nothing of its own yet: it looks like the rest.',
  tipografia: 'Typography',
  radio: 'Card rounding',
  densidad: 'Air between things',
  columnas: 'Grid columns',
  ejeColor: 'Colour',
  ejeLetra: 'Type',
  ejeForma: 'Shape',
  ejeAire: 'Air',
  ejeGrilla: 'Grid',
  cofre: 'Card colour',
  cofreAyuda:
      'The cards on THIS screen are tinted with this palette. The ones on other screens are left alone.',
  cofreCover: 'The cover',
  automatico: 'Automatic',
  bajandoTipografia: 'Downloading this screen typeface…',
  sinTipografia: 'That typeface could not be downloaded: this screen uses the app one.',
  nombres: _nombres,
  tplTocadas: 'Screens with their own design: %n',
);

/// Nombres de las vistas, iguales en los dos idiomas (son pantallas, no texto
/// genérico): la clave es la de VistaApp.
const _nombres = <String, String>{
  'feed': 'Inicio',
  'busqueda': 'Búsqueda',
  'mi_espacio': 'Mi Espacio',
  'detalle': 'Detalle',
  'reproductor': 'Reproductor',
  'ajustes': 'Ajustes',
  'tutorial': 'Tutorial',
};
