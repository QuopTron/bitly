// Página de detalle de artista: carga (memoria→local→API), cabecera
// con imagen/reproducir, top tracks, top álbumes (grilla horizontal)
// y tracks descargados offline del artista.
// Parts: _carga, _calculos, _acciones, _contenido, _estados.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/cache_detalle.dart';
import '../../core/cache/cache_detalle_memoria.dart';
import '../../core/cache/reproduccion_detalle_local.dart';
import '../../core/cache/reproduccion_sync.dart';
import '../../core/modelos/detalle_artista.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/plataforma/servicio_conectividad.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_reproductor.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/utilidades/acciones_item.dart';
import '../../shared/utilidades/estrategia_descarga.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/boton_accion_vidrio.dart';
import '../../shared/widgets/hoja_opciones_descarga.dart';
import '../../shared/widgets/tarjeta_grilla.dart';
import '../../shared/widgets/tarjeta_track.dart';
import 'cabecera_detalle.dart';
import 'esqueleto_detalle.dart';
import 'navegador_detalle.dart';

part 'artista_detalle_albumes.dart';
part 'artista_detalle_carga.dart';
part 'artista_detalle_calculos.dart';
part 'artista_detalle_acciones.dart';
part 'artista_detalle_contenido.dart';
part 'artista_detalle_estados.dart';

/// Datos calculados de la vista de artista (compartidos entre parts).
typedef DatosVistaArtista = ({
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
          body: const EsqueletoDetalle());
    }
    if (_artista == null) {
      return Scaffold(
          backgroundColor: colorFondo,
          appBar: AppBar(title: Text(loc.setup.searchArtists)),
          body: _estadoVacioArtista(this, context));
    }

    final artista = _artista!;
    final likedCubit = context.watch<CubitLikes>();
    final dlCubit = context.watch<CubitDescargas>();
    final datos = _calcularDatosArtista(
        this, context, artista, likedCubit, dlCubit);

    // Pre-calentar streams de los primeros tracks visibles.
    if (!_precacheado && datos.tracks.isNotEmpty) {
      _precacheado = true;
      sl<CubitReproductor>().precachearContexto(datos.tracks, limit: 3);
    }

    return Scaffold(
      backgroundColor: colorFondo,
      body: CabeceraDetalle(
        coverUrl: datos.imagen,
        titulo: artista.name,
        subtitulo: datos.subtitulo,
        heroTag: 'artist_${artista.id}',
        tamanoPortada: 160,
        acciones: _filaAccionesArtista(this, context, datos),
        children: _construirContenidoArtista(
            this, context, datos, artista, likedCubit, dlCubit),
      ),
    );
  }
}