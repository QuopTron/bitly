// ─────────────────────────────────────────────────────────────
// desencriptado_ejecucion.dart — PART de desencriptado_stream.dart:
// ejecuta el comando ffmpeg de decrypt (forma lista de args, sin
// shell), valida el archivo de salida (que parezca media real y no
// el stream DRM aún cifrado) y espera a que el archivo aparezca
// con contenido real (el callback async de ffmpeg-kit puede
// dispararse antes del flush final).
// Se conecta con: desencriptado_stream.dart (misma library).
// Parte del flujo: desencriptado de streams (ejecución ffmpeg).
// ─────────────────────────────────────────────────────────────

part of 'desencriptado_stream.dart';

/// True si [ruta] tiene audio desencriptado plausible (no CENC `cmfc`/`cenc`,
/// página de error o archivo vacío). Acepta un resultado ffmpeg aunque el
/// código de retorno del kit no sea confiable (callback async en emuladores).
Future<bool> _pareceMediaDesencriptada(String ruta) async {
  try {
    final f = File(ruta);
    if (!await f.exists()) return false;
    final tam = await f.length();
    if (tam < 10240) return false; // Rechaza archivos < 10KB (truncados/vacíos)
    final raf = await f.open();
    List<int> head;
    try {
      head = await raf.read(64);
    } finally {
      await raf.close();
    }
    if (head.length < 4) return false;
    String ascii(int x) => String.fromCharCode(x);
    final magic4 = ascii(head[0]) + ascii(head[1]) + ascii(head[2]) + ascii(head[3]);
    if (magic4 == 'fLaC' || magic4 == 'ID3' || magic4 == 'OggS' || magic4 == 'RIFF') {
      return true;
    }
    // MP4/MOV: acepta si tiene caja ftyp Y NO es marca CENC-encrypted
    // ("cmfc"/"cenc" significaría que sigue el stream DRM crudo). También
    // rechaza marcadores de cifrado (sinf/enca/encv).
    final asciis = head.map(ascii).join('');
    if (asciis.contains('ftyp')) {
      if (asciis.contains('cmfc') || asciis.contains('cenc')) return false;
      if (asciis.contains('sinf') || asciis.contains('enca') || asciis.contains('encv')) return false;
      return true;
    }
    // Payload binario desconocido con contenido — darle el beneficio de la
    // duda (la cadena de respaldo valida la estructura aguas abajo).
    return true;
  } catch (_) {
    return false;
  }
}

/// Espera a que [ruta] aparezca con contenido real: el callback async de
/// ffmpeg-kit puede dispararse antes del flush final del archivo.
Future<bool> _esperarArchivo(String ruta, {int intentos = 12}) async {
  for (var i = 0; i < intentos; i++) {
    try {
      final f = File(ruta);
      if (await f.exists() && (await f.length()) > 0) return true;
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}

/// Ejecuta un solo comando ffmpeg de decrypt. Prefiere el archivo en disco
/// sobre el código de retorno del kit (callback async poco confiable).
Future<ResultadoDesencriptadoStream> _ejecutarDecrypt(
  List<String> args,
  String rutaSalida,
) async {
  try {
    final sesion = await FFmpegKit.executeWithArgumentsAsync(args);
    final codigo = await sesion.getReturnCode();
    String salida = '';
    try {
      salida = (await sesion.getOutput() ?? '').trim();
    } catch (_) {}
    final flusheado = await _esperarArchivo(rutaSalida);
    if (flusheado && await _pareceMediaDesencriptada(rutaSalida)) {
      return ResultadoDesencriptadoStream(
        rutaArchivo: rutaSalida,
        exito: true,
        salida: salida,
      );
    }
    return ResultadoDesencriptadoStream(
      rutaArchivo: null,
      exito: false,
      salida: salida.isEmpty ? 'ffmpeg decrypt falló (rc=$codigo)' : salida,
    );
  } on Exception catch (e) {
    // ffmpeg-kit puede lanzar (SESSION_NOT_FOUND en la carrera de su callback)
    // incluso con salida producida — nunca crashear, verificar en disco.
    final flusheado = await _esperarArchivo(rutaSalida);
    if (flusheado && await _pareceMediaDesencriptada(rutaSalida)) {
      return ResultadoDesencriptadoStream(
        rutaArchivo: rutaSalida,
        exito: true,
        salida: 'error de ffmpeg-kit recuperado: $e',
      );
    }
    return ResultadoDesencriptadoStream(
      rutaArchivo: null,
      exito: false,
      salida: 'error de ffmpeg-kit: $e',
    );
  }
}

/// Construye la lista de args de decrypt: fuerza el demuxer MOV (la entrada
/// puede llamarse `.flac` pero contener MP4 cifrado), mapea solo audio, y
/// fuerza el muxer según la extensión de salida (sin eso FFmpeg mantiene el
/// layout ISO-BMFF bajo nombre .flac → archivo truncado/indecodificable).
List<String> _construirArgsDecrypt({
  required String demuxer,
  required String rutaEntrada,
  required String rutaSalida,
  required String clave,
  required bool soloAudio,
  bool forzarMuxerMov = false,
}) {
  final List<String> overrideMuxer;
  if (forzarMuxerMov) {
    overrideMuxer = <String>['-f', 'mov'];
  } else if (rutaSalida.toLowerCase().endsWith('.flac')) {
    overrideMuxer = <String>['-f', 'flac'];
  } else if (rutaSalida.toLowerCase().endsWith('.mp4') ||
      rutaSalida.toLowerCase().endsWith('.m4a') || rutaSalida.toLowerCase().endsWith('.aac')) {
    // .m4a/.aac son ISO-BMFF — usar mp4, NO ipod (ipod rechaza FLAC).
    overrideMuxer = <String>['-f', 'mp4'];
  } else {
    overrideMuxer = <String>['-f', 'ipod'];
  }
  return <String>[
    '-nostdin', '-hide_banner', '-v', 'error', '-decryption_key', clave,
    '-f', demuxer, '-i', rutaEntrada,
    if (soloAudio) ...<String>['-map', '0:a'],
    '-c', 'copy', ...overrideMuxer, '-y', rutaSalida,
  ];
}