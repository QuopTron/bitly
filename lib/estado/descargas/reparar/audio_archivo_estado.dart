// ─────────────────────────────────────────────────────────────
// audio_archivo_estado.dart — ¿un archivo descargado es audio
// reproducible? Mira SOLO los magic bytes del contenedor.
//
// Existe por un bug que borraba descargas del usuario: el chequeo
// viejo devolvía "no reproducible" cuando NI SIQUIERA PODÍA LEER el
// archivo (permiso no concedido todavía, carpeta externa no montada,
// E/S ocupada). Ese `false` se leía como "está corrupto" y terminaba
// borrando la descarga. Acá hay TRES respuestas y la tercera —no sé—
// nunca se castiga: sin evidencia positiva de otro contenedor, el
// archivo se trata como bueno.
//
// Se conecta con: estado/descargas (reparación, cola, poll) y
// estado/reproductor (archivos locales).
// Parte del flujo: descargas (validación de archivos).
// ─────────────────────────────────────────────────────────────

import 'dart:io';

/// Veredicto sobre un archivo de audio en disco.
enum EstadoArchivoAudio {
  /// El header coincide con audio del tipo que dice la extensión: suena.
  ok,

  /// Evidencia POSITIVA de otro contenedor (una caja MP4 `ftyp`, texto/HTML,
  /// un ZIP): con extensión de audio, esto no puede reproducirse.
  corrupto,

  /// No se pudo leer o el header no se reconoce. NO es prueba de nada: puede
  /// ser un formato nuevo, un archivo con tags raros delante, o un fallo
  /// transitorio de E/S. Se trata como bueno.
  desconocido,
}

/// Clasifica el archivo en [ruta] por sus magic bytes.
///
/// Nunca lanza y nunca devuelve [EstadoArchivoAudio.corrupto] por no poder
/// leer: eso es justamente lo que borraba descargas del usuario.
Future<EstadoArchivoAudio> estadoAudioEnDisco(String ruta) async {
  if (ruta.isEmpty) return EstadoArchivoAudio.desconocido;
  RandomAccessFile? raf;
  try {
    final f = File(ruta);
    raf = await f.open(mode: FileMode.read);
    final magic = await raf.read(16);
    return _clasificar(_extension(ruta), magic);
  } catch (_) {
    // Sin permiso, sin archivo, ocupado, ruta rara…: no sabemos. No es corrupto.
    return EstadoArchivoAudio.desconocido;
  } finally {
    try {
      await raf?.close();
    } catch (_) {}
  }
}

/// ¿Se puede usar este archivo? Todo menos [EstadoArchivoAudio.corrupto].
Future<bool> esAudioUsableEnDisco(String ruta) async =>
    await estadoAudioEnDisco(ruta) != EstadoArchivoAudio.corrupto;

/// Extensión en minúsculas, sin el punto ('' si no hay).
String _extension(String ruta) {
  final nombre = ruta.split(RegExp(r'[/\\]')).last.toLowerCase();
  final punto = nombre.lastIndexOf('.');
  return punto >= 0 ? nombre.substring(punto + 1) : '';
}

/// ¿Hay [letras] en [m] a partir de [desde]?
bool _hayEn(List<int> m, int desde, List<int> letras) {
  if (m.length < desde + letras.length) return false;
  for (var i = 0; i < letras.length; i++) {
    if (m[desde + i] != letras[i]) return false;
  }
  return true;
}

