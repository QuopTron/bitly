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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../app/inyeccion.dart' as di;
import '../core/backend_go/contrato_backend.dart';
import '../core/cache/cache_ajustes.dart';
import '../core/cache/cache_biblioteca.dart';
import '../core/cache/cache_descargas.dart';
import '../core/cache/cache_detalle.dart';
import '../core/cache/estado_descarga.dart';
import '../core/modelos/ajustes_descarga.dart';
import '../core/modelos/item_feed.dart';
import '../core/servicios/acceso_descarga.dart';
import '../core/servicios/desencriptado_stream.dart';
import '../core/servicios/estrategia_descarga.dart';
import '../core/servicios/huella_item.dart';
import '../core/servicios/servicio_verificacion.dart';
import '../core/servicios/utilidades_id.dart';
import 'cubit_like.dart';
import 'cubit_reproductor.dart';

part 'descargas_modelos.dart';
part 'descargas_base.dart';
part 'descargas_reparar.dart';
part 'descargas_reparar_decrypt.dart';
part 'descargas_reparar_escaneo.dart';
part 'descargas_polling.dart';
part 'descargas_carga_tracks.dart';
part 'descargas_carga_lotes.dart';
part 'descargas_carga.dart';
part 'descargas_cola_verificar.dart';
part 'descargas_reintentar.dart';
part 'descargas_cola.dart';
part 'descargas_estado.dart';
part 'descargas_lote_finalizar.dart';
part 'descargas_acceso.dart';
part 'descargas_inicio.dart';
part 'descargas_inicio_album.dart';
part 'descargas_inicio_playlist.dart';
part 'descargas_borrar.dart';
part 'descargas_borrar_playlist.dart';
part 'descargas_borrar_lote.dart';
part 'descargas_despacho.dart';
part 'descargas_track_borrar.dart';
part 'descargas_track_batch.dart';
part 'descargas_track.dart';
part 'descargas_poll_fallido.dart';
part 'descargas_poll_finalizar.dart';
part 'descargas_poll_persistir.dart';
part 'descargas_poll_completado.dart';
part 'descargas_poll_decrypt.dart';
part 'descargas_poll_item.dart';
part 'descargas_poll_lotes.dart';
part 'descargas_poll_timeout.dart';
part 'descargas_poll_progreso.dart';

final _log = Logger();

/// Cubit de descargas — clase principal que combina la cadena de mixins.
class CubitDescargas extends Cubit<EstadoCubitDescargas>
    with
        DescargasBase,
        DescargasReparar,
        DescargasRepararDecrypt,
        DescargasRepararEscaneo,
        DescargasPolling,
        DescargasCargaTracks,
        DescargasCargaLotes,
        DescargasCarga,
        DescargasColaVerificar,
        DescargasReintentar,
        DescargasCola,
        DescargasEstado,
        DescargasLoteFinalizar,
        DescargasAcceso,
        DescargasInicio,
        DescargasInicioAlbum,
        DescargasInicioPlaylist,
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