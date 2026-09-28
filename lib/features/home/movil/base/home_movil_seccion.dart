// ─────────────────────────────────────────────────────────────
// home_movil_seccion.dart — PART de home_movil.dart: envuelve cada
// sección del PageView móvil con animación sutil de opacidad y
// escala según su distancia a la página visible (efecto de
// profundidad al deslizar entre Buscar/Inicio/Mi Espacio) y la
// MANTIENE VIVA cuando sale de pantalla.
// Por qué el keep-alive: PageView descarta lo que deja de verse, así que
// volver a una sección la reconstruía de cero — la búsqueda escrita en Mi
// Espacio, la pestaña abierta y el scroll se perdían al ir a Buscar y volver.
// El escritorio y la TV no tenían el problema porque usan IndexedStack (que
// deja las tres montadas); esto empareja el celular con ellos.
// Se conecta con: home_movil.dart (misma library).
// Parte del flujo: Home (variante móvil, PageView animado).
// ─────────────────────────────────────────────────────────────

part of 'home_movil.dart';

/// Envuelve una sección del PageView con opacidad + escala dinámicas.
///
/// Es `StatefulWidget` (y no un builder suelto) por el keep-alive: el mixin
/// pide que lo dejen vivo mientras la sección está fuera de pantalla, que es
/// justo lo que necesita para no perder lo que el usuario tenía ahí.
class _SeccionAnimada extends StatefulWidget {
  final int index;
  final PageController controller;
  final Widget child;

  const _SeccionAnimada({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  State<_SeccionAnimada> createState() => _SeccionAnimadaState();
}

class _SeccionAnimadaState extends State<_SeccionAnimada>
    with AutomaticKeepAliveClientMixin {
  /// El envoltorio ya construido y el child que envolvía. Se reusa mientras el
  /// deslizamiento no cambie nada visible: el PageView notifica en CADA frame
  /// del gesto, y sin esto las tres secciones se reconstruían por frame
  /// (incluidas las que están fuera de pantalla). Devolver la misma instancia
  /// hace que Flutter corte ahí y no vuelva a bajar al subárbol.
  Widget? _pintado;
  Widget? _childPintado;

  /// Últimos valores pintados, para saber si el frame cambió algo.
  double _opacidad = 1;
  double _escala = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Obligatorio del mixin: avisa al padre que hay que mantener vivo esto.
    super.build(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final ctrl = widget.controller;
        final page =
            ctrl.hasClients
                ? (ctrl.page ?? widget.index.toDouble())
                : widget.index.toDouble();
        final diff = (page - widget.index).abs();
        final opacidad = (1.0 - diff * 0.4).clamp(0.0, 1.0);
        final escala = (1.0 - diff * 0.05).clamp(0.9, 1.0);

        // Mismo child y cambio por debajo del medio por mil: no hay nada nuevo
        // que pintar (el gesto avanza en pasos mucho más chicos que eso).
        if (_pintado != null &&
            identical(_childPintado, child) &&
            (opacidad - _opacidad).abs() < 0.004 &&
            (escala - _escala).abs() < 0.004) {
          return _pintado!;
        }

        _opacidad = opacidad;
        _escala = escala;
        _childPintado = child;
        return _pintado = Opacity(
          opacity: opacidad,
          child: Transform.scale(scale: escala, child: child),
        );
      },
      child: widget.child,
    );
  }
}
