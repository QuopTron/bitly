// ─────────────────────────────────────────────────────────────
// home_tv.dart — Shell de la Home para TV.
//
// La tele no usa ni el navbar inferior del celular ni la barra lateral de la
// PC: se maneja con el control remoto, así que la navegación va ARRIBA, en
// ítems grandes (ícono + nombre) y con el activo bien marcado —en una tele no
// hay hover que avise dónde estás parado—. El contenido vive a pantalla
// completa en un IndexedStack (cada sección conserva su scroll) y el
// miniplayer es una barra ancha al pie.
//
// El lienzo lógico fijo y el puntero del control los pone el arranque (ver
// vista_tv); acá solo se decide cómo se ordena la pantalla en una tele.
//
// Se conecta con: pagina_home (selector) + home_tv_piezas + home_tv_tutorial.
// Parte del flujo: Home (variante TV).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cache/estado/estado_cola.dart';
import '../../../estado/cola/cubit_cola.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/widgets/fondos/ambiente/fondo_ambiente.dart';
import '../../../shared/widgets/reproductor/base/marco_miniplayer.dart';
import '../../tutorial_interactivo/motor/base/tutorial_controller.dart';
import '../shell/ensamblador_home.dart';

part 'home_tv_piezas.dart';
part 'home_tv_tutorial.dart';

/// Shell de TV de la Home: navegación arriba, contenido y miniplayer al pie.
class HomeTv extends StatefulWidget {
  final Widget buscador;
  final Widget feed;
  final Widget miEspacio;
  final Widget miniPlayer;

  const HomeTv({
    super.key,
    required this.buscador,
    required this.feed,
    required this.miEspacio,
    required this.miniPlayer,
  });

  @override
  State<HomeTv> createState() => _HomeTvState();
}

class _HomeTvState extends State<HomeTv> with SingleTickerProviderStateMixin {
  /// Sección abierta: sale del notificador compartido con los otros shells
  /// (ver `pestanaHomeInicial` en ensamblador_home.dart).
  late int _tab;

  /// Última pestaña que pidió el tutorial (para no repetir el cambio).
  int? _pestanaTutorialAplicada;

  /// Pestaña donde estaba el usuario antes del tutorial, para devolverlo.
  int? _pestanaAntesDelTutorial;

  // Transición entre secciones: fade + micro-slide, igual que en PC.
  late final AnimationController _transicion;
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desplazamiento;

  @override
  void initState() {
    super.initState();
    _tab = pestanaHomeInicial();
    _transicion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    )..forward();
    final curva = CurvedAnimation(
      parent: _transicion,
      curve: Curves.easeOutCubic,
    );
    _opacidad = curva;
    _desplazamiento = Tween<Offset>(
      begin: const Offset(0, 0.014),
      end: Offset.zero,
    ).animate(curva);
  }

  void _cambiarTab(int i) {
    if (i == _tab) return;
    guardarPestanaHome(i);
    setState(() => _tab = i);
    _transicion.forward(from: 0);
  }

  @override
  void dispose() {
    _transicion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // El tutorial puede pedir una sección concreta: se atiende antes de pintar
    // el overlay, para que el paso explique algo que ya se ve.
    final tutorial = TutorialProvider.of(context);
    sincronizarPestanaTutorial(tutorial);

    return Scaffold(
      backgroundColor: isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro,
      body: FondoAmbienteConCola(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _NavSuperiorTv(
                isDark: isDark,
                currentIndex: _tab,
                onTap: _cambiarTab,
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _opacidad,
                  child: SlideTransition(
                    position: _desplazamiento,
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        widget.buscador,
                        widget.feed,
                        widget.miEspacio,
                      ],
                    ),
                  ),
                ),
              ),
              _MiniplayerTv(miniPlayer: widget.miniPlayer),
            ],
          ),
        ),
      ),
    );
  }
}