/// Caja MP4: el caso real de un stream encriptado guardado como `.flac`, que
/// NO es FLAC y no se puede reproducir.
///
/// Ojo con el offset: una caja MP4 empieza con su TAMAÑO (4 bytes) y recién
/// después el tipo (`ftyp`, `moov`, `mdat`, `styp`). Mirar el byte 0 buscando
/// "ftyp" no encuentra nada, y eso dejaba pasar como buenos justo los
/// archivos que este chequeo existe para detectar.
bool _esCajaMp4(List<int> m) =>
    _hayEn(m, 0, const [0x66, 0x74, 0x79, 0x70]) || // 'ftyp'
    _hayEn(m, 4, const [0x66, 0x74, 0x79, 0x70]) || // [size]'ftyp'
    _hayEn(m, 4, const [0x6D, 0x6F, 0x6F, 0x76]) || // [size]'moov'
    _hayEn(m, 4, const [0x73, 0x74, 0x79, 0x70]) || // [size]'styp'
    _hayEn(m, 4, const [0x6D, 0x64, 0x61, 0x74]); // [size]'mdat'

/// Tag ID3v2 delante de un archivo de audio. El 4º byte es la versión (2/3/4),
/// así que NO se mira: un FLAC o MP3 con ID3 adelante reproduce perfectamente y
/// rechazarlo borraba descargas buenas.
bool _empiezaConId3(List<int> m) =>
    m.length >= 3 && m[0] == 0x49 && m[1] == 0x44 && m[2] == 0x33;

/// Texto/HTML/JSON/ZIP: una página de error o un archivo comprimido guardado
/// con extensión de audio. Tampoco puede sonar.
bool _esTextoOBinarioAjeno(List<int> m) {
  if (m.isEmpty) return false;
  if (m[0] == 0x7B || m[0] == 0x3C) return true; // '{' o '<'
  if (m.length >= 2 && m[0] == 0x50 && m[1] == 0x4B) return true; // 'PK'
  return false;
}

EstadoArchivoAudio _clasificar(String ext, List<int> m) {
  // Archivo vacío o truncado: no hay header que juzgar.
  if (m.length < 4) return EstadoArchivoAudio.desconocido;
  final ajeno = _esCajaMp4(m) || _esTextoOBinarioAjeno(m);

  bool empieza(int a, int b, int c, int d) =>
      m[0] == a && m[1] == b && m[2] == c && m[3] == d;

  switch (ext) {
    case 'flac':
      if (empieza(0x66, 0x4C, 0x61, 0x43)) return EstadoArchivoAudio.ok; // fLaC
      if (_empiezaConId3(m)) return EstadoArchivoAudio.ok; // ID3 + FLAC
      return ajeno ? EstadoArchivoAudio.corrupto : EstadoArchivoAudio.desconocido;

    case 'mp3':
      if (_empiezaConId3(m)) return EstadoArchivoAudio.ok; // ID3
      if (m[0] == 0xFF && (m[1] & 0xE0) == 0xE0) {
        return EstadoArchivoAudio.ok; // frame MPEG
      }
      if (m[0] == 0x47) return EstadoArchivoAudio.ok; // MPEG-TS (HLS)
      return ajeno ? EstadoArchivoAudio.corrupto : EstadoArchivoAudio.desconocido;

    case 'wav':
      if (empieza(0x52, 0x49, 0x46, 0x46)) return EstadoArchivoAudio.ok; // RIFF
      return ajeno ? EstadoArchivoAudio.corrupto : EstadoArchivoAudio.desconocido;

    case 'ogg':
      if (empieza(0x4F, 0x67, 0x67, 0x53)) return EstadoArchivoAudio.ok; // OggS
      return ajeno ? EstadoArchivoAudio.corrupto : EstadoArchivoAudio.desconocido;

    case 'opus':
      if (empieza(0x4F, 0x67, 0x67, 0x53)) return EstadoArchivoAudio.ok; // OggS
      if (empieza(0x1A, 0x45, 0xDF, 0xA3)) return EstadoArchivoAudio.ok; // WebM
      if (ajeno) return EstadoArchivoAudio.corrupto;
      return EstadoArchivoAudio.desconocido; // Opus crudo: no hay magic fijo

    default:
      // mp4/m4a/aac y desconocidas: son contenedores MP4 estructuralmente
      // válidos incluso encriptados, así que no se sniffean (sniffearlos
      // marcaba como roto todo video descargado).
      return EstadoArchivoAudio.ok;
  }
}
