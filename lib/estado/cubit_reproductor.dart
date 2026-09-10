// ─────────────────────────────────────────────────────────────
// cubit_reproductor.dart — Cubit del reproductor de audio: abre
// tracks (local-first → streaming con verificación de sesión),
// resuelve streams vía Go (caché, dedup, decrypt, proxy local),
// precarga vecinos/letras/video, maneja el fin de canción (guards
// de stream muerto/preview, scrobble, avance con repetición),
// autoplay y controles (play/pausa/seek/volumen/velocidad).
// Los 2,535 líneas del PlayerCubit original se reparten en 24 mixins
// en cadena (cada uno `on` el anterior), todos ≤150 líneas:
//   base → estado_cache → stream → stream_proxy → stream_pipeline →
//   stream_resolve → archivos_temp → video_local → video_descarga →
//   video_fondo → preload → preload_media → controles → verificacion →
//   reporte → apertura_helpers → apertura → autoplay → limpieza →
//   completado → locales → player_setup → listener_cola → init.
// Se conecta con: CubitCola (cola), BackendService (Go), caches
// drift, ServicioVerificacion y ServicioConectividad.
// Parte del flujo: reproducción (miniplayer, notificación, player).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/inyeccion.dart' as di;
import '../core/backend_go/contrato_backend.dart';
import '../core/cache/cache_ajustes.dart';
import '../core/cache/cache_descargas.dart';
import '../core/cache/estado_cola.dart';
import '../core/cache/estado_reproductor.dart';
import '../core/cache/reproduccion_cache.dart';
import '../core/modelos/item_feed.dart';
import '../core/modelos/perfil_rendimiento.dart';
import '../core/plataforma/servicio_conectividad.dart';
import '../core/plataforma/servicio_foco_audio.dart';
import '../core/servicios/desencriptado_stream.dart';
import '../core/servicios/huella_item.dart';
import '../core/servicios/servicio_verificacion.dart';
import '../core/servicios/utilidades_id.dart';
import 'cubit_cola.dart';

part 'reproductor_base.dart';
part 'reproductor_estado_cache.dart';
part 'reproductor_stream.dart';
part 'reproductor_stream_proxy.dart';
part 'reproductor_stream_pipeline.dart';
part 'reproductor_stream_resolve.dart';
part 'reproductor_archivos_temp.dart';
part 'reproductor_video_local.dart';
part 'reproductor_video_descarga.dart';
part 'reproductor_video_fondo.dart';
part 'reproductor_preload.dart';
part 'reproductor_preload_media.dart';
part 'reproductor_controles.dart';
part 'reproductor_verificacion.dart';
part 'reproductor_reporte.dart';
part 'reproductor_apertura_helpers.dart';
part 'reproductor_apertura.dart';
part 'reproductor_autoplay.dart';
part 'reproductor_limpieza.dart';
part 'reproductor_completado.dart';
part 'reproductor_locales.dart';
part 'reproductor_player_setup.dart';
part 'reproductor_listener_cola.dart';
part 'reproductor_init.dart';

/// Cubit del reproductor: ensambla los 24 mixins de estado, apertura, stream,
/// precarga, controles, completado y limpieza sobre un Cubit de
/// EstadoAudioReproductor.
class CubitReproductor extends Cubit<EstadoAudioReproductor>
    with
        ReproductorBase,
        ReproductorEstadoCache,
        ReproductorStream,
        ReproductorStreamProxy,
        ReproductorStreamPipeline,
        ReproductorStreamResolve,
        ReproductorArchivosTemp,
        ReproductorVideoLocal,
        ReproductorVideoDescarga,
        ReproductorVideoFondo,
        ReproductorPreload,
        ReproductorPreloadMedia,
        ReproductorControles,
        ReproductorVerificacion,
        ReproductorReporte,
        ReproductorAperturaHelpers,
        ReproductorApertura,
        ReproductorAutoplay,
        ReproductorLimpieza,
        ReproductorCompletado,
        ReproductorLocales,
        ReproductorPlayerSetup,
        ReproductorListenerCola,
        ReproductorInit
    implements ControladorReproductor {
  /// Stream de si está reproduciendo (para el foco de audio).
  @override
  Stream<bool> get streamReproduciendo => stream.map((s) => s.estaReproduciendo);

  /// Si está reproduciendo ahora mismo (foco de audio).
  @override
  bool get estaReproduciendoAhora => state.estaReproduciendo;
  /// El constructor del cubit se reescribe acá (los mixins no pueden tener
  /// constructores): arranca el player mpv, la ruta de descargas + ajustes,
  /// el listener de cola, el perfil de rendimiento y el caché persistente.
  CubitReproductor(CubitCola cubitCola)
      : super(const EstadoAudioReproductor()) {
    _queueCubit = cubitCola;
    _initPlayer();
    unawaited(_initRutaDescargas());
    _listenQueue();
    _subPerfil = _onPerfilCambio;
    di.sl<ValueNotifier<PerfilRendimiento>>().addListener(_onPerfilCambio);
    unawaited(_cargarCachePersistente());
  }
}