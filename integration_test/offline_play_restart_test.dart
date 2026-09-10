// Test B del flujo de reproducción offline: REINICIO SIN INTERNET.
//
// Corre en un PROCESO NUEVO de la app (cada archivo de integration_test se
// instala/lanza por separado) con la RED APAGADA en el emulador
// (adb shell svc wifi disable && adb shell svc data disable), lo que equivale
// a cerrar y reabrir la app sin internet.
//
// Verifica el bug reportado por el usuario: "cuando no hay internet no puedo
// reproducir lo descargable". El track fue "descargado" por
// offline_play_setup_test.dart (archivo WAV real + fila en drift) y aquí debe
// reproducirse SIN NINGUNA llamada de red:
//   drift (download_history) → _loadLocalFiles → _resolveLocalUri → media_kit.
//
// NO se inicializa el backend Go a propósito: la reproducción local no debe
// depender de él, y así el test falla si el player intenta resolver un stream
// por red (offline → error).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:bitly/estado/cubit_reproductor.dart';
import 'package:bitly/estado/cubit_cola.dart';
import 'package:bitly/core/modelos/item_feed.dart';
import 'package:bitly/app/inyeccion.dart' as inj;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline: track descargado se reproduce tras reinicio sin red',
      (tester) async {
    MediaKit.ensureInitialized();
    await inj.configurarDependencias();

    // 1. Pipeline real en proceso nuevo: el historial viene de drift (local).
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

    // 2. Debe arrancar SIN internet (si intenta streaming, falla y queda error).
    var state = player.state;
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = player.state;
      if (state.estaReproduciendo || state.estadoReproduccion.name == 'error') break;
    }
    expect(state.estadoReproduccion.name, 'reproduciendo',
        reason: 'track descargado debe reproducirse offline (estado: '
            '${state.estadoReproduccion.name}, error: ${state.mensajeError})');

    // 3. El position debe avanzar: audio real decodificándose, no stall.
    final deadline2 = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline2) &&
        state.posicion.inMilliseconds < 1000) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = player.state;
    }
    expect(state.posicion.inMilliseconds, greaterThanOrEqualTo(1000),
        reason: 'el audio debe estar decodificándose offline (position: '
            '${state.posicion.inMilliseconds}ms)');
  });
}