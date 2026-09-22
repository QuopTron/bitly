// ─────────────────────────────────────────────────────────────
// artista_detalle_contenido.dart — PART de artista_detalle_pagina.dart:
// children de la cabecera — top tracks (lista con like/descarga/
// reproducir), top álbumes (grilla horizontal compartida) y tracks
// offline (likes del artista) con banner de solo-descargados.
// Se conecta con: artista_detalle_pagina.dart (misma library) +
// tarjeta_track + tarjeta_grilla + acciones_item.
// Parte del flujo: Detalle → artista (contenido).
// ─────────────────────────────────────────────────────────────

part of '../base/artista_detalle_pagina.dart';

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
    // Cada fila resuelve su carátula/like/descarga en SU build (ver
    // FilaTrackDetalle): abrir un artista con muchos tracks no paga el trabajo
    // de todos de golpe.
    for (final item in d.tracks) {
      widgets.add(
        FilaTrackDetalle(
          key: ValueKey('ar_${item.id}'),
          item: item,
          contexto: d.tracks,
          subtitulo: artista.name,
        ),
      );
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
    widgets.add(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spacingS),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off,
              size: r.footerSize,
              color: colorSuperficie.withValues(alpha: 0.4),
            ),
            SizedBox(width: 6),
            Text(
              '${loc.setup.downloaded} ${loc.setup.miSpaceSongs.toLowerCase()}',
              style: TextStyle(
                fontSize: r.footerSize,
                color: colorSuperficie.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
    widgets.add(SizedBox(height: r.spacingS));
    for (final item in d.tracksOffline) {
      widgets.add(
        FilaTrackDetalle(
          key: ValueKey('aroff_${item.id}'),
          item: item,
          contexto: d.tracksOffline,
          subtitulo: item.artists ?? st.widget.artistName,
          forzarAmado: true,
        ),
      );
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
