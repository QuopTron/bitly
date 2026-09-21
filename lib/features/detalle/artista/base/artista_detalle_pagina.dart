// Página de detalle de artista: carga (memoria→local→API), cabecera
// con imagen/reproducir, top tracks, top álbumes (grilla horizontal)
// y tracks descargados offline del artista.
// Parts: _carga, _calculos, _acciones, _contenido, _estados.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/inyeccion/inyeccion.dart';
import '../../../../core/backend_go/nucleo/base/contrato_backend.dart';
import '../../../../core/cache/almacenes/musica/cache_detalle.dart';
import '../../../../core/cache/almacenes/musica/cache_detalle_memoria.dart';
import '../../../../core/cache/reproduccion/detalle/reproduccion_detalle_local.dart';
import '../../../../core/cache/reproduccion/base/reproduccion_sync.dart';
import '../../../../core/modelos/detalle/contenido/detalle_artista.dart';
import '../../../../core/modelos/feed/item_feed.dart';
import '../../../../core/plataforma/red/servicio_conectividad.dart';
import '../../../../estado/cola/cubit_cola.dart';
import '../../../../estado/descargas/cubit_descargas.dart';
import '../../../../estado/like/base/cubit_like.dart';
import '../../../../estado/reproductor/cubit_reproductor.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/interaccion/acciones_item.dart';
import '../../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../../shared/utilidades/plataforma/responsive.dart';
import '../../../../shared/widgets/vidrio/botones/boton_accion_vidrio.dart';
import '../../../../shared/widgets/modales/descarga/base/hoja_opciones_descarga.dart';
import '../../../../shared/widgets/tarjetas/grilla/base/tarjeta_grilla.dart';
import '../../../../shared/widgets/tarjetas/track/base/tarjeta_track.dart';
import '../../comun/cabecera/cabecera_detalle.dart';
import '../../comun/vistas/detalle_tv.dart';
import '../../comun/base/esqueleto_detalle.dart';
import '../../comun/base/navegador_detalle.dart';
import '../../../../core/servicios/compartir/base/servicio_compartir.dart';
import '../../../../shared/utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart';
import '../../../../shared/tema/especificaciones/especificaciones_plataforma.dart';

part '../acciones/artista_detalle_albumes.dart';
part 'artista_detalle_carga.dart';
part 'artista_detalle_calculos.dart';
part '../acciones/artista_detalle_acciones.dart';
part '../contenido/artista_detalle_contenido.dart';
part '../contenido/artista_detalle_estados.dart';

/// Datos calculados de la vista de artista (compartidos entre parts).
typedef DatosVistaArtista =
    ({
      String? imagen,
      String subtitulo,
      List<ItemFeed> tracks,
      List<ItemFeed> albums,
      List<ItemFeed> tracksOffline,
    });

/// Detalle de artista: id, nombre y fuente de entrada.
class ArtistaDetallePagina extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String source;

  const ArtistaDetallePagina({
    super.key,
    required this.artistId,
    this.artistName = '',
    this.source = '',
  });

  @override
  State<ArtistaDetallePagina> createState() => _ArtistaDetallePaginaState();
}

class _ArtistaDetallePaginaState extends State<ArtistaDetallePagina> {
  DetalleArtista? _artista;
  bool _cargando = true;
  bool _error = false;
  bool _estaEnLinea = true;
  bool _precacheado = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalleArtista(this);
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
        appBar: AppBar(title: Text(loc.setup.searchArtists)),
        body: const EsqueletoDetalle(),
      );
    }
    if (_artista == null) {
      return Scaffold(
        backgroundColor: colorFondo,
        appBar: AppBar(title: Text(loc.setup.searchArtists)),
        body: _estadoVacioArtista(this, context),
      );
    }

    final artista = _artista!;
    final likedCubit = context.watch<CubitLikes>();
    final dlCubit = context.watch<CubitDescargas>();
    final datos = _calcularDatosArtista(
      this,
      context,
      artista,
      likedCubit,
      dlCubit,
    );

    // Pre-calentar streams de los primeros tracks visibles.
    if (!_precacheado && datos.tracks.isNotEmpty) {
      _precacheado = true;
      sl<CubitReproductor>().precachearContexto(datos.tracks, limit: 3);
    }

    // Las piezas se arman UNA vez: la variante de TV (detalle_tv) las ordena en
    // dos columnas y la de celular/PC en su cabecera de siempre.
    final acciones = _filaAccionesArtista(this, context, datos);
    final hijos = _construirContenidoArtista(
      this,
      context,
      datos,
      artista,
      likedCubit,
      dlCubit,
    );

    if (usarLayoutTv(context)) {
      return DetalleTv(
        coverUrl: datos.imagen,
        titulo: artista.name,
        subtitulo: datos.subtitulo,
        heroTag: 'artist_${artista.id}',
        acciones: acciones,
        children: hijos,
      );
    }

    return Scaffold(
      backgroundColor: colorFondo,
      body: CabeceraDetalle(
        coverUrl: datos.imagen,
        titulo: artista.name,
        subtitulo: datos.subtitulo,
        heroTag: 'artist_${artista.id}',
        tamanoPortada: 160,
        acciones: acciones,
        children: hijos,
      ),
    );
  }
}
