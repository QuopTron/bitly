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
//   avance_seguro → completado_guards → completado → locales →
//   player_setup → listener_cola → init.
// Se conecta con: CubitCola (cola), BackendService (Go), caches
// drift, ServicioVerificacion y ServicioConectividad.
// Parte del flujo: reproducción (miniplayer, notificación, player).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/inyeccion/inyeccion.dart' as di;
import '../../core/audio/base/reproductor_audio.dart';
import '../../core/audio/base/reproductor_audio_nativo.dart'
    if (dart.library.js_interop) '../../core/audio/web/reproductor_audio_web.dart';
import '../../core/backend_go/nucleo/base/contrato_backend.dart';
import '../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../core/cache/almacenes/descargas/cache_descargas.dart';
import '../../core/cache/estado/estado_cola.dart';
import '../../core/cache/estado/estado_reproductor.dart';
import '../../core/cache/reproduccion/base/reproduccion_cache.dart';
import '../../core/modelos/feed/item_feed.dart';
import '../../core/modelos/usuario/perfil/perfil_rendimiento.dart';
import '../../core/plataforma/red/servicio_calidad_red.dart';
import '../../core/plataforma/red/servicio_conectividad.dart';
import '../../core/servicios/reproduccion/decision_completado.dart';
import '../../core/plataforma/sistema/base/servicio_foco_audio.dart';
import '../../core/servicios/desencriptado/pasos/desencriptado_stream.dart';
import '../../core/servicios/utilidades/huella_item.dart';
import '../../core/servicios/verificacion/servicio_verificacion.dart';
import '../../shared/utilidades/formato/comun/textos/l10n_servicio.dart';
import '../../core/servicios/utilidades/utilidades_id.dart';
import '../cola/cubit_cola.dart';

part 'base/base/reproductor_base.dart';
part 'base/fiesta/reproductor_instantanea_fiesta.dart';
part 'base/controles/reproductor_estado_cache.dart';
part 'stream/base/reproductor_stream.dart';
part 'stream/base/reproductor_stream_proxy.dart';
part 'stream/base/reproductor_stream_pipeline.dart';
part 'stream/base/reproductor_stream_resolve.dart';
part 'apertura/errores/reproductor_archivos_temp.dart';
part 'video/reproductor_video_local.dart';
part 'video/reproductor_video_descarga.dart';
part 'video/reproductor_video_fondo.dart';
part 'stream/preload/reproductor_preload_vecinos.dart';
part 'stream/preload/reproductor_preload.dart';
part 'stream/preload/reproductor_preload_media.dart';
part 'base/controles/reproductor_controles.dart';
part 'apertura/base/reproductor_verificacion.dart';
part 'ciclo/reporte/reproductor_reporte.dart';
part 'apertura/base/reproductor_apertura_helpers.dart';
part 'apertura/base/reproductor_apertura.dart';
part 'player/reproductor_autoplay.dart';
part 'ciclo/base/reproductor_limpieza.dart';
part 'player/reproductor_avance_seguro.dart';
part 'ciclo/base/reproductor_completado.dart';
part 'base/base/reproductor_locales.dart';
part 'player/reproductor_player_setup.dart';
part 'ciclo/reporte/reproductor_listener_cola.dart';
part 'base/base/reproductor_init.dart';
part 'base/base/reproductor_constantes.dart';
part 'player/reproductor_player_errores.dart';
part 'ciclo/base/reproductor_completado_guards.dart';
part 'apertura/errores/reproductor_fallo_open.dart';

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
        ReproductorPreloadVecinos,
        ReproductorPreload,
        ReproductorPreloadMedia,
        ReproductorControles,
        ReproductorVerificacion,
        ReproductorReporte,
        ReproductorFalloOpen,
        ReproductorAperturaHelpers,
        ReproductorApertura,
        ReproductorAutoplay,
        ReproductorLimpieza,
        ReproductorAvanceSeguro,
        ReproductorCompletadoGuards,
        ReproductorCompletado,
        ReproductorLocales,
        ReproductorPlayerErrores,
        ReproductorPlayerSetup,
        ReproductorListenerCola,
        ReproductorInit
    implements ControladorReproductor {
  /// Stream de si está reproduciendo (para el foco de audio).
  @override
  Stream<bool> get streamReproduciendo =>
      stream.map((s) => s.estaReproduciendo);

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
