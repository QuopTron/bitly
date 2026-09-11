// puente_notificacion_media.dart — Puente entre la notificación media /
// controles del SO y el motor real de reproducción (CubitReproductor /
// CubitCola, isolate principal). En Android maneja un foreground service
// para seguir en segundo plano; espeja track, tiempo y controles
// (prev/play/pause/next/shuffle/repeat) al proxy del isolate de
// audio_service (manejador_notificacion_media.dart).

import 'dart:async';
import 'dart:isolate';

import 'package:audio_service/audio_service.dart';

import '../../app/inyeccion.dart' as di;
import '../cache/estado_cola.dart';
import '../cache/estado_reproductor.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_reproductor.dart';
import 'manejador_notificacion_media.dart';
import 'notificacion_media_helpers.dart';

part 'puente_notificacion_media_comandos.dart';

/// Puente singleton que espeja el estado real de reproducción en el handler.
class PuenteNotificacionMedia {
  PuenteNotificacionMedia._();

  static final PuenteNotificacionMedia instancia = PuenteNotificacionMedia._();

  AudioHandler? _handler;
  SendPort? _puertoEstadoHandler;
  StreamSubscription<EstadoCola>? _subCola;
  StreamSubscription<EstadoAudioReproductor>? _subReproductor;
  ReceivePort? _puertoControl;

  EstadoCola? _ultimaCola;
  EstadoAudioReproductor? _ultimoReproductor;
  DateTime _ultimoPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _inicializado = false;

  // Últimos valores enviados: un cambio de play/pause o buffering fuerza una
  // actualización inmediata de la notificación (no espera el throttle de 1 s).
  bool? _ultimoEnviadoReproduciendo;
  String? _ultimoEnviadoProcesando;

  AudioHandler? get handler => _handler;

  /// Inicializa [AudioService] y suscribe los cubits al handler. Se llama
  /// una vez desde main tras configurar la inyección.
  Future<void> init() async {
    if (_inicializado) return;
    _inicializado = true;

    _puertoControl = ReceivePort();
    final enviarAHandler = _puertoControl!.sendPort;

    try {
      _handler = await AudioService.init(
        builder: () => ManejadorAudioBitly(enviarAHandler),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.quoptron.bitly.channel.audio',
          androidNotificationChannelName: 'Bitly Music',
          // Mantiene el servicio en foreground incluso en pausa para no
          // chocar con la restricción Android 12+ de arrancar un servicio
          // foreground desde segundo plano al reanudar.
          androidStopForegroundOnPause: false,
          androidNotificationClickStartsActivity: true,
          androidResumeOnClick: true,
        ),
      );
    } catch (e) {
      // audio_service puede no existir en algunos desktops. La reproducción
      // dentro de la app siempre funciona; solo se omite la capa media del SO.
      _inicializado = false;
      return;
    }

    _puertoControl!.listen((raw) => _onMensajeControl(this, raw));

    // Espeja el estado real de reproducción hacia el handler.
    _subCola = di.sl<CubitCola>().stream.listen((q) {
      _ultimaCola = q;
      _pushEstado(force: true);
    });
    _subReproductor = di.sl<CubitReproductor>().stream.listen((p) {
      _ultimoReproductor = p;
      _pushEstado();
    });
  }

  /// Envía el snapshot actual al handler. Las actualizaciones de posición se
  /// limitan a ~1 Hz salvo con [force] (cambio de track, play/pause, seek...).
  void _pushEstado({bool force = false}) {
    if (_puertoEstadoHandler == null) return;
    final cola = _ultimaCola;
    final reproductor = _ultimoReproductor;
    if (cola == null || reproductor == null) return;

    final reproduciendo = reproductor.estaReproduciendo;
    final procesando = procesandoDesde(reproductor);
    // Play/pause y buffering importan visualmente — saltan el throttle.
    if (reproduciendo != _ultimoEnviadoReproduciendo ||
        procesando != _ultimoEnviadoProcesando) {
      force = true;
    }

    final ahora = DateTime.now();
    if (!force &&
        ahora.difference(_ultimoPush) < const Duration(milliseconds: 1000)) {
      return;
    }

    final track = cola.actual;
    final media = track == null
        ? <String, dynamic>{'hasCurrent': false}
        : <String, dynamic>{
            'hasCurrent': true,
            'id': track.id,
            'title': track.name,
            'artist': track.artists ?? '',
            'album': track.albumName ?? '',
            'durationMs': track.durationMs ?? reproductor.duracion.inMilliseconds,
            'artUri': track.coverUrl,
          };

    _puertoEstadoHandler!.send({
      ...media,
      'playing': reproduciendo,
      'processing': procesando,
      'positionMs': reproductor.posicion.inMilliseconds,
      'bufferedMs': reproductor.posicion.inMilliseconds,
      'shuffle': cola.shuffle,
      'repeat': repeticionDesde(cola.modoRepeticion),
      'queueIndex': cola.indiceActual,
    });
    _ultimoEnviadoReproduciendo = reproduciendo;
    _ultimoEnviadoProcesando = procesando;
    _ultimoPush = ahora;
  }

  /// Detiene la reproducción en segundo plano y cierra el servicio.
  Future<void> dispose() async {
    await _subCola?.cancel();
    await _subReproductor?.cancel();
    _puertoControl?.close();
  }
}