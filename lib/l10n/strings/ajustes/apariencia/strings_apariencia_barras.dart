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

  const StringsAparienciaBarras({
    required this.titulo,
    required this.ayuda,
    required this.navbar,
    required this.miniplayer,
    required this.esquinasArriba,
    required this.olas,
    required this.ayudaOlas,
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
  );
}
