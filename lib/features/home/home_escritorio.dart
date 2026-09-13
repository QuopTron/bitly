// ─────────────────────────────────────────────────────────────
// home_escritorio.dart — Shell de la Home para LAYOUT DE
// ESCRITORIO (PC/web/pantallas anchas): barra lateral fija de
// navegación a la izquierda y un panel de contenido central que
// muestra la sección activa (Buscar, Inicio o Mi Espacio) sin
// PageView — cada sección persiste viva y se alterna con
// IndexedStack. Cambiar de sección anima un fade + micro-slide
// (SOLO escritorio; el móvil mantiene su navbar + PageView).
// El miniplayer se posiciona al pie del panel como tarjeta
// flotante con sombra (variante de escritorio).
// Recibe las páginas y el miniplayer como slots.
// Se conecta con: pagina_home (selector) + barra_navegacion_lateral
// + shared (tema, cubit de cola para el miniplayer).
// Parte del flujo: Home (variante escritorio).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cache/estado/estado_cola.dart';
import '../../estado/cola/cubit_cola.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/widgets/fondos/fondo_ambiente.dart';
import '../tutorial_interactivo/tutorial_controller.dart';
import 'ensamblador_home.dart';
import 'widgets/barra_navegacion_lateral.dart';

part 'home_escritorio_tutorial.dart';

/// Shell de escritorio de la Home: sidebar + panel de contenido.
class HomeEscritorio extends StatefulWidget {
  final Widget buscador;
  final Widget feed;
  final Widget miEspacio;
  final Widget miniPlayer;

  const HomeEscritorio({
    super.key,
    required this.buscador,
    required this.feed,
    required this.miEspacio,
    required this.miniPlayer,
  });

  @override
  State<HomeEscritorio> createState() => _HomeEscritorioState();
}

class _HomeEscritorioState extends State<HomeEscritorio>
    with SingleTickerProviderStateMixin {
  int _tab = 1; // Inicio por defecto.

  /// Última pestaña que pidió el tutorial (para no repetir el cambio).
  int? _pestanaTutorialAplicada;

  /// Pestaña donde estaba el usuario antes del tutorial, para devolverlo.
  int? _pestanaAntesDelTutorial;

  // Transición de sección: fade + micro-slide. Sin keys: el IndexedStack
  // conserva el State de cada sección (scroll, búsqueda, etc.).
  late final AnimationController _transicion;
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desplazamiento;

  @override
  void initState() {
    super.initState();
    _transicion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      // Entrada inicial de la Home (fade-in suave al montar el shell).
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
    // El tutorial puede pedir una sección concreta: se atiende antes de
    // pintar el overlay, para que el paso explique algo ya visible.
    final tutorial = TutorialProvider.of(context);
    sincronizarPestanaTutorial(tutorial);

    return Scaffold(
      backgroundColor: isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro,
      body: FondoAmbienteConCola(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BarraNavegacionLateral(
                  isDark: isDark,
                  currentIndex: _tab,
                  onTap: _cambiarTab,
                ),
                Expanded(
                  child: Column(
                    children: [
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
                      _MiniplayerEscritorio(miniPlayer: widget.miniPlayer),
                    ],
                  ),
                ),
              ],
            ),
            // (El tutorial interactivo lo monta TutorialHost en el Overlay
            // raíz, así queda por encima de los modales.)
          ],
        ),
      ),
    );
  }
}

/// Miniplayer en su variante de escritorio: tarjeta flotante con sombra y
/// esquinas redondeadas (en móvil queda como barra pegada al borde). Se
/// oculta entero cuando no hay track actual (el miniplayer interno devuelve
/// un SizedBox.shrink, pero la tarjeta no debe dejar una sombra vacía).
class _MiniplayerEscritorio extends StatelessWidget {
  final Widget miniPlayer;

  const _MiniplayerEscritorio({required this.miniPlayer});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CubitCola, EstadoCola>(
      buildWhen:
          (prev, curr) =>
              prev.tieneActual != curr.tieneActual ||
              prev.actual?.id != curr.actual?.id,
      builder: (context, cola) {
        if (!cola.tieneActual) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: esOscuro ? 0.45 : 0.14),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: miniPlayer,
            ),
          ),
        );
      },
    );
  }
}
