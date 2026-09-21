// ─────────────────────────────────────────────────────────────
// lan_cancion.dart — Una canción del catálogo de OTRO aparato.
//
// Viaja con lo mínimo para decidir y bajar: identidad (ISRC, o nombre más
// artista), de dónde salió, cuánto dura y cuánto pesa. La identidad es la
// que decide si ya la tenés: comparar por id de descarga no sirve porque
// cada aparato guarda los suyos.
//
// Se conecta con: lan_modelos (lo reexporta) + servicio_lan.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

/// Una canción descargada en el otro aparato.
class CancionLan {
  /// Id de la descarga (la clave con la que se pide el archivo).
  final String id;

  final String nombre;
  final String artista;
  final String album;

  /// ISRC cuando se conoce: es la identidad buena para decidir si ya la
  /// tenés (el nombre puede coincidir por casualidad).
  final String isrc;

  /// De dónde se la bajó (youtube, soulseek, internetarchive...).
  final String origen;

  /// Duración en milisegundos (0 si no se sabe).
  final int duracionMs;

  /// Tamaño del archivo en bytes (0 si no se pudo leer).
  final int bytes;

  /// Extensión del archivo ('flac', 'mp3'...), sin el punto: el que recibe
  /// tiene que guardarlo con el mismo tipo que tenía.
  final String ext;

  /// Carátula: la URL remota (respaldo por si el archivo no viaja) y la
  /// extensión del archivo local ('jpg', 'png'...). Sin extensión no hay
  /// carátula para prestar.
  final String coverUrl;
  final String extCover;

  /// ¿Tiene la letra descargada al lado del audio? Se copia con el mismo
  /// nombre que usa la app (`lyrics_<sha1 del id>.lrc`).
  final bool tieneLetra;

  const CancionLan({
    required this.id,
    required this.nombre,
    required this.artista,
    this.album = '',
    this.isrc = '',
    this.origen = '',
    this.duracionMs = 0,
    this.bytes = 0,
    this.ext = '',
    this.coverUrl = '',
    this.extCover = '',
    this.tieneLetra = false,
  });

  /// Clave de identidad para comparar catálogos: el ISRC si lo hay, y si no
  /// el nombre + artista normalizados (sin acentos, minúsculas).
  String get clave =>
      isrc.isNotEmpty
          ? 'isrc:${isrc.toUpperCase()}'
          : 'txt:${_normal(nombre)}|${_normal(artista)}';

  /// Normaliza para comparar sin depender de tildes, mayúsculas ni
  /// puntuación. La 'ñ' pasa a 'n' ("ñoña" tiene que encontrar "nona"): si se
  /// borrara, "canción ñoña" y "cancion nona" dejarían de coincidir.
  static String _normal(String s) =>
      s
          .toLowerCase()
          .replaceAll(RegExp('ñ'), 'n')
          .replaceAll(RegExp('ç'), 'c')
          .replaceAll(RegExp('[áàäâ]'), 'a')
          .replaceAll(RegExp('[éèëê]'), 'e')
          .replaceAll(RegExp('[íìïî]'), 'i')
          .replaceAll(RegExp('[óòöô]'), 'o')
          .replaceAll(RegExp('[úùüû]'), 'u')
          .replaceAll(RegExp('[^a-z0-9]'), '')
          .trim();

  Map<String, dynamic> aJson() => {
    'id': id,
    'nombre': nombre,
    'artista': artista,
    'album': album,
    'isrc': isrc,
    'origen': origen,
    'duracionMs': duracionMs,
    'bytes': bytes,
    'ext': ext,
    'coverUrl': coverUrl,
    'extCover': extCover,
    'tieneLetra': tieneLetra,
  };

  factory CancionLan.desdeJson(Map<String, dynamic> json) => CancionLan(
    id: json['id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    artista: json['artista'] as String? ?? '',
    album: json['album'] as String? ?? '',
    isrc: json['isrc'] as String? ?? '',
    origen: json['origen'] as String? ?? '',
    duracionMs: (json['duracionMs'] as num?)?.toInt() ?? 0,
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    ext: json['ext'] as String? ?? '',
    coverUrl: json['coverUrl'] as String? ?? '',
    extCover: json['extCover'] as String? ?? '',
    tieneLetra: json['tieneLetra'] == true,
  );
}
