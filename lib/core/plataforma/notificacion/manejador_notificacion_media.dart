// manejador_notificacion_media.dart — Proxy [AudioHandler] del isolate
// de fondo de audio_service (foreground service / notificación media /
// controles del SO). La reproducción real vive en el isolate principal
// (CubitReproductor), así que este handler solo reenvía comandos del SO
// (play/pause/seek/next/prev/shuffle/repeat) al principal vía SendPort y
// re-emite el estado que el principal le empuja (puente_notificacion_media).

import 'dart:isolate';

import 'package:audio_service/audio_service.dart';

part 'manejador_notificacion_media_estado.dart';

/// Handler de audio que corre en el isolate de audio_service.
class ManejadorAudioBitly extends BaseAudioHandler {
  final SendPort _aPrincipal;
  final ReceivePort _puertoEstado = ReceivePort();

  ManejadorAudioBitly(this._aPrincipal) {
    // Avisa al isolate principal cómo empujarnos el estado real.
    _aPrincipal.send({
      '@type': 'register',
      'sendPort': _puertoEstado.sendPort,
    });
    _puertoEstado.listen((dynamic msg) {
      if (msg is Map) _aplicarMensajeEstado(msg);
    });
  }

  // ── SO → isolate principal (control) ──
  @override
  Future<void> play() async => _enviar('play');
  @override
  Future<void> pause() async => _enviar('pause');
  @override
  Future<void> skipToNext() async => _enviar('next');
  @override
  Future<void> skipToPrevious() async => _enviar('prev');
  @override
  Future<void> seek(Duration position) async {
    _enviar('seek', {'ms': position.inMilliseconds});
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _enviar('shuffle', {'on': shuffleMode == AudioServiceShuffleMode.all});
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _enviar('repeat', {'mode': _modoRepeticionAString(repeatMode)});
  }

  @override
  Future<void> stop() async => _enviar('stop');

  void _enviar(String command, [Map<String, dynamic>? extra]) {
    _aPrincipal.send({
      '@type': 'command',
      'cmd': command,
      ...?extra,
    });
  }

  // ── Isolate principal → SO (estado de la notificación) ──
  void _aplicarMensajeEstado(Map<dynamic, dynamic> m) {
    final tieneActual = m['hasCurrent'] == true;
    if (tieneActual) {
      final id = (m['id'] ?? '').toString();
      mediaItem.add(
        MediaItem(
          id: id,
          title: (m['title'] ?? '').toString(),
          artist: (m['artist'] ?? '').toString().isNotEmpty
              ? (m['artist']).toString()
              : (m['album'] ?? '').toString(),
          album: (m['album'] ?? '').toString(),
          duration: Duration(
            milliseconds: (m['durationMs'] as int?) ?? 0,
          ),
          artUri: _parsearArtUri(m['artUri'] as String?),
        ),
      );
    } else {
      mediaItem.add(null);
    }

    final reproduciendo = m['playing'] == true;
    final procesando = _procesandoDesdeString(
      (m['processing'] ?? 'idle').toString(),
    );
    final controles = <MediaControl>[
      const MediaControl(
        androidIcon: 'drawable/bitly_shuffle',
        label: 'Shuffle',
        action: MediaAction.setShuffleMode,
      ),
      MediaControl.skipToPrevious,
      if (reproduciendo) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      const MediaControl(
        androidIcon: 'drawable/bitly_repeat',
        label: 'Repeat',
        action: MediaAction.setRepeatMode,
      ),
    ];

    playbackState.add(
      PlaybackState(
        controls: controles,
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        // Notificación compacta (colapsada): prev, play/pause, next (máx 3).
        androidCompactActionIndices: const [1, 2, 3],
        processingState: tieneActual ? procesando : AudioProcessingState.idle,
        playing: tieneActual && reproduciendo,
        updatePosition: Duration(
          milliseconds: (m['positionMs'] as int?) ?? 0,
        ),
        bufferedPosition: Duration(
          milliseconds: (m['bufferedMs'] as int?) ?? 0,
        ),
        speed: 1.0,
        shuffleMode: (m['shuffle'] == true)
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _modoRepeticionDesdeString((m['repeat'] ?? 'none').toString()),
        queueIndex: (m['queueIndex'] as int?) ?? 0,
      ),
    );
  }

}