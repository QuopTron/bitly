// ─────────────────────────────────────────────────────────────
// strings_info_cancion.dart — Textos del modal de información de
// canción: etiquetas de las filas (título, artista, álbum, duración,
// tipo, lanzamiento, ISRC y origen), el encabezado y la traducción de
// esos DATOS.
//
// Las etiquetas salen de acá (l10n normal, viajan en el APK). Los
// VALORES son datos del proveedor y no se pueden empaquetar, así que se
// piden al traductor sólo si el usuario lo pide (ver
// servicio_traduccion_texto.dart).
//
// Los idiomas destino NO se repiten acá: se reusa `loc.letras.idiomas`,
// que ya está localizado y es exactamente la misma lista.
// Se conecta con: app_localizations.dart (lo expone como `infoCancion`)
// y shared/widgets/modales/info_cancion/.
// Parte del flujo: acciones de ítem (info) → canción / artista / álbum.
// ─────────────────────────────────────────────────────────────

class StringsInfoCancion {
  final String titulo;
  final String campoCancion;
  final String campoArtista;
  final String campoAlbum;
  final String campoDuracion;
  final String campoLanzamiento;
  final String campoIsrc;
  final String campoOrigen;
  final String traduciendo;
  final String traduccionError;
  final String traduccionTitulo;
  final String traduccionAyuda;
  final String traduccionDetectado;
  final String traduccionOcultar;

  const StringsInfoCancion({
    required this.titulo,
    required this.campoCancion,
    required this.campoArtista,
    required this.campoAlbum,
    required this.campoDuracion,
    required this.campoLanzamiento,
    required this.campoIsrc,
    required this.campoOrigen,
    required this.traduciendo,
    required this.traduccionError,
    required this.traduccionTitulo,
    required this.traduccionAyuda,
    required this.traduccionDetectado,
    required this.traduccionOcultar,
  });

  static const es = StringsInfoCancion(
    titulo: 'Información',
    campoCancion: 'Canción',
    campoArtista: 'Artista',
    campoAlbum: 'Álbum',
    campoDuracion: 'Duración',
    campoLanzamiento: 'Lanzamiento',
    campoIsrc: 'ISRC',
    campoOrigen: 'Origen',
    traduciendo: 'Traduciendo…',
    traduccionError: 'No se pudo traducir',
    traduccionTitulo: 'Traducir datos',
    traduccionAyuda:
        'Traduce el nombre de la canción, el artista y el álbum. Las fechas y '
        'los códigos nunca se traducen.',
    traduccionDetectado: 'Idioma detectado:',
    traduccionOcultar: 'Ver original',
  );

  static const en = StringsInfoCancion(
    titulo: 'Information',
    campoCancion: 'Song',
    campoArtista: 'Artist',
    campoAlbum: 'Album',
    campoDuracion: 'Duration',
    campoLanzamiento: 'Released',
    campoIsrc: 'ISRC',
    campoOrigen: 'Source',
    traduciendo: 'Translating…',
    traduccionError: 'Could not translate',
    traduccionTitulo: 'Translate details',
    traduccionAyuda:
        'Translates the song name, artist and album. Dates and codes are '
        'never translated.',
    traduccionDetectado: 'Detected language:',
    traduccionOcultar: 'Show original',
  );
}
