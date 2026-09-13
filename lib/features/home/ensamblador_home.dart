// ensamblador_home.dart — Ensamblador de la Home: crea los blocs
// de Búsqueda y Feed (con el backend Go), provee los cubits
// globales en el árbol y construye los 4 slots del shell —
// buscador (PaginaBusqueda), feed (PaginaFeed), miEspacio y
// miniplayer. Dispara CargarFeed al montarse. Inyecta el
// TutorialController y muestra el overlay interactivo post-setup.
// Se conecta con: busqueda_bloc + feed_bloc + cubits (cola, likes,
// descargas, playlists) + pagina_home + tutorial_interactivo.
// Parte del flujo: Home (ruta '/home' tras el splash/setup).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/inyeccion.dart';
import '../../core/backend_go/contrato_backend.dart';
import '../../core/cache/almacenes/cache_busqueda.dart';
import '../../core/plataforma/servicio_calidad_red.dart';
import '../../core/servicios/verificacion/servicio_verificacion.dart';
import '../../core/modelos/feed/item_feed.dart';
import '../../estado/cola/cubit_cola.dart';
import '../../estado/descargas/cubit_descargas.dart';
import '../../estado/like/cubit_like.dart';
import '../../estado/playlists/cubit_playlists.dart';
import '../../estado/reproductor/cubit_reproductor.dart';
import '../busqueda/bloc/busqueda_bloc.dart';
import '../busqueda/pagina_busqueda.dart';
import '../feed/bloc/feed_bloc.dart';
import '../feed/bloc/feed_evento.dart';
import '../feed/feed_pagina.dart';
import '../detalle/navegador_detalle.dart';
import '../mi_espacio/pagina/pagina_mi_espacio.dart';
import '../reproductor/reproductor_pagina.dart';
import '../../shared/widgets/reproductor/miniplayer.dart';
import '../../shared/widgets/base/transiciones_pagina.dart';
import '../../l10n/app_localizations.dart';
import '../tutorial_interactivo/tutorial_controller.dart';
import '../tutorial_interactivo/tutorial_host.dart';
import '../tutorial_interactivo/tutorial_pasos.dart';
import 'pagina_home.dart';

/// InheritedProvider para que el TutorialController sea accesible
/// desde cualquier parte del árbol de widgets.
class TutorialProvider extends InheritedNotifier<TutorialController> {
  const TutorialProvider({
    super.key,
    required TutorialController controller,
    required super.child,
  }) : super(notifier: controller);

  static TutorialController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TutorialProvider>()!
        .notifier!;
  }

  /// Igual que [of] pero devuelve null si no hay provider arriba: útil para
  /// widgets que también se usan sueltos (tests, previews).
  static TutorialController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TutorialProvider>()
        ?.notifier;
  }
}

/// Ensambla la Home: blocs + cubits + slots → shell.
class EnsambladorHome extends StatefulWidget {
  const EnsambladorHome({super.key});

  @override
  State<EnsambladorHome> createState() => _EnsambladorHomeState();
}

class _EnsambladorHomeState extends State<EnsambladorHome> {
  late final BlocBusqueda _blocBusqueda;
  late final BlocFeed _blocFeed;
  late final TutorialController _tutorialCtrl;

  /// El tutorial se arma una sola vez, cuando ya hay contexto.
  bool _tutorialArmado = false;

  @override
  void initState() {
    super.initState();
    final backend = sl<BackendService>();
    _blocBusqueda = BlocBusqueda(backend, sl<CacheBusqueda>());
    _blocFeed = BlocFeed(backend)..add(const CargarFeed());
    ServicioCalidadRed.instancia.iniciar();
    _provisionarSesionesAlArrancar();
    _tutorialCtrl = TutorialController();
  }

  // Los textos del tutorial salen del locale, y el locale recién está
  // disponible acá: leerlo en initState con Localizations.localeOf(context)
  // dispara la assertion de dependencia-de-inherited-antes-de-initState.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tutorialArmado) return;
    _tutorialArmado = true;
    _inicializarTutorial();
  }

  Future<void> _inicializarTutorial() async {
    // Los textos salen del locale (una lista, en el mismo orden que los
    // pasos) y los widgets objetivo se resuelven por GlobalKey.
    final loc = AppLocalizations.of(context);
    final pasos = crearPasosTutorial(loc.tutorialInteractivo.pasos);
    // Un respiro antes de arrancar: el feed ocupa media pantalla y el primer
    // objetivo del tutorial es su contenido. Sin esta espera el overlay sale
    // en el primer frame, cuando todavía no hay ningún objetivo montado.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _tutorialCtrl.inicializar(pasos);
  }

  Future<void> _provisionarSesionesAlArrancar() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final servicio = ServicioVerificacion();
    try {
      await servicio.provisionarSesionesFirmadas();
      await servicio.reintentarPendientesSilencioso();
    } catch (_) {}
  }

  void _navegarItem(BuildContext context, ItemFeed item) {
    final fuente = item.source ?? '';
    switch (item.type) {
      case 'album':
        abrirDetalleAlbum(
          context,
          id: item.id,
          fuente: fuente,
          coverUrl: item.coverUrl,
        );
      case 'playlist':
        abrirDetallePlaylist(
          context,
          id: item.id,
          nombre: item.name,
          fuente: fuente,
          coverUrl: item.coverUrl,
        );
      case 'artist':
        abrirDetalleArtista(
          context,
          id: item.id,
          nombre: item.name,
          fuente: fuente,
        );
      default:
        if (item.albumId != null && item.albumId!.isNotEmpty) {
          abrirDetalleAlbum(
            context,
            id: item.albumId!,
            fuente: fuente,
            coverUrl: item.coverUrl,
          );
        }
    }
  }

  void _abrirReproductor(BuildContext context) {
    Navigator.push(
      context,
      RutaDeslizarArriba(pagina: const ReproductorPagina()),
    );
  }

  @override
  void dispose() {
    ServicioCalidadRed.instancia.detener();
    _blocBusqueda.close();
    _blocFeed.close();
    _tutorialCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cola = sl<CubitCola>();
    final likes = sl<CubitLikes>();
    final descargas = sl<CubitDescargas>();
    final playlists = sl<CubitPlaylists>();
    final reproductor = sl<CubitReproductor>();

    return TutorialProvider(
      controller: _tutorialCtrl,
      // El host monta la capa del tutorial en el Overlay raíz (por encima
      // de los modales). No dibuja nada por sí solo.
      child: TutorialHost(
        controller: _tutorialCtrl,
        child: MultiBlocProvider(
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
            miEspacio: const PaginaMiEspacio(),
            miniPlayer: KeyedSubtree(
              key: keyTutorialMiniplayer,
              child: Miniplayer(
                onAbrirReproductor: () => _abrirReproductor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
