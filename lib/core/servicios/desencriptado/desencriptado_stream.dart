// ─────────────────────────────────────────────────────────────
// desencriptado_stream.dart — Desencripta archivos de stream
// DRM (p.ej. Amazon mov_key FLAC-in-MP4) vía ffmpeg-kit, probando
// múltiples formatos de clave y muxers hasta obtener un archivo
// reproducible. Serializa las corridas para no saturar RAM.
// Se conecta con: ffmpeg_kit + player_cubit/download_cubit.
// Parte del flujo: reproducción/descarga de streams cifrados.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';

part 'desencriptado_claves.dart';
part 'desencriptado_ejecucion.dart';
part 'desencriptado_flujo.dart';
part 'desencriptado_reencodificar.dart';

/// Serializa las corridas de decrypt. ffmpeg-kit_full levanta un ffmpeg
/// nativo pesado por sesión; en dispositivos con poca RAM muchas
/// desencriptaciones a la vez (lote + reparación + preloads) hacen OOM a los
/// procesos a mitad de escritura — el síntoma es salida truncada en múltiplos
/// limpios de 4096 + ráfaga de SESSION_NOT_FOUND. Correrlas de a una mantiene
/// un solo ffmpeg vivo y termina la carrera.
final _compuertaDecrypt = <Future<void>>[Future.value()];

Future<T> _serializado<T>(Future<T> Function() ejecutar) async {
  final previo = _compuertaDecrypt.last;
  final completador = Completer<void>();
  _compuertaDecrypt.add(completador.future);
  try {
    await previo;
    return await ejecutar();
  } finally {
    completador.complete();
    _compuertaDecrypt.remove(completador.future);
  }
}

/// Resultado de un intento de desencriptado de stream/descarga.
class ResultadoDesencriptadoStream {
  final String? rutaArchivo;
  final bool exito;
  final String salida;

  const ResultadoDesencriptadoStream({
    this.rutaArchivo,
    required this.exito,
    this.salida = '',
  });
}

/// Desencripta un archivo de stream cifrado en un archivo reproducible.
/// Escribe la salida junto al origen (o en [directorioSalida] con
/// [nombreBaseSalida]) y devuelve la ruta si tuvo éxito (null si no).
/// Robusto contra diferencias de formato de clave, múltiples pistas y
/// codecs que el muxer flac rechaza (cae a .m4a/.mp4 y, por último, al
/// muxer MOV forzado para AC-4/Atmos).
Future<ResultadoDesencriptadoStream> desencriptarArchivoMovKey({
  required String rutaOrigen,
  required String clave,
  String? formatoEntrada,
  String? extensionSalida,
  String? directorioSalida,
  String? nombreBaseSalida,
}) =>
    _serializado(() => _desencriptarMovKeyDesbloqueado(
          rutaOrigen: rutaOrigen,
          clave: clave,
          formatoEntrada: formatoEntrada,
          extensionSalida: extensionSalida,
          directorioSalida: directorioSalida,
          nombreBaseSalida: nombreBaseSalida,
        ));