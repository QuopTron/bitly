// ─────────────────────────────────────────────────────────────
// ensamblador_home.dart — Ensamblador de la Home: crea los blocs
// de Búsqueda y Feed (con el backend Go), provee los cubits
// globales en el árbol y construye los 4 slots del shell —
// buscador (PaginaBusqueda), feed (PaginaFeed), miEspacio y
// miniplayer (placeholders hasta migrarlos). Dispara CargarFeed al
// montarse.
// Se conecta con: busqueda_bloc + feed_bloc + cubits (cola, likes,
// descargas, playlists) + pagina_home + placeholders.
// Parte del flujo: Home (ruta '/home' tras el splash/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/cache_busqueda.dart';
import '../../core/servicios/servicio_verificacion.dart';
import '../../core/modelos/item_feed.dart';
import '../../estado/cubit_cola.dart';
import '../../estado/cubit_descargas.dart';
import '../../estado/cubit_like.dart';
import '../../estado/cubit_playlists.dart';
import '../../estado/cubit_reproductor.dart';
import '../busqueda/bloc/busqueda_bloc.dart';
import '../busqueda/pagina_busqueda.dart';
import '../feed/bloc/feed_bloc.dart';
import '../feed/bloc/feed_evento.dart';
import '../feed/feed_pagina.dart';
import '../detalle/navegador_detalle.dart';
import '../mi_espacio/pagina_mi_espacio.dart';
import '../reproductor/reproductor_pagina.dart';
import '../../shared/widgets/miniplayer.dart';
import '../../shared/widgets/transiciones_pagina.dart';
import 'pagina_home.dart';

/// Ensambla la Home: blocs + cubits + slots → shell.
class EnsambladorHome extends StatefulWidget {
  const EnsambladorHome({super.key});

  @override
  State<EnsambladorHome> createState() => _EnsambladorHomeState();
}

class _EnsambladorHomeState extends State<EnsambladorHome> {
  late final BlocBusqueda _blocBusqueda;
  late final BlocFeed _blocFeed;

  @override
  void initState() {
    super.initState();
    final backend = sl<BackendService>();
    _blocBusqueda = BlocBusqueda(backend, sl<CacheBusqueda>());
    _blocFeed = BlocFeed(backend)..add(const CargarFeed());
    _provisionarSesionesAlArrancar();
  }

  /// Provisiona las sesiones firmadas en segundo plano (post-frame, sin
  /// bloquear la UI) y corre SOLO intentos silenciosos: cada fuente pendiente
  /// se intenta en el WebView oculto (Turnstile managed auto-pasa sin mostrar
  /// nada cuando Cloudflare lo permite). NUNCA abre un modal al arrancar — los
  /// challenges que exigen interacción humana se resuelven bajo demanda cuando
  /// el usuario realmente usa esa fuente (descarga/reproducción/búsqueda).
  Future<void> _provisionarSesionesAlArrancar() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final servicio = ServicioVerificacion();
    try {
      await servicio.provisionarSesionesFirmadas();
      await servicio.reintentarPendientesSilencioso();
    } catch (_) {
      // El provision/reintento nunca debe romper la Home.
    }
  }

  /// Navega al detalle según el tipo del ítem (track → artist/album).
  void _navegarItem(BuildContext context, ItemFeed item) {
    final fuente = item.source ?? '';
    switch (item.type) {
      case 'album':
        abrirDetalleAlbum(context,
            id: item.id, fuente: fuente, coverUrl: item.coverUrl);
      case 'playlist':
        abrirDetallePlaylist(context,
            id: item.id, nombre: item.name, fuente: fuente,
            coverUrl: item.coverUrl);
      case 'artist':
        abrirDetalleArtista(context,
            id: item.id, nombre: item.name, fuente: fuente);
      default:
        // Los tracks navegan a su álbum si lo tienen, o no hacen nada.
        if (item.albumId != null && item.albumId!.isNotEmpty) {
          abrirDetalleAlbum(context,
              id: item.albumId!, fuente: fuente, coverUrl: item.coverUrl);
        }
    }
  }

  /// Abre el reproductor completo con la transición slide-up compartida.
  void _abrirReproductor(BuildContext context) {
    Navigator.push(
      context,
      RutaDeslizarArriba(pagina: const ReproductorPagina()),
    );
  }

  @override
  void dispose() {
    _blocBusqueda.close();
    _blocFeed.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cola = sl<CubitCola>();
    final likes = sl<CubitLikes>();
    final descargas = sl<CubitDescargas>();
    final playlists = sl<CubitPlaylists>();
    final reproductor = sl<CubitReproductor>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<CubitCola>.value(value: cola),
        BlocProvider<CubitLikes>.value(value: likes),
        BlocProvider<CubitDescargas>.value(value: descargas),
        BlocProvider<CubitPlaylists>.value(value: playlists),
        BlocProvider<CubitReproductor>.value(value: reproductor),
        BlocProvider<BlocBusqueda>.value(value: _blocBusqueda),
        BlocProvider<BlocFeed>.value(value: _blocFeed),
      ],
      child: PaginaHome(
        buscador: PaginaBusqueda(
          onNavegarItem: (item) => _navegarItem(context, item),
        ),
        feed: PaginaFeed(
          onNavegarItem: (item) => _navegarItem(context, item),
        ),
        miEspacio: const PaginaMiEspacio(), // real migrado
        miniPlayer: Miniplayer(
          onAbrirReproductor: () => _abrirReproductor(context),
        ),
      ),
    );
  }
}