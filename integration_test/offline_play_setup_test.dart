// Test A del flujo de reproducción offline: PREPARACIÓN + verificación online.
//
// Simula una descarga real SIN depender de ningún provider: genera un archivo
// de audio WAV válido (sine wave, 3s) directamente en el directorio de
// descargas de la app y registra la fila en drift (CacheDescargas), exactamente
// como lo haría una descarga real. Luego reproduce el track con el pipeline
// real (CubitCola → CubitReproductor → _resolveLocalUri → media_kit).
//
// CORRER EN ORDEN: primero este archivo (con red), luego
// offline_play_restart_test.dart CON LA RED APAGADA en el emulador
// (adb shell svc wifi disable && adb shell svc data disable) — ese segundo
// proceso equivale a cerrar y reabrir la app sin internet.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bitly/core/cache/cache_descargas.dart';
import 'package:bitly/core/backend_go/backend_android.dart';
import 'package:bitly/estado/cubit_reproductor.dart';
import 'package:bitly/estado/cubit_cola.dart';
import 'package:bitly/core/modelos/item_feed.dart';
import 'package:bitly/app/inyeccion.dart' as inj;

/// Genera un WAV PCM 16-bit mono 44.1kHz de [seconds] segundos (sine 440Hz)
/// y lo escribe en [path]. Devuelve la ruta. No usa red.
Future<String> generarWavLocal(String path, {int seconds = 3}) async {
  const sampleRate = 44100;
  final totalSamples = sampleRate * seconds;
  final dataLen = totalSamples * 2; // 16-bit mono
  final bytes = BytesBuilder();

  void writeStr(String s) => bytes.add(s.codeUnits);
  void writeU32(int v) =>
      bytes.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void writeU16(int v) => bytes.add([v & 0xFF, (v >> 8) & 0xFF]);

  writeStr('RIFF');
  writeU32(36 + dataLen);
  writeStr('WAVE');
  writeStr('fmt ');
  writeU32(16); // fmt chunk size
  writeU16(1); // PCM
  writeU16(1); // mono
  writeU32(sampleRate);
  writeU32(sampleRate * 2); // byte rate
  writeU16(2); // block align
  writeU16(16); // bits per sample
  writeStr('data');
  writeU32(dataLen);

  for (var i = 0; i < totalSamples; i++) {
    final sample =
        (math.sin(2 * math.pi * 440 * i / sampleRate) * 12000).round();
    writeU16(sample & 0xFFFF);
  }

  final file = File(path);
  file.parent.createSync(recursive: true);
  await file.writeAsBytes(bytes.toBytes(), flush: true);
  return path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline: descarga local se reproduce online y queda en drift',
      (tester) async {
    MediaKit.ensureInitialized();
    await inj.configurarDependencias();
    final backend = BackendAndroid();

    // 1. Init real del backend Go (el app arranca bien online).
    final healthy = await backend.healthCheck();
    expect(healthy, isTrue, reason: 'el backend Go debe inicializarse');

    // 2. Crear el archivo de audio "descargado" en el dir de descargas.
    final docs = await getApplicationDocumentsDirectory();
    final wavPath = await generarWavLocal('${docs.path}/Bitly/offline_test_1.wav');
    expect(File(wavPath).existsSync(), isTrue, reason: 'el WAV debe existir');

    // 3. Registrar en drift igual que una descarga real.
    await inj.sl<CacheDescargas>().guardarTrackDescargado(
      id: 'offline_test_1',
      trackName: 'Offline Test Track',
      artistName: 'Tester',
      filePath: wavPath,
      service: 'ytmusic-spotiflac',
      duration: 3000,
    );
    final saved = await inj.sl<CacheDescargas>().getRutaArchivoPorId('offline_test_1');
    expect(saved, wavPath, reason: 'drift debe recordar el archivo descargado');

    // 4. Reproducir con el pipeline real (proceso online).
    final queue = inj.sl<CubitCola>();
    final player = inj.sl<CubitReproductor>();
    final track = ItemFeed(
      id: 'offline_test_1',
      type: 'track',
      name: 'Offline Test Track',
      artists: 'Tester',
      source: 'ytmusic-spotiflac',
      durationMs: 3000,
    );
    queue.reproducir(track);

    // Esperar a que arranque la reproducción (media_kit en emulador es lento).
    var state = player.state;
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = player.state;
      if (state.estaReproduciendo || state.estadoReproduccion.name == 'error') break;
    }
    expect(state.estadoReproduccion.name, 'reproduciendo',
        reason: 'debe reproducir el archivo local (estado: '
            '${state.estadoReproduccion.name}, error: ${state.mensajeError})');

    // 5. Esperar a que el position avance (>1s) = audio decodificado real.
    final deadline2 = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline2) &&
        state.posicion.inMilliseconds < 1000) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = player.state;
    }
    expect(state.posicion.inMilliseconds, greaterThanOrEqualTo(1000),
        reason: 'el audio debe estar decodificándose (position: '
            '${state.posicion.inMilliseconds}ms)');

    // Dejar el track registrado en drift para el Test B (reinicio offline).
  });
}