// ─────────────────────────────────────────────────────────────
// strings_acciones_rapidas.dart — Textos de la burbuja "Acciones
// rápidas" (Ajustes → Apariencia): qué gesto llama a qué acción en las
// tarjetas de canción, y el aviso que confirma cada gesto.
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como
// `accionesRapidas`) + tarjeta_acciones_rapidas.dart + el gesto de
// tarjeta_track_deslizar.dart.
// Parte del flujo: Ajustes → Apariencia → acciones rápidas.
// ─────────────────────────────────────────────────────────────

class StringsAccionesRapidas {
  final String titulo;
  final String ayuda;
  final String gestoDerecha;
  final String gestoIzquierda;
  final String gestoArriba;
  final String gestoAbajo;
  final String gestoDobleToque;
  final String ayudaVertical;
  final String ninguna;
  final String agregarCola;
  final String meGusta;
  final String descargar;
  final String compartir;
  final String info;
  final String irAlbum;
  final String quitarMiEspacio;
  final String _agregadoACola;
  final String _quitadoDeMiEspacio;
  final String _accionNoDisponible;

  const StringsAccionesRapidas({
    required this.titulo,
    required this.ayuda,
    required this.gestoDerecha,
    required this.gestoIzquierda,
    required this.gestoArriba,
    required this.gestoAbajo,
    required this.gestoDobleToque,
    required this.ayudaVertical,
    required this.ninguna,
    required this.agregarCola,
    required this.meGusta,
    required this.descargar,
    required this.compartir,
    required this.info,
    required this.irAlbum,
    required this.quitarMiEspacio,
    required String agregadoACola,
    required String quitadoDeMiEspacio,
    required String accionNoDisponible,
  }) : _agregadoACola = agregadoACola,
       _quitadoDeMiEspacio = quitadoDeMiEspacio,
       _accionNoDisponible = accionNoDisponible;

  /// Aviso "Agregado a la cola · `nombre`".
  String agregadoACola(String cancion) =>
      _agregadoACola.replaceFirst('{cancion}', cancion);

  /// Aviso "Quitado de Mi Espacio · `nombre`".
  String quitadoDeMiEspacio(String cancion) =>
      _quitadoDeMiEspacio.replaceFirst('{cancion}', cancion);

  /// Aviso cuando el gesto pide algo que esta tarjeta no puede hacer (por
  /// ejemplo "quitar de Mi Espacio" en un resultado de búsqueda).
  String get accionNoDisponible => _accionNoDisponible;

  static const es = StringsAccionesRapidas(
    titulo: 'Acciones rápidas',
    ayuda:
        'Elegí qué hace cada gesto sobre una canción, sin abrir el menú de '
        'los tres puntos. Con "Nada" el gesto queda sin efecto. Ojo: activar '
        'los dos toques retrasa un poco el toque simple de la tarjeta.',
    gestoDerecha: 'Deslizar a la derecha',
    gestoIzquierda: 'Deslizar a la izquierda',
    gestoArriba: 'Deslizar hacia arriba',
    gestoAbajo: 'Deslizar hacia abajo',
    gestoDobleToque: 'Dos toques',
    ayudaVertical:
        'Los gestos de arriba y abajo son un movimiento rápido (un tirón): la '
        'lista se sigue desplazando normal, así que hacelo corto y ligero. Si '
        'no los usás, dejalos en "Nada".',
    ninguna: 'Nada',
    agregarCola: 'Agregar a la cola',
    meGusta: 'Me gusta',
    descargar: 'Descargar',
    compartir: 'Compartir',
    info: 'Información',
    irAlbum: 'Ir al álbum',
    quitarMiEspacio: 'Quitar de Mi Espacio',
    agregadoACola: 'Agregado a la cola · {cancion}',
    quitadoDeMiEspacio: 'Quitado de Mi Espacio · {cancion}',
    accionNoDisponible: 'Esta tarjeta no puede hacer esa acción',
  );

  static const en = StringsAccionesRapidas(
    titulo: 'Quick actions',
    ayuda:
        'Pick what each gesture does on a song, without opening the three-dot '
        'menu. With "None" the gesture does nothing. Careful: turning on '
        'double tap delays the plain tap on the card a little.',
    gestoDerecha: 'Swipe right',
    gestoIzquierda: 'Swipe left',
    gestoArriba: 'Swipe up',
    gestoAbajo: 'Swipe down',
    gestoDobleToque: 'Double tap',
    ayudaVertical:
        'Up and down gestures are a quick flick: the list still scrolls as '
        'usual, so keep it short and light. If you do not use them, leave '
        'them as "None".',
    ninguna: 'None',
    agregarCola: 'Add to queue',
    meGusta: 'Like',
    descargar: 'Download',
    compartir: 'Share',
    info: 'Information',
    irAlbum: 'Go to album',
    quitarMiEspacio: 'Remove from My Space',
    agregadoACola: 'Added to queue · {cancion}',
    quitadoDeMiEspacio: 'Removed from My Space · {cancion}',
    accionNoDisponible: 'This card cannot do that action',
  );
}
