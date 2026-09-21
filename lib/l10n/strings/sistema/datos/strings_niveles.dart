// ─────────────────────────────────────────────────────────────
// strings_niveles.dart — Textos de los niveles de escucha: la
// tarjeta, y los NOMBRES y PREMIOS de la escalera (13 niveles, en el
// mismo orden que niveles_escucha.dart). Español primario, inglés.
// Se conecta con: app_localizations.dart (lo expone como `niveles`) y
// settings_estadisticas_niveles / _nivel_chip.
// Parte del flujo: Ajustes → Estadísticas (niveles y recompensas).
// ─────────────────────────────────────────────────────────────

class StringsNiveles {
  final String titulo;
  final String premioOculto;
  final String escaleraCompleta;
  final String sinNivel;
  final List<String> nombres;
  final List<String> premios;
  final String _nivelActual;
  final String _faltan;

  const StringsNiveles({
    required this.titulo,
    required this.premioOculto,
    required this.escaleraCompleta,
    required this.sinNivel,
    required this.nombres,
    required this.premios,
    required String nivelActual,
    required String faltan,
  }) : _nivelActual = nivelActual,
       _faltan = faltan;

  /// Nombre del nivel en la posición [i].
  String nombre(int i) => nombres[i];

  /// Premio del nivel en la posición [i].
  String premio(int i) => premios[i];

  /// Línea "Nivel actual: ..." con el nombre del nivel.
  String nivelActual(String nombre) => _nivelActual.replaceFirst('{n}', nombre);

  /// Línea "Faltan X h para \"nombre\"".
  String faltan(String horas, String nombre) =>
      _faltan.replaceFirst('{h}', horas).replaceFirst('{n}', nombre);

  static const es = StringsNiveles(
    titulo: 'Niveles de escucha',
    premioOculto: 'Premio oculto',
    escaleraCompleta: 'Escalera completa: ya desbloqueaste todos los premios.',
    sinNivel: 'Todavía sin nivel — el primero llega a la hora de escucha',
    nombres: [
      'Primer tema',
      'Oyente',
      'De madrugada',
      'Coleccionista',
      'Curado',
      'Fiel',
      'Incansable',
      'Maestro de sesión',
      'Archivo vivo',
      'Un año sin parar',
      'Dos años',
      'Tres años',
      'Cuatro años non-stop',
    ],
    premios: [
      'Marco de perfil en tono del tema que más escuchaste',
      'Etiqueta "Oyente" junto a tu nombre al compartir',
      'Tema oscuro extra para el reproductor (medianoche)',
      'Cola de 200 temas en vez de 100',
      'Filtro "solo sin pérdida" en todas las búsquedas',
      'Tus 10 temas más escuchados en un álbum automático',
      'Descargas en paralelo dobles (más rápido)',
      'Etiqueta dorada en las tarjetas que compartís',
      'Respaldo de tu biblioteca en un archivo propio',
      'Insignia "365×24" y fondo animado exclusivo',
      'Tu historial completo exportable por año',
      'Tema visual completo hecho a mano (uno de tres)',
      'Insignia definitiva: "Escuchó cuatro años sin cortar"',
    ],
    nivelActual: 'Nivel actual: {n}',
    faltan: 'Faltan {h} h para "{n}"',
  );

  static const en = StringsNiveles(
    titulo: 'Listening levels',
    premioOculto: 'Hidden reward',
    escaleraCompleta: 'Full ladder: you have unlocked every reward.',
    sinNivel: 'No level yet — the first one arrives at one hour of listening',
    nombres: [
      'First track',
      'Listener',
      'After midnight',
      'Collector',
      'Curator',
      'Loyal',
      'Tireless',
      'Session master',
      'Living archive',
      'A year non-stop',
      'Two years',
      'Three years',
      'Four years non-stop',
    ],
    premios: [
      'Profile frame tinted with your most played track',
      '"Listener" tag next to your name when sharing',
      'Extra dark theme for the player (midnight)',
      'Queue of 200 tracks instead of 100',
      '"Lossless only" filter in every search',
      'Your 10 most played tracks in an automatic album',
      'Double parallel downloads (faster)',
      'Golden tag on the cards you share',
      'Backup of your library in its own file',
      '"365×24" badge and exclusive animated background',
      'Your full history exportable per year',
      'Full handmade visual theme (one of three)',
      'Ultimate badge: "Listened four years non-stop"',
    ],
    nivelActual: 'Current level: {n}',
    faltan: '{h} h left for "{n}"',
  );
}
