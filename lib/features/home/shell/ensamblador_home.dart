// ─────────────────────────────────────────────────────────────
// ensamblador_home.dart — Ensamblador de la Home: crea los blocs
// de Búsqueda y Feed (con el backend Go), provee los cubits
// globales en el árbol y construye los 4 slots del shell —
// buscador (PaginaBusqueda), feed (PaginaFeed), miEspacio y
// miniplayer. El arranque (tutorial + sesiones + navegación de
// items) vive en home_arranque.dart.
// Se conecta con: busqueda_bloc + feed_bloc + cubits (cola, likes,
// descargas, playlists) + pagina_home + home_arranque.
// Parte del flujo: Home (ruta '/home' tras el splash/setup).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/inyeccion/inyeccion.dart';
import '../../../core/backend_go/nucleo/base/contrato_backend.dart';
import '../../../core/cache/almacenes/musica/cache_busqueda.dart';
import '../../../core/plataforma/red/servicio_calidad_red.dart';
import '../../../estado/cola/cubit_cola.dart';
import '../../../estado/descargas/cubit_descargas.dart';
import '../../../estado/like/base/cubit_like.dart';
import '../../../estado/playlists/cubit_playlists.dart';
import '../../../estado/reproductor/cubit_reproductor.dart';
import '../../../core/modelos/usuario/disenos/vistas/vista_app.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/base/comun/transiciones_pagina.dart';
import '../../../shared/widgets/reproductor/base/miniplayer.dart';
import '../../../shared/widgets/vista/base/diseno_de_vista.dart';
import '../../busqueda/bloc/base/busqueda_bloc.dart';
import '../../busqueda/pagina/base/pagina_busqueda.dart';
import '../../feed/bloc/feed_bloc.dart';
import '../../feed/bloc/feed_evento.dart';
import '../../feed/pagina/feed_pagina.dart';
import '../../mi_espacio/pagina/base/pagina_mi_espacio.dart';
import '../../reproductor/pagina/base/reproductor_pagina.dart';
import '../../tutorial_interactivo/motor/base/tutorial_claves.dart';
import '../../tutorial_interactivo/motor/base/tutorial_controller.dart';
import '../../tutorial_interactivo/motor/base/tutorial_host.dart';
import '../../tutorial_interactivo/motor/base/tutorial_provider.dart';
import 'home_arranque.dart';
import 'pagina_home.dart';

// El TutorialProvider vive en tutorial_provider.dart; se re-exporta para que
// quien lea la Home siga encontrándolo por este archivo.
export '../../tutorial_interactivo/motor/base/tutorial_provider.dart';

/// Cuántas secciones tiene la Home (Buscar, Inicio, Mi Espacio).
const int cantidadPestanasHome = 3;

/// Pestaña de la Home que el usuario dejó abierta (0=Buscar, 1=Inicio,
/// 2=Mi Espacio).
///
/// Vive en la inyección para que los TRES shells (celular, escritorio y TV)
/// coincidan: cambiar de sección en uno no deja a los otros desubicados. El
/// valor es por sesión: la primera vez se abre en Inicio, que es el centro.
int pestanaHomeInicial() {
  final n = sl<ValueNotifier<int>>().value;
  return n.clamp(0, cantidadPestanasHome - 1);
}

/// Guarda la pestaña activa de la Home (la llaman los shells al cambiar).
void guardarPestanaHome(int i) {
  sl<ValueNotifier<int>>().value = i.clamp(0, cantidadPestanasHome - 1);
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
    provisionarSesionesHome();
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
    armarTutorialHome(
      ctrl: _tutorialCtrl,
      loc: AppLocalizations.of(context),
      estaMontado: () => mounted,
    );
  }

  void _abrirReproductor(BuildContext context) {
    // El reproductor es su propia vista: puede tener un diseño distinto al del
    // resto de la app (Ajustes → Apariencia → Vistas).
    Navigator.push(
      context,
      RutaDeslizarArriba(
        pagina: const DisenoDeVista(
          vista: VistaApp.reproductor,
          child: ReproductorPagina(),
        ),
      ),
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
          // Cada slot es una VISTA: se envuelve acá y de ahí para adentro todo
          // —cards, grillas, separaciones— ya obedece al diseño que el usuario
          // le puso a esa vista en Ajustes → Apariencia → Vistas.
          child: PaginaHome(
            buscador: DisenoDeVista(
              vista: VistaApp.busqueda,
              child: PaginaBusqueda(
                onNavegarItem: (item) => navegarItemFeed(context, item),
              ),
            ),
            feed: DisenoDeVista(
              vista: VistaApp.feed,
              child: PaginaFeed(
                onNavegarItem: (item) => navegarItemFeed(context, item),
              ),
            ),
            miEspacio: const DisenoDeVista(
              vista: VistaApp.miEspacio,
              child: PaginaMiEspacio(),
            ),
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
