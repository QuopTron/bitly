// ─────────────────────────────────────────────────────────────
// acciones_item.dart — Centraliza los handlers de acción de los
// ítems (like, descargar, descarga por lote, borrar, exportar,
// info, más) para que Feed, Búsqueda y MiEspacio compartan la
// misma lógica en vez de duplicarla por vista. El lote y la
// exportación fetchean el detalle a Go y delegan en los servicios.
// Se conecta con: cubit_like + cubit_descargas + hoja_opciones_
// descarga + modal_info_cancion + modal_agregar_a + exportacion_
// playlist_ui + cache_ajustes + backend Go (detalle).
// Parte del flujo: acciones de ítem en todas las vistas.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart';
import '../../../core/backend_go/nucleo/contrato_backend.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/modelos/detalle/detalle_album.dart';
import '../../../core/modelos/detalle/detalle_playlist.dart';
import '../../../core/modelos/detalle/detalle_track.dart';
import '../../../core/modelos/feed/item_feed.dart';
import '../../../estado/descargas/cubit_descargas.dart';
import '../../../estado/like/cubit_like.dart';
import '../../widgets/modales/descarga/hoja_opciones_descarga.dart';
import '../../widgets/modales/agregar_a/modal_agregar_a.dart';
import '../../widgets/modales/info_cancion/modal_info_cancion.dart';
import '../descarga/exportacion_playlist_ui.dart';

part 'acciones_item_detalle.dart';
part 'acciones_item_lote.dart';

/// Handlers de acción de ítems compartidos por todas las vistas.
class AccionesItem {
  AccionesItem._();

  static void alternarLike(BuildContext context, ItemFeed item) {
    context.read<CubitLikes>().alternarLike(item);
  }

  static Future<void> iniciarDescarga(
      BuildContext context, ItemFeed item) async {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    await mostrarOpcionesDescarga(context, item, esOscuro);
  }

  static void mostrarInfo(BuildContext context, ItemFeed item) =>
      mostrarInfoCancion(context, item);

  static void mostrarMas(BuildContext context, ItemFeed item) =>
      mostrarAgregarA(context, item);

  /// Descarga por lote: ver acciones_item_lote.dart (implementación).
  static Future<void> iniciarDescargaLote(
          BuildContext context, ItemFeed item) =>
      _iniciarDescargaLote(context, item);

  /// Exporta álbum/playlist: ver acciones_item_lote.dart.
  static Future<void> exportarPlaylist(
          BuildContext context, ItemFeed item) =>
      _exportarPlaylist(context, item);

  static void borrarLote(BuildContext context, ItemFeed item) {
    final src = item.source ?? '';
    final cubit = context.read<CubitDescargas>();
    if (item.type == 'album') {
      cubit.borrarDescargaAlbum(item.id, src);
    } else if (item.type == 'playlist') {
      cubit.borrarDescargaPlaylist(item.id, src);
    }
  }

  static void borrarTrack(BuildContext context, ItemFeed item) {
    context.read<CubitDescargas>().borrarTrackResuelto(item);
  }
}
