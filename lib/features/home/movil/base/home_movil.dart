// home_movil.dart — Shell de la Home para LAYOUT MÓVIL (celular/tablet
// vertical): PageView con las 3 secciones (Buscar, Inicio, Mi Espacio)
// animadas y mantenidas vivas, y miniplayer arriba de la navbar flotante.
// Recibe las páginas y el miniplayer como slots (seccion animada en
// home_movil_seccion.dart).
//
// La pestaña activa se lee y se escribe en el notificador compartido con el
// escritorio y la TV (ver ensamblador_home.dart), así volver a la Home cae
// donde el usuario estaba y no siempre en Inicio.

import 'package:flutter/material.dart';
import '../../../../shared/tema/colores_app.dart';
import '../../../../shared/utilidades/plataforma/pantalla/insets_sistema.dart';
import '../../../../shared/widgets/reproductor/base/marco_miniplayer.dart';
import '../../../../shared/widgets/fondos/ambiente/fondo_ambiente.dart';
import '../../../tutorial_interactivo/motor/base/tutorial_controller.dart';
import '../../shell/ensamblador_home.dart';
import '../../widgets/flotante/barra_navegacion_flotante.dart';

part '../piezas/home_movil_barra_inferior.dart';
part 'home_movil_seccion.dart';
part '../piezas/home_movil_tutorial.dart';

/// Shell móvil de la Home. [buscador]/[feed]/[miEspacio] son las 3
/// secciones del PageView; [miniPlayer] se posiciona sobre la navbar.
class HomeMovil extends StatefulWidget {
  final Widget buscador;
  final Widget feed;
  final Widget miEspacio;
  final Widget miniPlayer;

  const HomeMovil({
    super.key,
    required this.buscador,
    required this.feed,
    required this.miEspacio,
    required this.miniPlayer,
  });

  @override
  State<HomeMovil> createState() => _HomeMovilState();
}

class _HomeMovilState extends State<HomeMovil> {
  late final PageController _pageCtrl;
  late int _tab;

  /// Última pestaña que pidió el tutorial (para no re-animar en cada build).
  int? _pestanaTutorialAplicada;

  /// Pestaña donde estaba el usuario antes de que el tutorial lo moviera,
  /// para devolverlo ahí cuando el tutorial termine.
  int? _pestanaAntesDelTutorial;

  @override
  void initState() {
    super.initState();
    // Donde el usuario dejó la Home la última vez (Inicio la primera vez).
    _tab = pestanaHomeInicial();
    _pageCtrl = PageController(initialPage: _tab);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _alCambiarPagina(int i) {
    if (i == _tab) return;
    guardarPestanaHome(i);
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // El tutorial puede pedir una pestaña concreta para explicar lo que
    // vive en ella: se atiende antes de pintar el overlay.
    final tutorial = TutorialProvider.of(context);
    sincronizarPestanaTutorial(tutorial);

    return Scaffold(
      backgroundColor: isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro,
      // Fondo ambiente: el cover de la canción actual desenfocado detrás de
      // todo el shell (igual que el diseño anterior con AmbientBackdrop y el
      // tinte de los modals).
      body: FondoAmbienteConCola(
        // El inset de abajo NO se delega a SafeArea: lo reserva la barra
        // inferior (ver _BarraInferiorShell) para que el menú de navegación
        // del celular nunca tape el miniplayer ni la navbar.
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // PageView de secciones con animación de opacidad/escala. Cada
              // una se queda viva al salir de pantalla (ver _SeccionAnimada):
              // así la búsqueda, la pestaña y el scroll de una sección no se
              // reinician al ir a otra y volver.
              Positioned.fill(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: _alCambiarPagina,
                  children: [
                    _SeccionAnimada(
                      index: 0,
                      controller: _pageCtrl,
                      child: widget.buscador,
                    ),
                    _SeccionAnimada(
                      index: 1,
                      controller: _pageCtrl,
                      child: widget.feed,
                    ),
                    _SeccionAnimada(
                      index: 2,
                      controller: _pageCtrl,
                      child: widget.miEspacio,
                    ),
                  ],
                ),
              ),
              // Miniplayer + navbar flotante al pie.
              _BarraInferiorShell(
                miniPlayer: widget.miniPlayer,
                isDark: isDark,
                currentIndex: _tab,
                onTap: _onNavTap,
              ),
              // (El tutorial interactivo no va acá: lo monta TutorialHost
              // en el Overlay raíz, así queda también por encima de los
              // modales, como la hoja de ajustes.)
            ],
          ),
        ),
      ),
    );
  }
}
