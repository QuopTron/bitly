// ─────────────────────────────────────────────────────────────
// artista_detalle_albumes.dart — PART de artista_detalle_pagina.dart:
// grilla horizontal de los top álbumes del artista usando la tarjeta
// compartida (TarjetaGrilla): like, estado/descarga de lote y tap
// que navega al detalle del álbum.
// Se conecta con: artista_detalle_pagina.dart (misma library) +
// tarjeta_grilla + acciones_item + navegador_detalle.
// Parte del flujo: Detalle → artista (álbumes).
// ─────────────────────────────────────────────────────────────

part of 'artista_detalle_pagina.dart';

/// Grilla horizontal de top álbumes con acciones y navegación.
Widget _grillaAlbumesArtista(
  _ArtistaDetallePaginaState st,
  BuildContext context,
  DatosVistaArtista d,
  CubitLikes likedCubit,
  CubitDescargas dlCubit,
) {
  final r = Responsive(context);
  return SizedBox(
    height: 212,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: r.spacingS),
      itemCount: d.albums.length,
      separatorBuilder: (_, _) => SizedBox(width: r.spacingXS),
      itemBuilder: (_, i) {
        final item = d.albums[i];
        final clave =
            'album_${normalizarIdTrack(item.id)}_${item.source ?? ''}';
        return SizedBox(
          width: 150,
          height: 212,
          child: TarjetaGrilla(
            tipo: 'album',
            titulo: item.name,
            subtitulo: st.widget.artistName,
            coverUrl: likedCubit.caratulaLocalPara(item),
            esAmado: likedCubit.estaAmado(item),
            escalaTexto: 1.2,
            onLike: () => likedCubit.alternarLike(item),
            estadoDescarga: dlCubit.estadoDescargaPara(clave).estado,
            onDescargar: () => AccionesItem.iniciarDescargaLote(context, item),
            onBorrar: () => AccionesItem.borrarLote(context, item),
            mostrarTerceraAccion: false,
            onTap: () => abrirDetalleAlbum(context,
                id: item.id, fuente: item.source ?? ''),
          ),
        );
      },
    ),
  );
}