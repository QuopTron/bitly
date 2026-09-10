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

import '../../core/cache/estado_cola.dart';
import '../../estado/cubit_cola.dart';
import '../../shared/tema/colores_app.dart';
import '../../shared/widgets/fondo_ambiente.dart';
import 'widgets/barra_navegacion_lateral.dart';

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

    return Scaffold(
      backgroundColor: isDark ? ColoresApp.fondoOscuro : ColoresApp.fondoClaro,
      // Fondo ambiente: cover de la canción actual desenfocado detrás del
      // panel central (la sidebar es opaca y queda al frente).
      body: FondoAmbienteConCola(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra lateral de navegación fija.
            BarraNavegacionLateral(
              isDark: isDark,
              currentIndex: _tab,
              onTap: _cambiarTab,
            ),
            // Panel central: sección activa + miniplayer al pie.
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    // Fade + slide al cambiar de sección (state conservado).
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
      buildWhen: (prev, curr) =>
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