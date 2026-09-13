// ─────────────────────────────────────────────────────────────
// desencriptado_reencodificar.dart — PART de desencriptado_stream.dart:
// fallbacks de re-codificación cuando -c copy falla: flac re-encoded,
// m4a (mp4 muxer), dos pasos (tmp mp4 → flac/m4a) y AAC como último
// recurso universal. Separado del flujo principal para mantener el
// límite de líneas.
// Se conecta con: desencriptado_stream.dart (misma library).
// Parte del flujo: desencriptado de streams (fallbacks de recode).
// ─────────────────────────────────────────────────────────────

part of 'desencriptado_stream.dart';

/// Fallbacks de re-codificación (se llaman cuando el copy falló).
Future<ResultadoDesencriptadoStream> _reencodificarFallbacks({
  required ResultadoDesencriptadoStream resultado,
  required String rutaOrigen,
  required String Function(String ext) rutaSalida,
  required String demuxer,
  required String candidata,
  required String extPreferida,
}) async {
  var res = resultado;

  // Re-encode fallback: FLAC es lossless, así que re-codificar con -c:a flac
  // es seguro y funciona cuando -c copy falla (p.ej. FLAC-in-MP4 donde el
  // layout del contenedor impide copia directa a .flac). Se fija el muxer de
  // salida explícito (-f flac / -f mp4) porque ffmpeg auto-detecta 'ipod'
  // para .m4a que rechaza codec FLAC.
  if (!res.exito && extPreferida == '.flac') {
    final rutaOut = rutaSalida('.flac');
    res = await _ejecutarDecrypt(
      <String>[
        '-nostdin',
        '-hide_banner',
        '-v', 'error',
        '-decryption_key', candidata,
        '-f', demuxer,
        '-i', rutaOrigen,
        '-map', '0:a',
        '-c:a', 'flac',
        '-f', 'flac',
        '-y', rutaOut,
      ],
      rutaOut,
    );
  }

  // Re-encode a .m4a como último recurso (FLAC re-codificado en contenedor
  // MP4). DEBE usar -f mp4 (no ipod) porque ipod rechaza codec FLAC.
  if (!res.exito && extPreferida == '.flac') {
    final rutaOut = rutaSalida('.m4a');
    res = await _ejecutarDecrypt(
      <String>[
        '-nostdin',
        '-hide_banner',
        '-v', 'error',
        '-decryption_key', candidata,
        '-f', demuxer,
        '-i', rutaOrigen,
        '-map', '0:a',
        '-c:a', 'flac',
        '-f', 'mp4',
        '-y', rutaOut,
      ],
      rutaOut,
    );
  }

  // Opción nuclear: decrypt a .mp4 temporal primero (copy, siempre funciona
  // para MP4-in-MP4), luego re-encode desde el temp a formato deseado. Este
  // camino de dos pasos evita desajustes demuxer/muxer en modo single-pass.
  if (!res.exito && extPreferida == '.flac') {
    final tmpMp4 = rutaSalida('.tmp.mp4');
    final resTmp = await _ejecutarDecrypt(
      _construirArgsDecrypt(
        demuxer: demuxer,
        rutaEntrada: rutaOrigen,
        rutaSalida: tmpMp4,
        clave: candidata,
        soloAudio: true,
      ),
      tmpMp4,
    );
    if (resTmp.exito && await File(tmpMp4).exists()) {
      // Re-encode del MP4 desencriptado temporal a .flac
      var rutaOut = rutaSalida('.flac');
      res = await _ejecutarDecrypt(
        <String>[
          '-nostdin',
          '-hide_banner',
          '-v', 'error',
          '-i', tmpMp4,
          '-map', '0:a',
          '-c:a', 'flac',
          '-f', 'flac',
          '-y', rutaOut,
        ],
        rutaOut,
      );
      // Si el re-encode a .flac también falló, intentar .m4a
      if (!res.exito) {
        rutaOut = rutaSalida('.m4a');
        res = await _ejecutarDecrypt(
          <String>[
            '-nostdin',
            '-hide_banner',
            '-v', 'error',
            '-i', tmpMp4,
            '-map', '0:a',
            '-c:a', 'flac',
            '-f', 'mp4',
            '-y', rutaOut,
          ],
          rutaOut,
        );
      }
    }
    // Limpiar el archivo temporal
    try {
      await File(tmpMp4).delete();
    } catch (_) {}
  }

  // AAC re-encode fallback: cuando FLAC copy y FLAC re-encode fallan (p.ej.
  // ffmpeg-kit de emulador no maneja FLAC-in-MP4), caer a AAC que es
  // universalmente soportado. Produce archivo con pérdida pero es mejor que
  // no tener archivo.
  if (!res.exito) {
    final rutaOut = rutaSalida('.m4a');
    res = await _ejecutarDecrypt(
      <String>[
        '-nostdin', '-hide_banner', '-v', 'error',
        '-decryption_key', candidata,
        '-f', demuxer,
        '-i', rutaOrigen,
        '-map', '0:a',
        '-c:a', 'aac', '-b:a', '256k',
        '-f', 'ipod',
        '-y', rutaOut,
      ],
      rutaOut,
    );
  }

  return res;
}