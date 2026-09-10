// ─────────────────────────────────────────────────────────────
// navegador_detalle.dart — Punto ÚNICO de navegación a las páginas
// de detalle (álbum/playlist/artista) desde cualquier vista
// (Feed, Búsqueda, Mi Espacio) con la transición compartida.
// Se conecta con: transiciones_pagina + páginas de detalle reales
// (album/playlist/artista) + vistas que navegan a detalle.
// Parte del flujo: navegación a detalle (feed/busqueda/mi_espacio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_playlists.dart';
import '../../estado/cubit_reproductor.dart';
import '../../shared/widgets/transiciones_pagina.dart';
import 'album_detalle_pagina.dart';
import 'artista_detalle_pagina.dart';
import 'playlist_detalle_pagina.dart';

/// Envuelve las páginas de detalle con los cubits globales: el push va al
/// Navigator raíz (fuera del árbol de la Home) y sin esto las páginas
/// lanzan "Provider not found" (pantalla roja) al usar likes/descargas/cola.
Widget _envolverDetalle(Widget pagina) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<CubitCola>.value(value: sl<CubitCola>()),
      BlocProvider<CubitLikes>.value(value: sl<CubitLikes>()),
      BlocProvider<CubitDescargas>.value(value: sl<CubitDescargas>()),
      BlocProvider<CubitPlaylists>.value(value: sl<CubitPlaylists>()),
      BlocProvider<CubitReproductor>.value(value: sl<CubitReproductor>()),
    ],
    child: pagina,
  );
}

/// Abre el detalle de álbum.
void abrirDetalleAlbum(
  BuildContext context, {
  required String id,
  required String fuente,
  String? coverUrl,
}) {
  Navigator.push(
    context,
    RutaDesvanecerSubir(
      pagina: _envolverDetalle(AlbumDetallePagina(
        albumId: id,
        source: fuente,
        coverUrl: coverUrl,
      )),
    ),
  );
}

/// Abre el detalle de playlist.
void abrirDetallePlaylist(
  BuildContext context, {
  required String id,
  required String nombre,
  required String fuente,
  String? coverUrl,
}) {
  Navigator.push(
    context,
    RutaDesvanecerSubir(
      pagina: _envolverDetalle(PlaylistDetallePagina(
        collectionId: id,
        playlistName: nombre,
        source: fuente,
        coverUrl: coverUrl,
      )),
    ),
  );
}

/// Abre el detalle de artista.
void abrirDetalleArtista(
  BuildContext context, {
  required String id,
  required String nombre,
  String? fuente,
}) {
  Navigator.push(
    context,
    RutaDesvanecerSubir(
      pagina: _envolverDetalle(ArtistaDetallePagina(
        artistId: id,
        artistName: nombre,
        source: fuente ?? '',
      )),
    ),
  );
}

/// Muestra la hoja de info de canción desde Mi Espacio.
void mostrarInfoCancionDesdeMiEspacio(BuildContext context, dynamic item) {
  // La hoja de info de canción se migra con el reproductor; por ahora
  // queda sin acción (el tap de info usa AccionesItem.mostrarInfo).
  assert(item != null);
}