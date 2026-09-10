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

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/modelos/detalle_album.dart';
import '../../core/modelos/detalle_playlist.dart';
import '../../core/modelos/detalle_track.dart';
import '../../core/modelos/item_feed.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../widgets/hoja_opciones_descarga.dart';
import '../widgets/modal_agregar_a.dart';
import '../widgets/modal_info_cancion.dart';
import 'exportacion_playlist_ui.dart';

part 'acciones_item_detalle.dart';

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

  /// Descarga por lote (álbum/playlist): fetch del detalle a Go, muestra
  /// la hoja de calidad (igual que el detalle) y despacha con la calidad
  /// elegida. Antes descargaba directo sin modal — por eso el usuario no
  /// veía el selector de calidad al descargar álbum/playlist desde el feed,
  /// búsqueda o Mi Espacio.
  static Future<void> iniciarDescargaLote(
      BuildContext context, ItemFeed item) async {
    final cubit = sl<CubitDescargas>();
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final ajustes = await sl<CacheAjustes>().getAjustesDescarga();
    final src = item.source ?? '';

    // Pre-fetch del detalle para conocer los tracks del lote.
    final List<Map<String, dynamic>> tracks;
    if (item.type == 'album') {
      final detalle = await _fetchDetalleAlbum(item.id, src);
      if (detalle == null || detalle.tracks.isEmpty) return;
      tracks = _tracksAMapas(detalle.tracks, src, coverUrlPadre: item.coverUrl);
    } else if (item.type == 'playlist') {
      final detalle = await _fetchDetallePlaylist(item.id, src);
      if (detalle == null || detalle.tracks.isEmpty) return;
      tracks = _tracksAMapas(detalle.tracks, src, coverUrlPadre: item.coverUrl);
    } else {
      return;
    }
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HojaOpcionesDescarga(
        item: item,
        esOscuro: esOscuro,
        ajustes: ajustes,
        onCalidadSeleccionada: (calidad) {
          if (item.type == 'album') {
            cubit.iniciarDescargaAlbum(
              item.id,
              tracks,
              ajustes: ajustes,
              source: src,
              calidadForzada: calidad,
            );
          } else {
            cubit.iniciarDescargaPlaylist(
              item.id,
              tracks,
              ajustes: ajustes,
              source: src,
              calidadForzada: calidad,
            );
          }
        },
      ),
    );
  }

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

  /// Exporta álbum/playlist a archivos M3U/CUE/NFO con feedback en SnackBar.
  static Future<void> exportarPlaylist(
      BuildContext context, ItemFeed item) async {
    final messenger = ScaffoldMessenger.of(context);
    final esAlbum = item.type == 'album';
    final src = item.source ?? '';
    final String nombre;
    final List<TrackDetalle> tracks;
    if (esAlbum) {
      final detalle = await _fetchDetalleAlbum(item.id, src);
      if (detalle == null) {
        _snackError(messenger, esAlbum);
        return;
      }
      nombre = detalle.name;
      tracks = detalle.tracks;
    } else {
      final detalle = await _fetchDetallePlaylist(item.id, src);
      if (detalle == null) {
        _snackError(messenger, esAlbum);
        return;
      }
      nombre = detalle.name;
      tracks = detalle.tracks;
    }
    await exportarConSnack(
      // ignore: use_build_context_synchronously
      context: context,
      name: nombre,
      tracks: tracks,
      initialDirectory: await sl<CacheAjustes>().getRutaDescargas(),
    );
  }
}