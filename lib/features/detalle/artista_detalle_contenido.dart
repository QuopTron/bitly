// ─────────────────────────────────────────────────────────────
// artista_detalle_contenido.dart — PART de artista_detalle_pagina.dart:
// children de la cabecera — top tracks (lista con like/descarga/
// reproducir), top álbumes (grilla horizontal compartida) y tracks
// offline (likes del artista) con banner de solo-descargados.
// Se conecta con: artista_detalle_pagina.dart (misma library) +
// tarjeta_track + tarjeta_grilla + acciones_item.
// Parte del flujo: Detalle → artista (contenido).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Contenido debajo de la cabecera: tracks, álbumes y offline.
List<Widget> _construirContenidoArtista(
  _ArtistaDetallePaginaState st,
  BuildContext context,
  DatosVistaArtista d,
  DetalleArtista artista,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  final r = Responsive(context);
  final esOscuro = Theme.of(context).brightness == Brightness.dark;
  final colorSuperficie = ColoresApp.enSuperficie(esOscuro);
  final loc = AppLocalizations.of(context);
  final widgets = <Widget>[];

  // ── Top tracks ──
  if (st._estaEnLinea && d.tracks.isNotEmpty) {
    widgets.add(_tituloSeccion(r, loc.setup.searchTracks, esOscuro));
    widgets.add(SizedBox(height: r.spacingS));
    for (final item in d.tracks) {
      final src = item.source ?? '';
      final clave = 'track_${normalizarIdTrack(item.id)}_$src';
      void play() => sl<CubitCola>().reproducirConContexto(d.tracks, item);
      widgets.add(Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
        child: TarjetaTrack(
          titulo: item.name,
          subtitulo: artista.name,
          coverUrl: likedCubit.caratulaLocalPara(item),
          esAmado: likedCubit.estaAmado(item),
          readyKey: normalizarIdTrack(item.id),
          escalaTexto: 1.2,
          onLike: () => likedCubit.alternarLike(item),
          estadoDescarga: dlCubit.estadoDescargaPara(clave).estado,
          onDescargar: () => mostrarOpcionesDescarga(context, item, esOscuro),
          onBorrar: () => dlCubit.borrarDescargaTrack(item.id, src),
          onTap: play,
          onCompartir: () => SharePlus.instance.share(ShareParams(
                text: item.albumName != null
                    ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
                    : '🎵 ${item.name} — ${item.artists ?? ''}',
              )),
        ),
      ));
    }
  }

  // ── Top álbumes (grilla horizontal compartida) ──
  if (st._estaEnLinea && d.albums.isNotEmpty) {
    widgets.add(SizedBox(height: r.spacingM));
    widgets.add(_tituloSeccion(r, loc.setup.searchAlbums, esOscuro));
    widgets.add(SizedBox(height: r.spacingS));
    widgets.add(_grillaAlbumesArtista(st, context, d, likedCubit, dlCubit));
  }

  // ── Offline: banner + tracks descargados del artista ──
  if (!st._estaEnLinea && d.tracksOffline.isNotEmpty) {
    widgets.add(SizedBox(height: r.spacingM));
    widgets.add(Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      child: Row(children: [
        Icon(Icons.cloud_off,
            size: r.footerSize,
            color: colorSuperficie.withValues(alpha: 0.4)),
        SizedBox(width: 6),
        Text(
          '${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
          style: TextStyle(
              fontSize: r.footerSize,
              color: colorSuperficie.withValues(alpha: 0.4)),
        ),
      ]),
    ));
    widgets.add(SizedBox(height: r.spacingS));
    for (final item in d.tracksOffline) {
      final src = item.source ?? '';
      final clave = 'track_${normalizarIdTrack(item.id)}_$src';
      void play() =>
          sl<CubitCola>().reproducirConContexto(d.tracksOffline, item);
      widgets.add(Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.spacingS, vertical: r.spacingXS * 0.5),
        child: TarjetaTrack(
          titulo: item.name,
          subtitulo: item.artists ?? st.widget.artistName,
          coverUrl: likedCubit.caratulaLocalPara(item),
          esAmado: true,
          readyKey: normalizarIdTrack(item.id),
          escalaTexto: 1.2,
          onLike: () => likedCubit.alternarLike(item),
          estadoDescarga: dlCubit.estadoDescargaPara(clave).estado,
          onDescargar: () => mostrarOpcionesDescarga(context, item, esOscuro),
          onBorrar: () => dlCubit.borrarDescargaTrack(item.id, src),
          onTap: play,
          onCompartir: () => SharePlus.instance.share(ShareParams(
                text: item.albumName != null
                    ? '🎵 ${item.name} — ${item.artists ?? ''}\n💿 ${item.albumName}'
                    : '🎵 ${item.name} — ${item.artists ?? ''}',
              )),
        ),
      ));
    }
  }
  return widgets;
}

/// Título de sección reutilizado en tracks y álbumes.
Widget _tituloSeccion(Responsive r, String texto, bool esOscuro) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: r.spacingS),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: r.footerSize + 1,
        fontWeight: FontWeight.w700,
        color: ColoresApp.enSuperficie(esOscuro),
      ),
    ),
  );
}