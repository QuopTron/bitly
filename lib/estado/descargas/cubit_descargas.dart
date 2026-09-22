// ─────────────────────────────────────────────────────────────
// cubit_descargas.dart — Cubit de descargas: orquesta TODO el flujo
// de descargas (Mi Espacio y botón de descarga): historial en BD,
// poll de progreso contra el backend Go (3s), cola secuencial FIFO
// con consciencia de lote, decrypt DRM por ffmpeg-kit, verificación
// Cloudflare, gate del plan free, reparación de arranque, reintentos
// de lotes y borrado con respeto de referencias (otros lotes/likes).
// Está dividido en 30 mixins encadenados (cada uno ≤150 líneas y con
// su cabecera): los de abajo aportan campos y helpers; los de arriba
// consumen. `initialize()` arranca la carga + polling + reparación.
// Se conecta con: backend Go, caches (descargas/biblioteca/detalle/
// ajustes) y los cubits de reproductor y likes.
// Parte del flujo: descargas (entrada desde la UI).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/inyeccion/inyeccion.dart' as di;
import '../../core/backend_go/mixins/base/infra_mixin.dart';
import '../../core/backend_go/nucleo/base/contrato_backend.dart';
// Con prefijo: `app_database.dart` exporta una tabla llamada `File` que
// taparía la `File` de dart:io en todo el cubit (rompía cada File(...) del
// flujo de descargas).
import '../../core/base_datos/app_database.dart' as bd;
import '../../core/base_datos/daos/contenido/content_dao.dart' as daobd;
import '../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../core/cache/almacenes/biblioteca/base/cache_biblioteca.dart';
import '../../core/cache/almacenes/descargas/cache_descargas.dart';
import '../../core/cache/almacenes/musica/cache_detalle.dart';
import '../../core/cache/estado/estado_descarga.dart';
import '../../core/modelos/ajustes_descarga.dart';
import '../../core/modelos/feed/item_feed.dart';
import '../../core/servicios/descarga/acceso_descarga.dart';
import '../../core/servicios/descargas/plan/escalado_calidad.dart';
import '../../core/servicios/descargas/plan/motivos_descarga.dart';
import '../../core/servicios/desencriptado/pasos/desencriptado_stream.dart';
import 'reparar/audio_archivo_estado.dart';
import '../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../shared/utilidades/portada/base/caratula_util.dart';
import '../../core/servicios/utilidades/huella_item.dart';
import '../../core/servicios/verificacion/servicio_verificacion.dart';
import '../../core/servicios/utilidades/utilidades_id.dart';
import '../like/base/cubit_like.dart';
import '../reproductor/cubit_reproductor.dart';
import 'lote_restaurado.dart';
import 'track_descargado.dart';

part 'base/estado/descargas_modelos.dart';
part 'base/base/descargas_base.dart';
part 'reparar/descargas_reparar.dart';
part 'reparar/descargas_reparar_decrypt.dart';
part 'reparar/descargas_reparar_escaneo.dart';
part 'poll/base/descargas_polling.dart';
part 'inicio/carga/descargas_carga_tracks.dart';
part 'inicio/carga/descargas_carga_lotes_caratulas.dart';
part 'inicio/carga/descargas_carga_lotes.dart';
part 'inicio/carga/descargas_carga.dart';
part 'cola/verificar/descargas_cola_verificar.dart';
part 'cola/reintento/descargas_reintentar.dart';
part 'cola/reintento/descargas_cola_reintento.dart';
part 'cola/base/cola/descargas_cola.dart';
part 'cola/verificar/descargas_cola_track.dart';
part 'base/estado/descargas_estado.dart';
part 'inicio/lotes/descargas_lote_finalizar.dart';
part 'inicio/lotes/descargas_lote_caratula.dart';
part 'base/base/descargas_acceso.dart';
part 'inicio/base/descargas_inicio.dart';
part 'inicio/base/descargas_inicio_album.dart';
part 'inicio/base/descargas_inicio_playlist.dart';
part 'cola/reintento/descargas_reintento_global.dart';
part 'borrar/descargas_borrar.dart';
part 'borrar/descargas_borrar_playlist.dart';
part 'borrar/descargas_borrar_lote.dart';
part 'cola/base/cola/descargas_despacho.dart';
part 'cola/base/track/descargas_track_borrar.dart';
part 'cola/base/track/descargas_track_batch.dart';
part 'cola/base/track/descargas_track.dart';
part 'poll/ciclo/fallo/descargas_poll_fallido.dart';
part 'poll/ciclo/exito/descargas_poll_finalizar.dart';
part 'poll/base/descargas_poll_persistir.dart';
part 'poll/ciclo/exito/descargas_poll_completado.dart';
part 'poll/ciclo/pasos/descargas_poll_decrypt.dart';
part 'poll/base/descargas_poll_item.dart';
part 'poll/base/descargas_poll_lotes.dart';
part 'poll/ciclo/fallo/descargas_poll_timeout.dart';
part 'poll/ciclo/pasos/descargas_poll_progreso.dart';
part 'base/base/descargas_base_caches.dart';
part 'base/estado/descargas_estado_reintento.dart';

final _log = Logger();

/// Cubit de descargas — clase principal que combina la cadena de mixins.
class CubitDescargas extends Cubit<EstadoCubitDescargas>
    with
        DescargasBaseCaches,
        DescargasBase,
        DescargasReparar,
        DescargasRepararDecrypt,
        DescargasRepararEscaneo,
        DescargasPolling,
        DescargasCargaTracks,
        DescargasCargaLotesCaratulas,
        DescargasCargaLotes,
        DescargasCarga,
        DescargasColaVerificar,
        DescargasReintentar,
        DescargasColaReintento,
        DescargasCola,
        DescargasColaTrack,
        DescargasEstadoReintento,
        DescargasEstado,
        DescargasLoteFinalizar,
        DescargasLoteCaratula,
        DescargasAcceso,
        DescargasInicio,
        DescargasInicioAlbum,
        DescargasInicioPlaylist,
        DescargasReintentoGlobal,
        DescargasBorrar,
        DescargasBorrarPlaylist,
        DescargasBorrarLote,
        DescargasDespacho,
        DescargasTrackBorrar,
        DescargasTrackBatch,
        DescargasTrack,
        DescargasPollFallido,
        DescargasPollFinalizar,
        DescargasPollPersistir,
        DescargasPollCompletado,
        DescargasPollDecrypt,
        DescargasPollItem,
        DescargasPollLotes,
        DescargasPollTimeout,
        DescargasPollProgreso {
  /// El constructor se reescribe acá (los mixins no pueden tener
  /// constructores): inyecta el backend Go y resuelve el caché de descargas.
  CubitDescargas(BackendService backend) : super(const EstadoCubitDescargas()) {
    _backend = backend;
    _downloadCache = di.sl<CacheDescargas>();
  }
}
