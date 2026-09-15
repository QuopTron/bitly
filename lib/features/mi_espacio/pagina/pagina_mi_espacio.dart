// ─────────────────────────────────────────────────────────────
// pagina_mi_espacio.dart — Página de Mi Espacio: carga defensiva
// (username, playlists propias, contadores y stats), pestañas de
// biblioteca, banner de descargas interrumpidas y doble variante
// móvil/escritorio. Las acciones viven en _acciones.dart, el
// banner en _banner.dart y las piezas en _widgets/_helpers.
// Se conecta con: cubits + caches + l10n + deteccion_plataforma.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion.dart';
import '../../../core/cache/almacenes/cache_ajustes.dart';
import '../../../core/cache/almacenes/cache_descargas.dart';
import '../../../core/cache/estado/estado_descarga.dart';
import '../../../core/cache/reproduccion/reproduccion_stats.dart';
import '../../../core/modelos/feed/item_feed.dart';
import '../../../core/servicios/playlist/servicio_dominio_playlist.dart';
import '../../../estado/descargas/cubit_descargas.dart';
import '../../../estado/like/cubit_like.dart';
import '../../../estado/playlists/cubit_playlists.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utilidades/interaccion/acciones_item.dart';
import '../../../shared/utilidades/plataforma/deteccion_plataforma.dart';
import '../../../shared/utilidades/descarga/estrategia_descarga.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';
import '../../../core/cache/estado/estado_like.dart';
import '../../../core/servicios/utilidades/huella_item.dart';
import '../filtros/controles_orden_mi_espacio.dart';
import '../../../shared/widgets/vidrio/contenedor_vidrio.dart';
import '../../detalle/comun/navegador_detalle.dart';
import '../contenido/contenido_mi_espacio.dart';
import '../datos/datos_mi_espacio.dart';
import '../vistas/mi_espacio_escritorio.dart';
import '../vistas/mi_espacio_movil.dart';
import '../modelos_item.dart';
import '../perfil/perfil_mi_espacio.dart';
import '../vistas/pestanas_mi_espacio.dart';
import '../filtros/barra_busqueda_mi_espacio.dart';

part 'pagina_mi_espacio_acciones.dart';
part 'pagina_mi_espacio_banner.dart';
part 'pagina_mi_espacio_helpers.dart';
part 'pagina_mi_espacio_widgets.dart';
part 'pagina_mi_espacio_build.dart';
part 'pagina_mi_espacio_cuerpo.dart';
part 'pagina_mi_espacio_boton_busqueda.dart';

/// Página de Mi Espacio (biblioteca personal).
class PaginaMiEspacio extends StatefulWidget {
  const PaginaMiEspacio({super.key});

  @override
  State<PaginaMiEspacio> createState() => _PaginaMiEspacioState();
}

class _PaginaMiEspacioState extends State<PaginaMiEspacio> {
  String _username = '';
  bool _cargando = true;
  int _pestanaSeleccionada = 0;
  List<Item> _playlists = [];
  Map<String, int> _contadoresReproduccion = {};
  String _textoBusqueda = '';
  FiltrosMiEspacio _filtros = const FiltrosMiEspacio();
  bool _mostrarBusqueda = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cargando) _cargarInicial();
  }

  /// Carga defensiva: inicializa cubits (no-op si ya están cargados),
  /// username, playlists propias, contadores y stats.
  Future<void> _cargarInicial() async {
    unawaited(context.read<CubitLikes>().inicializar());
    unawaited(context.read<CubitDescargas>().initialize());
    unawaited(context.read<CubitPlaylists>().inicializar());
    final u = await cargarUsername();
    final p = await cargarPlaylistsPropias();
    await sl<CubitPlaylists>().cargarStats();
    Map<String, int> contadores = {};
    try {
      final top = await sl<ReproduccionStats>().getTopTracksConNombres(100);
      for (final t in top) {
        final id = t['trackId'];
        if (id != null) contadores[id as String] = (t['count'] as int?) ?? 0;
      }
    } catch (e) { debugPrint("[Feature] $e"); }
    if (mounted) {
      setState(() {
        _username = u;
        _playlists = p;
        _contadoresReproduccion = contadores;
        _cargando = false;
      });
    }
  }

  void _onCambioPestana(int i) {
    setState(() => _pestanaSeleccionada = i);
    // Recargar playlists creadas al volver al tab de playlists.
    if (i == 1) _recargarPlaylists();
  }

  void _aplicar(VoidCallback fn) => setState(fn);

  void _onBusquedaCambiada(String q) {
    setState(() => _textoBusqueda = q);
  }

  void _onFiltrosCambiados(FiltrosMiEspacio f) {
    setState(() => _filtros = f);
  }

  /// Recarga las playlists propias desde drift y repinta.
  Future<void> _recargarPlaylists() async {
    final p = await cargarPlaylistsPropias();
    if (mounted) setState(() => _playlists = p);
  }

  @override
  Widget build(BuildContext context) => _construirPaginaMiEspacio(this);


  /// Abre el detalle según el tipo de ítem (via navegador de detalle).
  void _onItemTap(Item item) {
    if (item.idReal.isEmpty) return;
    final src = _resolverFuente(this, item);
    switch (item.tipo) {
      case TipoItem.album:
        abrirDetalleAlbum(context, id: item.idReal, fuente: src);
      case TipoItem.playlist:
        abrirDetallePlaylist(
          context,
          id: item.idReal,
          nombre: item.titulo,
          fuente: src,
        );
      case TipoItem.artista:
        abrirDetalleArtista(context, id: item.idReal, nombre: item.titulo);
      case TipoItem.cancion:
        mostrarInfoCancionDesdeMiEspacio(context, item);
    }
  }
}