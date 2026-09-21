// ─────────────────────────────────────────────────────────────
// strings_apariencia.dart — Textos de Ajustes → Apariencia: el
// bloque "Diseño" (separación de las cards/grillas y su redondeo,
// con la vista previa) y el tema/idioma.
//
// El espacio "Barras" tiene su archivo (strings_apariencia_barras.dart,
// acá dentro como `barras`) y el cofre de paletas el suyo
// (strings_cofre_paletas.dart, en AppLocalizations como `cofre`).
//
// Cada control trae su ayuda corta (una línea) para que se entienda sin
// adivinar. Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `apariencia`),
// settings_sheet_appearance_diseno.dart y settings_sheet_appearance_barras.
// Parte del flujo: Ajustes → Apariencia.
// ─────────────────────────────────────────────────────────────

import 'strings_apariencia_barras.dart';

export 'strings_apariencia_barras.dart';

class StringsApariencia {
  final String disenoTitulo;
  final String disenoAyuda;
  final String separacionTitulo;
  final String separacionAyuda;
  final String separacionX;
  final String separacionY;
  final String avanzadoTitulo;
  final String avanzadoAyuda;
  final String avanzadoCancion;
  final String avanzadoGrilla;
  final String personalizado;
  final String radioTitulo;
  final String radioAyuda;
  final String vistaPreviaTitulo;
  final String vistaPreviaAyuda;
  final String restablecer;
  final String temaAyuda;
  final String idiomaAyuda;

  /// Espacio "Barras": navbar y miniplayer (ver strings_apariencia_barras).
  final StringsAparienciaBarras barras;

  const StringsApariencia({
    required this.disenoTitulo,
    required this.disenoAyuda,
    required this.separacionTitulo,
    required this.separacionAyuda,
    required this.separacionX,
    required this.separacionY,
    required this.avanzadoTitulo,
    required this.avanzadoAyuda,
    required this.avanzadoCancion,
    required this.avanzadoGrilla,
    required this.personalizado,
    required this.radioTitulo,
    required this.radioAyuda,
    required this.vistaPreviaTitulo,
    required this.vistaPreviaAyuda,
    required this.restablecer,
    required this.temaAyuda,
    required this.idiomaAyuda,
    required this.barras,
  });

  /// Textos en español (idioma primario).
  static const es = StringsApariencia(
    disenoTitulo: 'Diseño',
    disenoAyuda:
        'El espacio entre las cards y sus esquinas, para que las grillas se vean como querés.',
    separacionTitulo: 'Separación',
    separacionAyuda:
        'Cuánto espacio hay entre las cards. En 0 se pegan (tipo Spotify) y queda una línea finita que las divide; en 1 se ven como vienen.',
    separacionX: 'Horizontal',
    separacionY: 'Vertical',
    avanzadoTitulo: 'Avanzado',
    avanzadoAyuda: 'Separá las cards de canción de las grillas para afinarlas.',
    avanzadoCancion: 'Cards de canción',
    avanzadoGrilla: 'Cards de grilla (álbum, playlist, artista)',
    personalizado: 'Personalizado',
    radioTitulo: 'Redondeo de las cards',
    radioAyuda:
        'Qué tan curvas son las esquinas de las cards. En 0 quedan cuadradas.',
    vistaPreviaTitulo: 'Cómo se ve',
    vistaPreviaAyuda: 'Se actualiza mientras movés los controles.',
    restablecer: 'Volver al diseño original',
    temaAyuda: 'El cambio se aplica al instante en todas las vistas.',
    idiomaAyuda: 'Elegí en qué idioma querés la app.',
    barras: StringsAparienciaBarras.es,
  );

  /// Textos en inglés.
  static const en = StringsApariencia(
    disenoTitulo: 'Design',
    disenoAyuda:
        'The space between cards and their corners, so grids look the way you want.',
    separacionTitulo: 'Spacing',
    separacionAyuda:
        'How much space sits between cards. At 0 they join Spotify-style with a thin line between them; at 1 they look like the app ships.',
    separacionX: 'Horizontal',
    separacionY: 'Vertical',
    avanzadoTitulo: 'Advanced',
    avanzadoAyuda: 'Split song cards from grid cards to fine-tune them.',
    avanzadoCancion: 'Song cards',
    avanzadoGrilla: 'Grid cards (album, playlist, artist)',
    personalizado: 'Custom',
    radioTitulo: 'Card roundness',
    radioAyuda: 'How round the card corners are. At 0 they become square.',
    vistaPreviaTitulo: 'Preview',
    vistaPreviaAyuda: 'Updates as you move the controls.',
    restablecer: 'Back to the original design',
    temaAyuda: 'It applies instantly across every view.',
    idiomaAyuda: 'Pick the language you want for the app.',
    barras: StringsAparienciaBarras.en,
  );
}
