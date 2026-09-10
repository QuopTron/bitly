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

import '../../app/inyeccion.dart';
import '../../core/cache/cache_ajustes.dart';
import '../../core/cache/cache_descargas.dart';
import '../../core/cache/estado_descarga.dart';
import '../../core/cache/reproduccion_stats.dart';
import '../../core/modelos/item_feed.dart';
import '../../core/servicios/servicio_dominio_playlist.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_playlists.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utilidades/acciones_item.dart';
import '../../shared/utilidades/deteccion_plataforma.dart';
import '../../shared/utilidades/estrategia_descarga.dart';
import '../../shared/utilidades/responsive.dart';
import '../../shared/widgets/contenedor_vidrio.dart';
import '../detalle/navegador_detalle.dart';
import 'contenido_mi_espacio.dart';
import 'datos_mi_espacio.dart';
import 'mi_espacio_escritorio.dart';
import 'mi_espacio_movil.dart';
import 'modelos_item.dart';
import 'perfil_mi_espacio.dart';
import 'pestanas_mi_espacio.dart';

part 'pagina_mi_espacio_acciones.dart';
part 'pagina_mi_espacio_banner.dart';
part 'pagina_mi_espacio_helpers.dart';
part 'pagina_mi_espacio_widgets.dart';

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
    } catch (_) {}
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

  /// Recarga las playlists propias desde drift y repinta.
  Future<void> _recargarPlaylists() async {
    final p = await cargarPlaylistsPropias();
    if (mounted) setState(() => _playlists = p);
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final onBg = esOscuro ? Colors.white : Colors.black;

    final estadoDl = context.watch<CubitDescargas>().state;
    final interrumpidas = estadoDl.descargas.values
        .where((d) => d.estado == EstadoDescarga.interrumpido)
        .length;
    final hayLotesReintentables = estadoDl.descargas.entries.any(
      (e) =>
          e.value.estado == EstadoDescarga.interrumpido &&
          (e.key.startsWith('album_') || e.key.startsWith('playlist_')),
    );

    final cabecera =
        _construirCabecera(this, onBg, hayLotesReintentables, interrumpidas);
    final cuerpo = _construirCuerpo(this, onBg);

    if (usarLayoutEscritorio(context)) {
      return MiEspacioEscritorio(cabecera: cabecera, cuerpo: cuerpo);
    }
    return MiEspacioMovil(cabecera: cabecera, cuerpo: cuerpo);
  }

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