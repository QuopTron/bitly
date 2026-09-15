// ─────────────────────────────────────────────────────────────
// acciones_item_lote.dart — PART de acciones_item.dart: acciones de
// ítem por LOTE (álbum/playlist) — descarga con selector de calidad
// (pre-fetch del detalle a Go) y exportación a M3U/CUE/NFO con
// feedback en SnackBar. Los handlers simples quedan en el padre.
// Se conecta con: acciones_item.dart (misma library) + cubit_descargas
// + hoja_opciones_descarga + exportacion_playlist_ui + cache_ajustes.
// Parte del flujo: acciones de ítem en todas las vistas.
// ─────────────────────────────────────────────────────────────

part of 'acciones_item.dart';

/// Descarga por lote (álbum/playlist): fetch del detalle a Go, muestra
/// la hoja de calidad (igual que el detalle) y despacha con la calidad
/// elegida. Antes descargaba directo sin modal — por eso el usuario no
/// veía el selector de calidad al descargar álbum/playlist desde el feed,
/// búsqueda o Mi Espacio.
Future<void> _iniciarDescargaLote(
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

/// Exporta álbum/playlist a archivos M3U/CUE/NFO con feedback en SnackBar.
Future<void> _exportarPlaylist(BuildContext context, ItemFeed item) async {
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
