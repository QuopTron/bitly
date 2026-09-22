// Página de detalle de playlist: carga (memoria→local→API→lote),
// cabecera con like/descargar/reproducir/exportar y tracks.
// Parts: _batch, _carga, _lote, _calculos, _acciones, _contenido, _estados.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/backend_go/nucleo/base/contrato_backend.dart';
import '../../../../core/cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../core/cache/almacenes/descargas/cache_descargas.dart';
import '../../../../core/cache/almacenes/musica/cache_detalle.dart';
import '../../../../core/cache/almacenes/musica/cache_detalle_memoria.dart';
import '../../../../core/cache/estado/estado_descarga.dart';
import '../../../../core/cache/reproduccion/detalle/reproduccion_detalle_local.dart';
import '../../../../core/cache/reproduccion/base/reproduccion_sync.dart';
import '../../../../core/modelos/detalle/contenido/detalle_playlist.dart';
import '../../../../core/modelos/detalle/base/detalle_track.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/plataforma/red/servicio_conectividad.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../estado/descargas/cubit_descargas.dart';
import '../../../../estado/like/base/cubit_like.dart';
import '../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../../../shared/utilidades/descarga/exportacion_playlist_ui.dart';
import '../../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/utilidades/portada/base/caratula_util.dart';
import '../../../../shared/widgets/vidrio/botones/boton_accion_vidrio.dart';
import '../../../../shared/utilidades/modales/mostrar_modal.dart';
import '../../../../shared/widgets/modales/descarga/base/hoja_opciones_descarga.dart';
import '../../../../shared/widgets/modales/playlist/base/hoja_playlist.dart';
import '../../comun/cabecera/cabecera_detalle.dart';
import '../../comun/piezas/fila_track_detalle.dart';
import '../../comun/vistas/detalle_tv.dart';
import '../../comun/base/esqueleto_detalle.dart';
import '../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';

part '../acciones/playlist_detalle_batch.dart';
part 'playlist_detalle_carga.dart';
part 'playlist_detalle_calculos.dart';
part '../acciones/playlist_detalle_acciones.dart';
part '../contenido/playlist_detalle_contenido.dart';
part '../contenido/playlist_detalle_estados.dart';
part '../acciones/playlist_detalle_lote.dart';

/// Datos calculados de la vista de playlist (compartidos entre parts).
typedef DatosVistaPlaylist =
    ({
      String src,
      EstadoDescarga estadoLote,
      int descargados,
      int total,
      bool todosDescargados,
      bool hayArchivosLocales,
      String? caratula,
      List<ItemFeed> items,
    });

/// Detalle de playlist: id, nombre, fuente y carátula opcional.
class PlaylistDetallePagina extends StatefulWidget {
  final String collectionId;
  final String playlistName;
  final String source;
  final String? coverUrl;

  const PlaylistDetallePagina({
    super.key,
    required this.collectionId,
    this.playlistName = '',
    this.source = '',
    this.coverUrl,
  });

  @override
  State<PlaylistDetallePagina> createState() => _PlaylistDetallePaginaState();
}

class _PlaylistDetallePaginaState extends State<PlaylistDetallePagina> {
  DetallePlaylist? _playlist;
  bool _cargando = true;
  bool _error = false;
  bool _estaEnLinea = true;
  bool _precacheado = false;
  String? _caratulaResuelta;

  @override
  void initState() {
    super.initState();
    _cargarDetallePlaylist(this);
  }

  /// Repinta la página tras mutar campos desde los parts de carga.
  void repintar() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final colorFondo = ColoresApp.fondo(esOscuro);
    final loc = AppLocalizations.of(context);

    if (_cargando) {
      return Scaffold(
        backgroundColor: colorFondo,
        appBar: AppBar(title: Text(loc.setup.searchPlaylists)),
        body: const EsqueletoDetalle(),
      );
    }
    if (_playlist == null) {
      return Scaffold(
        backgroundColor: colorFondo,
        appBar: AppBar(title: Text(loc.setup.searchPlaylists)),
        body: _estadoVacioPlaylist(this, context),
      );
    }

    final playlist = _playlist!;
    final likedCubit = context.watch<CubitLikes>();
    final dlCubit = context.watch<CubitDescargas>();
    final datos = _calcularDatosPlaylist(
      this,
      context,
      playlist,
      likedCubit,
      dlCubit,
    );
    _caratulaResuelta = datos.caratula;

    // Pre-calentar streams de los primeros tracks visibles (arranque rápido).
    if (!_precacheado && datos.items.isNotEmpty) {
      _precacheado = true;
      sl<CubitReproductor>().precachearContexto(datos.items, limit: 3);
    }

    final esPlaylistAmada = likedCubit.estaAmado(
      ItemFeed(
        id: playlist.id,
        type: 'playlist',
        name: playlist.name,
        coverUrl: datos.caratula,
      ),
    );

    // Las piezas se arman UNA vez: la variante de TV (detalle_tv) las ordena en
    // dos columnas y la de celular/PC en su cabecera de siempre.
    final badge = _construirBadgePlaylist(datos, playlist, loc);
    final acciones = _filaAccionesPlaylist(
      this,
      context,
      datos,
      playlist,
      esPlaylistAmada,
      likedCubit,
    );
    final hijos = _construirContenidoPlaylist(
      this,
      context,
      datos,
      playlist,
      likedCubit,
      dlCubit,
    );

    if (usarLayoutTv(context)) {
      return DetalleTv(
        coverUrl: datos.caratula,
        titulo: playlist.name,
        subtitulo: '',
        heroTag: 'playlist_${playlist.id}',
        badge: badge,
        acciones: acciones,
        children: hijos,
      );
    }

    return Scaffold(
      backgroundColor: colorFondo,
      body: CabeceraDetalle(
        coverUrl: datos.caratula,
        titulo: playlist.name,
        subtitulo: '',
        heroTag: 'playlist_${playlist.id}',
        badge: badge,
        acciones: acciones,
        children: hijos,
      ),
    );
  }
}
