// ─────────────────────────────────────────────────────────────
// strings_fuentes_idiomas.dart — Las dos instancias de los textos de
// TIPOGRAFÍA: español (primario) e inglés.
//
// Va aparte de strings_fuentes.dart (que describe la clase) para que cada
// archivo siga chico. Los nombres de las tipografías se repiten en los dos
// idiomas a propósito: son nombres propios y no se traducen.
//
// Se conecta con: strings_fuentes.dart (la clase) +
// app_localizations_inicializar.dart (elige una).
// Parte del flujo: Ajustes → Apariencia → Tipografía.
// ─────────────────────────────────────────────────────────────

import 'strings_fuentes.dart';

/// Nombres del catálogo, iguales en los dos idiomas.
const _nombres = <String, String>{
  'google_sans': 'Google Sans Flex',
  'inter': 'Inter',
  'manrope': 'Manrope',
  'rubik': 'Rubik',
  'space_grotesk': 'Space Grotesk',
  'jetbrains_mono': 'JetBrains Mono',
  'nunito': 'Nunito',
};

/// Textos en español (idioma primario).
const fuentesEs = StringsFuentes(
  titulo: 'Tipografía',
  ayuda:
      'Con qué letra se escribe toda la app. Google Sans Flex viene con la app y funciona sin internet; las demás se bajan una vez y quedan guardadas. Se abren con las horas que escuchás y con las actualizaciones.',
  enUso: 'En uso',
  usar: 'Usar',
  descargando: 'Bajando…',
  previaTitulo: 'Así se ve',
  previaTexto: 'Bitly — escuchá tu música',
  sinRed: 'No se pudo bajar. Seguís con la de la app.',
  reintentar: 'Reintentar',
  liberar: 'Borrar las tipografías bajadas',
  liberado: 'Listo: se borraron las tipografías bajadas.',
  nombres: _nombres,
  tplHoras: 'Se abre con %n h de escucha',
  tplVersion: 'Llega con la versión %v',
);

/// Textos en inglés.
const fuentesEn = StringsFuentes(
  titulo: 'Typography',
  ayuda:
      'The typeface the whole app is written in. Google Sans Flex ships with the app and works offline; the rest download once and stay on disk. They open with your listening hours and with updates.',
  enUso: 'In use',
  usar: 'Use',
  descargando: 'Downloading…',
  previaTitulo: 'Looks like this',
  previaTexto: 'Bitly — listen to your music',
  sinRed: 'Could not download. You are staying on the app one.',
  reintentar: 'Try again',
  liberar: 'Delete downloaded typefaces',
  liberado: 'Done: downloaded typefaces were deleted.',
  nombres: _nombres,
  tplHoras: 'Opens with %n h of listening',
  tplVersion: 'Arrives with version %v',
);
