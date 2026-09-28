// ─────────────────────────────────────────────────────────────
// strings_apariencia_barras.dart — Textos del espacio "Barras" de
// Ajustes → Apariencia: el navbar, el miniplayer y las esquinas de
// arriba que se les ajustan.
//
// El contorno ya no tiene textos acá: dejó de ser un selector aparte y
// pasó a ser parte de los DISEÑOS del cofre (strings_cofre_paletas).
//
// Va aparte de strings_apariencia.dart para que cada archivo de textos
// siga chico y haga una sola cosa (el espacio Barras tiene su propio
// vocabulario).
//
// Español primario, inglés secundario.
// Se conecta con: strings_apariencia.dart (lo expone como `apariencia.barras`).
// Parte del flujo: Ajustes → Apariencia → Barras.
// ─────────────────────────────────────────────────────────────

class StringsAparienciaBarras {
  /// Título del espacio.
  final String titulo;

  /// Ayuda corta del espacio.
  final String ayuda;

  /// Nombre de la barra de navegación.
  final String navbar;

  /// Nombre del miniplayer.
  final String miniplayer;

  /// Control de las esquinas de arriba.
  final String esquinasArriba;

  /// Nombre del control cuando la barra tiene el adorno de OLAS.
  final String olas;

  /// Ayuda de ese control: qué hace mover las olas.
  final String ayudaOlas;

  /// Rótulo del preset de TAMAÑO del miniplayer.
  final String tamano;

  /// Ayuda del tamaño: qué crece y qué no.
  final String ayudaTamano;

  /// Rótulo de la FORMA del miniplayer (cómo se apoya en el borde).
  final String forma;

  /// Ayuda de la forma.
  final String ayudaForma;

  /// Preset chico.
  final String compacto;

  /// Preset de siempre.
  final String normal;

  /// Preset grande.
  final String grande;

  /// Forma de siempre por aparato.
  final String formaAuto;

  /// Forma pegada al borde, sin márgenes.
  final String formaPegado;

  /// Forma de tarjeta con márgenes.
  final String formaFlotante;

  /// Rótulo del ancho máximo del miniplayer.
  final String ancho;

  /// Ayuda del ancho: por qué se acota.
  final String ayudaAncho;

  /// Ancho acotado sólo en pantallas enormes.
  final String anchoAuto;

  /// Ancho acotado siempre.
  final String anchoContenido;

  /// Ancho completo, sin tope.
  final String anchoCompleto;

  const StringsAparienciaBarras({
    required this.titulo,
    required this.ayuda,
    required this.navbar,
    required this.miniplayer,
    required this.esquinasArriba,
    required this.olas,
    required this.ayudaOlas,
    required this.tamano,
    required this.ayudaTamano,
    required this.forma,
    required this.ayudaForma,
    required this.compacto,
    required this.normal,
    required this.grande,
    required this.formaAuto,
    required this.formaPegado,
    required this.formaFlotante,
    required this.ancho,
    required this.ayudaAncho,
    required this.anchoAuto,
    required this.anchoContenido,
    required this.anchoCompleto,
  });

  /// Textos en español (idioma primario).
  static const es = StringsAparienciaBarras(
    titulo: 'Barras',
    ayuda:
        'Elegí si ajustás el navbar o el miniplayer, moveles las esquinas de arriba y abrí el cofre de diseños.',
    navbar: 'Navbar',
    miniplayer: 'Miniplayer',
    esquinasArriba: 'Esquinas de arriba',
    olas: 'Olas',
    ayudaOlas:
        'El borde de arriba ondula: movés el control para tener más o menos olas.',
    tamano: 'Tamaño',
    ayudaTamano:
        'Agranda la carátula y los botones del miniplayer. El nombre de la canción y los controles siempre tienen su lugar: en pantallas chicas el tamaño se ajusta solo.',
    forma: 'Cómo se apoya',
    ayudaForma:
        'Flotante deja la barra separada del borde como una tarjeta; pegada la pega al canto, que es lo cómodo en el celular.',
    compacto: 'Compacto',
    normal: 'Normal',
    grande: 'Grande',
    formaAuto: 'Automático',
    formaPegado: 'Pegado al borde',
    formaFlotante: 'Flotante',
    ancho: 'Ancho',
    ayudaAncho:
        'En una pantalla muy ancha la barra de lado a lado hace que el ojo viaje de un control al otro. Acotarla la deja centrada y cómoda.',
    anchoAuto: 'Automático',
    anchoContenido: 'Contenido',
    anchoCompleto: 'Ancho completo',
  );

  /// Textos en inglés.
  static const en = StringsAparienciaBarras(
    titulo: 'Bars',
    ayuda:
        'Choose whether you tweak the navbar or the miniplayer, move their top corners and open the design chest.',
    navbar: 'Navbar',
    miniplayer: 'Miniplayer',
    esquinasArriba: 'Top corners',
    olas: 'Waves',
    ayudaOlas:
        'The top edge ripples: move the control to get more or fewer waves.',
    tamano: 'Size',
    ayudaTamano:
        'Makes the miniplayer cover and buttons bigger. The song name and the controls always keep their room: on small screens the size adjusts itself.',
    forma: 'How it sits',
    ayudaForma:
        'Floating leaves the bar away from the edge like a card; attached glues it to the edge, which is the comfy one on a phone.',
    compacto: 'Compact',
    normal: 'Normal',
    grande: 'Large',
    formaAuto: 'Automatic',
    formaPegado: 'Attached',
    formaFlotante: 'Floating',
    ancho: 'Width',
    ayudaAncho:
        'On a very wide screen a bar that spans edge to edge makes your eye travel from one control to the other. Capping it keeps it centered and comfortable.',
    anchoAuto: 'Automatic',
    anchoContenido: 'Contained',
    anchoCompleto: 'Full width',
  );
}
