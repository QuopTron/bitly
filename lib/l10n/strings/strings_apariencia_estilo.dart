// ─────────────────────────────────────────────────────────────
// strings_apariencia_estilo.dart — Textos del bloque "Estilo con cover" de
// Ajustes → Apariencia: el slider GENERAL de OPACIDAD, su modal de ayuda,
// la sección "Avanzado" con un control por componente y el selector de idioma.
//
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como
// `aparienciaEstilo`) y settings_sheet_appearance_style.dart.
// Parte del flujo: Ajustes → Apariencia (estilo e idioma).
// ─────────────────────────────────────────────────────────────

class StringsAparienciaEstilo {
  final String estiloTitulo;
  final String estiloAyuda;
  final String estiloGeneral;
  final String estiloInfoTitulo;
  final String estiloInfoTexto;
  final String estiloInfoCerrar;
  final String estiloPersonalizado;
  final String estiloVistaPrevia;
  final String estiloAvanzado;
  final String estiloAvanzadoAyuda;
  final String estiloRestablecer;
  final String compCancion;
  final String compCancionAyuda;
  final String compGrilla;
  final String compGrillaAyuda;
  final String compFondoPrincipal;
  final String compFondoPrincipalAyuda;
  final String compFondoReproductor;
  final String compFondoReproductorAyuda;
  final String compModals;
  final String compModalsAyuda;
  final String idiomaSelectorTitulo;
  final String idiomaEspanol;
  final String idiomaIngles;

  const StringsAparienciaEstilo({
    required this.estiloTitulo,
    required this.estiloAyuda,
    required this.estiloGeneral,
    required this.estiloInfoTitulo,
    required this.estiloInfoTexto,
    required this.estiloInfoCerrar,
    required this.estiloPersonalizado,
    required this.estiloVistaPrevia,
    required this.estiloAvanzado,
    required this.estiloAvanzadoAyuda,
    required this.estiloRestablecer,
    required this.compCancion,
    required this.compCancionAyuda,
    required this.compGrilla,
    required this.compGrillaAyuda,
    required this.compFondoPrincipal,
    required this.compFondoPrincipalAyuda,
    required this.compFondoReproductor,
    required this.compFondoReproductorAyuda,
    required this.compModals,
    required this.compModalsAyuda,
    required this.idiomaSelectorTitulo,
    required this.idiomaEspanol,
    required this.idiomaIngles,
  });

  /// Textos en español (idioma primario).
  static const es = StringsAparienciaEstilo(
    estiloTitulo: 'Estilo con cover',
    estiloAyuda: 'Cuánto del color de la carátula entra en la app.',
    estiloGeneral: 'Opacidad',
    estiloInfoTitulo: 'Qué hace la opacidad',
    estiloInfoTexto:
        'Sube o baja cuánto del color de cada carátula se pinta en la app.\n\n'
        'En 0% queda el diseño de siempre, sin color de carátula: es el punto '
        'de partida.\n\n'
        'Al subir, la carátula se sigue viendo y el color entra encima de a '
        'poco, así que en el medio tenés media carátula y medio color.\n\n'
        'Al 100% el color de la carátula pasa a ser el fondo principal.\n\n'
        'Los paneles de abajo muestran en vivo cómo queda el fondo, las cards '
        'y los modales. Con "Avanzado" podés mover cada zona por separado.',
    estiloInfoCerrar: 'Entendido',
    estiloPersonalizado: 'Personalizado',
    estiloVistaPrevia: 'Así se ve ahora',
    estiloAvanzado: 'Avanzado',
    estiloAvanzadoAyuda: 'Un control por zona, si querés afinar.',
    estiloRestablecer: 'Volver al diseño original',
    compCancion: 'Cards de canción',
    compCancionAyuda: 'Color del cover en cada track',
    compGrilla: 'Cards de grilla',
    compGrillaAyuda: 'Álbumes, playlists y artistas',
    compFondoPrincipal: 'Fondo principal',
    compFondoPrincipalAyuda: 'Cover desenfocado en el inicio',
    compFondoReproductor: 'Fondo del reproductor',
    compFondoReproductorAyuda: 'Cover desenfocado en el reproductor',
    compModals: 'Fondos de modales',
    compModalsAyuda: 'Ajustes, cola y letras',
    idiomaSelectorTitulo: 'Elegí el idioma',
    idiomaEspanol: 'Español',
    idiomaIngles: 'English',
  );

  /// Textos en inglés.
  static const en = StringsAparienciaEstilo(
    estiloTitulo: 'Cover style',
    estiloAyuda: 'How much of each cover\'s color goes into the app.',
    estiloGeneral: 'Opacity',
    estiloInfoTitulo: 'What opacity does',
    estiloInfoTexto:
        'Raises or lowers how much of each cover\'s color is painted across '
        'the app.\n\n'
        'At 0% you get the classic look, with no cover color at all: that is '
        'where you start.\n\n'
        'As you go up the cover stays visible and its color comes in on top, '
        'so halfway you have half cover and half color.\n\n'
        'At 100% the cover color becomes the main background.\n\n'
        'The panels below show it live for the background, the cards and the '
        'modals. With "Advanced" you can move each area separately.',
    estiloInfoCerrar: 'Got it',
    estiloPersonalizado: 'Customized',
    estiloVistaPrevia: 'Live preview',
    estiloAvanzado: 'Advanced',
    estiloAvanzadoAyuda: 'One control per area, if you want to fine-tune.',
    estiloRestablecer: 'Back to the original design',
    compCancion: 'Song cards',
    compCancionAyuda: 'Cover color on every track',
    compGrilla: 'Grid cards',
    compGrillaAyuda: 'Albums, playlists and artists',
    compFondoPrincipal: 'Main background',
    compFondoPrincipalAyuda: 'Blurred cover on home',
    compFondoReproductor: 'Player background',
    compFondoReproductorAyuda: 'Blurred cover in the player',
    compModals: 'Modal backgrounds',
    compModalsAyuda: 'Settings, queue and lyrics',
    idiomaSelectorTitulo: 'Choose your language',
    idiomaEspanol: 'Español',
    idiomaIngles: 'English',
  );
}
