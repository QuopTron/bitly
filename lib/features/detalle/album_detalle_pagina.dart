// ─────────────────────────────────────────────────────────────
// Página de detalle de álbum: carga (memoria→local→API→lote), cabecera
// con like/descargar/reproducir y lista de tracks.
// Parts: _carga, _lote, _calculos, _acciones, _contenido, _estados.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/cache/cache_descargas.dart';
import '../../core/cache/cache_detalle.dart';
import '../../core/cache/cache_detalle_memoria.dart';
import '../../core/cache/estado_descarga.dart';
import '../../core/cache/reproduccion_detalle_local.dart';
import '../../core/modelos/detalle_album.dart';
import '../../core/modelos/detalle_track.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/plataforma/servicio_conectividad.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_reproductor.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/estrategia_descarga.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/boton_accion_vidrio.dart';
import '../../shared/widgets/hoja_opciones_descarga.dart';
import '../../shared/widgets/tarjeta_track.dart';
import 'cabecera_detalle.dart';
import 'esqueleto_detalle.dart';

part 'album_detalle_carga.dart';
part 'album_detalle_calculos.dart';
part 'album_detalle_acciones.dart';
part 'album_detalle_contenido.dart';
part 'album_detalle_estados.dart';
part 'album_detalle_lote.dart';

/// Datos calculados de la vista de álbum (compartidos entre parts).
typedef DatosVistaAlbum = ({
  String src,
  EstadoDescarga estadoLote,
  int descargados,
  int total,
  bool todosDescargados,
  String? caratula,
  List<ItemFeed> items,
});

/// Detalle de álbum: id, fuente y carátula opcional de entrada.
class AlbumDetallePagina extends StatefulWidget {
  final String albumId;
  final String source;
  final String? coverUrl;

  const AlbumDetallePagina({
    super.key,
    required this.albumId,
    this.source = '',
    this.coverUrl,
  });

  @override
  State<AlbumDetallePagina> createState() => _AlbumDetallePaginaState();
}

class _AlbumDetallePaginaState extends State<AlbumDetallePagina> {
  DetalleAlbum? _album;
  bool _cargando = true;
  bool _error = false;
  bool _estaEnLinea = true;
  bool _precacheado = false;
  String? _caratulaAlbumResuelta;

  @override
  void initState() {
    super.initState();
    _cargarDetalleAlbum(this);
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
        appBar: AppBar(title: Text(loc.setup.searchAlbums)),
        body: const EsqueletoDetalle(),
      );
    }
    if (_album == null) {
      return Scaffold(
        backgroundColor: colorFondo,
        appBar: AppBar(title: Text(loc.setup.searchAlbums)),
        body: _estadoVacio(this, context),
      );
    }

    final album = _album!;
    final likedCubit = context.watch<CubitLikes>();
    final dlCubit = context.watch<CubitDescargas>();
    final datos = _calcularDatosVista(this, context, album, likedCubit, dlCubit);
    _caratulaAlbumResuelta = datos.caratula;

    // Pre-calentar streams de los primeros tracks visibles (arranque rápido).
    if (!_precacheado && datos.items.isNotEmpty) {
      _precacheado = true;
      sl<CubitReproductor>().precachearContexto(datos.items, limit: 3);
    }

    final esAlbumAmado = likedCubit.estaAmado(ItemFeed(
      id: album.id,
      type: 'album',
      name: album.name,
      artists: album.artistName,
      coverUrl: datos.caratula,
    ));

    return Scaffold(
      backgroundColor: colorFondo,
      body: CabeceraDetalle(
        coverUrl: datos.caratula,
        titulo: album.name,
        subtitulo: album.artistName ?? '',
        heroTag: 'album_${album.id}',
        badge: _construirBadge(datos, album, loc),
        acciones: _filaAcciones(
          this, context, datos, album, esAlbumAmado, likedCubit,
        ),
        children: _construirContenido(
          this, context, datos, album, likedCubit, dlCubit,
        ),
      ),
    );
  }
}