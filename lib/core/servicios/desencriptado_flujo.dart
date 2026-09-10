// ─────────────────────────────────────────────────────────────
// desencriptado_flujo.dart — PART de desencriptado_stream.dart:
// flujo principal de desencriptado: recorre los candidatos de clave
// y los fallbacks de contenedor (flac → mp4 → m4a → mov forzado)
// hasta obtener un archivo reproducible. Los fallbacks de
// re-codificación viven en desencriptado_reencodificar.dart.
// Se conecta con: desencriptado_stream.dart (misma library).
// Parte del flujo: desencriptado de streams (fallbacks de copy).
// ─────────────────────────────────────────────────────────────

part of 'desencriptado_stream.dart';

/// Implementación sin serializar del desencriptado (el gate ya corrió).
Future<ResultadoDesencriptadoStream> _desencriptarMovKeyDesbloqueado({
  required String rutaOrigen,
  required String clave,
  String? formatoEntrada,
  String? extensionSalida,
  String? directorioSalida,
  String? nombreBaseSalida,
}) async {
  final archivoOrigen = File(rutaOrigen);
  if (!await archivoOrigen.exists()) {
    return const ResultadoDesencriptadoStream(exito: false, salida: 'origen no encontrado');
  }

  final extPreferida = _resolverExtensionPreferida(extensionSalida);
  final demuxer = (formatoEntrada ?? '').trim().isNotEmpty ? formatoEntrada!.trim() : 'mov';
  final dir = directorioSalida ?? archivoOrigen.parent.path;
  final nombreOrigen = archivoOrigen.uri.pathSegments.last;
  final nombreBase = (nombreBaseSalida ?? nombreOrigen).replaceFirst(RegExp(r'\.[^.]+$'), '');
  String rutaSalida(String ext) => '$dir${Platform.pathSeparator}$nombreBase.dec$ext';

  final claves = _candidatosClaveDesencriptado(clave);
  if (claves.isEmpty) {
    return const ResultadoDesencriptadoStream(exito: false, salida: 'sin clave usable');
  }

  String? ultimaSalidaFfmpeg;
  for (final candidata in claves) {
    var rutaOut = rutaSalida(extPreferida);
    var resultado = await _ejecutarDecrypt(
      _construirArgsDecrypt(
        demuxer: demuxer,
        rutaEntrada: rutaOrigen,
        rutaSalida: rutaOut,
        clave: candidata,
        soloAudio: true,
      ),
      rutaOut,
    );
    if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;

    // Fallback: FLAC-in-MP4 no remuxea a .flac con el muxer flac (falla
    // silencioso); mp4 sí soporta FLAC, ipod no — probar mp4 primero.
    if (!resultado.exito && extPreferida == '.flac') {
      rutaOut = rutaSalida('.mp4');
      resultado = await _ejecutarDecrypt(
        _construirArgsDecrypt(
          demuxer: demuxer,
          rutaEntrada: rutaOrigen,
          rutaSalida: rutaOut,
          clave: candidata,
          soloAudio: true,
        ),
        rutaOut,
      );
      if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;
    }

    // Fallback: streams que no se pueden remuxear a FLAC reciben .m4a.
    if (!resultado.exito && extPreferida == '.flac') {
      rutaOut = rutaSalida('.m4a');
      resultado = await _ejecutarDecrypt(
        _construirArgsDecrypt(
          demuxer: demuxer,
          rutaEntrada: rutaOrigen,
          rutaSalida: rutaOut,
          clave: candidata,
          soloAudio: true,
        ),
        rutaOut,
      );
      if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;
    }

    // Fallback: muxer mp4 para codecs que ipod rechaza (eac3, mha1/Atmos).
    if (!resultado.exito) {
      rutaOut = rutaSalida('.mp4');
      resultado = await _ejecutarDecrypt(
        _construirArgsDecrypt(
          demuxer: demuxer,
          rutaEntrada: rutaOrigen,
          rutaSalida: rutaOut,
          clave: candidata,
          soloAudio: true,
        ),
        rutaOut,
      );
      if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;
    }

    // Fallback final: muxer MOV forzado para codecs que mp4 rechaza (AC-4).
    if (!resultado.exito) {
      rutaOut = rutaSalida('.mp4');
      resultado = await _ejecutarDecrypt(
        _construirArgsDecrypt(
          demuxer: demuxer,
          rutaEntrada: rutaOrigen,
          rutaSalida: rutaOut,
          clave: candidata,
          soloAudio: true,
          forzarMuxerMov: true,
        ),
        rutaOut,
      );
      if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;
    }

    // Fallbacks de re-codificación (ver desencriptado_reencodificar.dart).
    if (!resultado.exito) {
      resultado = await _reencodificarFallbacks(
        resultado: resultado,
        rutaOrigen: rutaOrigen,
        rutaSalida: rutaSalida,
        demuxer: demuxer,
        candidata: candidata,
        extPreferida: extPreferida,
      );
      if (!resultado.exito) ultimaSalidaFfmpeg = resultado.salida;
    }

    if (resultado.exito) return resultado;
  }

  // Limpiar salidas parciales.
  for (final ext in [extPreferida, '.m4a', '.mp4', '.tmp.mp4']) {
    try {
      final f = File(rutaSalida(ext));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
  // Incluye el último error de ffmpeg + qué es el archivo realmente (ftyp=
  // cifrado válido, fLaC=plano, "<!"=página de error, tamaño=truncado).
  return ResultadoDesencriptadoStream(
    exito: false,
    salida: ultimaSalidaFfmpeg ?? 'decrypt falló: ${await _huellaArchivo(rutaOrigen)}',
  );
}