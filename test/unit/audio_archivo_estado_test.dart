// audio_archivo_estado_test.dart — Fija que un archivo descargado NUNCA se
// declare roto sin evidencia.
//
// El bug que esto previene: el validador viejo devolvía "no reproducible"
// cuando ni siquiera podía leer el archivo (permiso sin conceder, carpeta
// externa no montada, E/S ocupada). Ese `false` se interpretaba como
// "corrupto": la descarga dejaba de contar como descargada y, peor, el
// reparador de arranque borraba el archivo y su fila de la base. El usuario
// lo vivía como "la descarga me dura un día y se pierde".
//
// Regla que se fija acá: para decir `corrupto` hace falta EVIDENCIA POSITIVA
// de otro contenedor (una caja MP4 `ftyp`, texto/HTML, un ZIP). No poder leer
// el archivo, o no reconocer el header, es `desconocido` y se trata como bueno.
//
// Se conecta con: estado/descargas/reparar/audio_archivo_estado.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/estado/descargas/reparar/audio_archivo_estado.dart';

late Directory _dir;

/// Escribe [bytes] en un archivo temporal con la extensión [ext].
String _crear(String nombre, String ext, List<int> bytes) {
  final f = File('${_dir.path}${Platform.pathSeparator}$nombre.$ext');
  f.writeAsBytesSync(bytes);
  return f.path;
}

/// Header de una caja MP4 (`ftyp`) — así se ven los streams encriptados.
const _mp4 = [0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70];
const _flac = [0x66, 0x4C, 0x61, 0x43, 0x00, 0x00, 0x00, 0x22];
const _id3 = [0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00];
const _riff = [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00];
const _oggs = [0x4F, 0x67, 0x67, 0x53, 0x00, 0x00, 0x00, 0x00];
const _html = [0x3C, 0x21, 0x44, 0x4F, 0x43, 0x54, 0x59, 0x50];

void main() {
  setUpAll(() => _dir = Directory.systemTemp.createTempSync('bitly_audio_'));
  tearDownAll(() {
    try {
      _dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('audio válido → ok', () {
    test('FLAC real', () async {
      expect(
        await estadoAudioEnDisco(_crear('bueno', 'flac', _flac)),
        EstadoArchivoAudio.ok,
      );
    });

    test('FLAC con tag ID3 delante (reproduce igual)', () async {
      // Regresión: esto se marcaba como roto y la descarga se borraba.
      expect(
        await estadoAudioEnDisco(_crear('conid3', 'flac', _id3)),
        EstadoArchivoAudio.ok,
      );
    });

    test('WAV y OGG', () async {
      expect(
        await estadoAudioEnDisco(_crear('w', 'wav', _riff)),
        EstadoArchivoAudio.ok,
      );
      expect(
        await estadoAudioEnDisco(_crear('o', 'ogg', _oggs)),
        EstadoArchivoAudio.ok,
      );
    });

    test('mp4/m4a: no se sniffean (un video descargado es válido)', () async {
      expect(
        await estadoAudioEnDisco(_crear('v', 'mp4', _mp4)),
        EstadoArchivoAudio.ok,
      );
      expect(
        await estadoAudioEnDisco(_crear('a', 'm4a', _mp4)),
        EstadoArchivoAudio.ok,
      );
    });
  });

  group('evidencia positiva de otro contenedor → corrupto', () {
    test('stream encriptado guardado como .flac (caja MP4)', () async {
      expect(
        await estadoAudioEnDisco(_crear('enc', 'flac', _mp4)),
        EstadoArchivoAudio.corrupto,
      );
    });

    test('página HTML guardada como audio', () async {
      expect(
        await estadoAudioEnDisco(_crear('err', 'flac', _html)),
        EstadoArchivoAudio.corrupto,
      );
    });
  });

  group('no se pudo leer o no se reconoce → desconocido (NO corrupto)', () {
    test('archivo inexistente', () async {
      // Regresión clave: esto devolvía `false` (= borrar la descarga).
      final ruta = '${_dir.path}${Platform.pathSeparator}no-existe.flac';
      expect(
        await estadoAudioEnDisco(ruta),
        EstadoArchivoAudio.desconocido,
      );
    });

    test('ruta vacía', () async {
      expect(await estadoAudioEnDisco(''), EstadoArchivoAudio.desconocido);
    });

    test('una carpeta con nombre de audio', () async {
      final d = Directory('${_dir.path}${Platform.pathSeparator}carpeta.flac')
        ..createSync();
      expect(
        await estadoAudioEnDisco(d.path),
        EstadoArchivoAudio.desconocido,
      );
    });

    test('archivo vacío o truncado', () async {
      expect(
        await estadoAudioEnDisco(_crear('vacio', 'flac', const [])),
        EstadoArchivoAudio.desconocido,
      );
      expect(
        await estadoAudioEnDisco(_crear('corto', 'flac', const [0x66, 0x4C])),
        EstadoArchivoAudio.desconocido,
      );
    });

    test('header que no reconocemos', () async {
      expect(
        await estadoAudioEnDisco(
          _crear('raro', 'flac', const [0x11, 0x22, 0x33, 0x44]),
        ),
        EstadoArchivoAudio.desconocido,
      );
    });
  });

  group('esAudioUsableEnDisco', () {
    test('solo el corrupto se rechaza', () async {
      expect(
        await esAudioUsableEnDisco(_crear('ok2', 'flac', _flac)),
        isTrue,
      );
      expect(
        await esAudioUsableEnDisco(_crear('rot2', 'flac', _mp4)),
        isFalse,
      );
      // Lo importante: un archivo que no se pudo leer NO se rechaza.
      expect(
        await esAudioUsableEnDisco(
          '${_dir.path}${Platform.pathSeparator}tampoco-existe.flac',
        ),
        isTrue,
      );
    });
  });
}
