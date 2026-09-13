// ─────────────────────────────────────────────────────────────
// home_movil_seccion.dart — PART de home_movil.dart: envuelve cada
// sección del PageView móvil con animación sutil de opacidad y
// escala según su distancia a la página visible (efecto de
// profundidad al deslizar entre Buscar/Inicio/Mi Espacio).
// Se conecta con: home_movil.dart (misma library).
// Parte del flujo: Home (variante móvil, PageView animado).
// ─────────────────────────────────────────────────────────────

part of 'home_movil.dart';

/// Envuelve una sección del PageView con opacidad + escala dinámicas.
class _SeccionAnimada extends StatelessWidget {
  final int index;
  final PageController controller;
  final Widget child;

  const _SeccionAnimada({
    required this.index,
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final page = controller.hasClients
            ? (controller.page ?? index.toDouble())
            : index.toDouble();
        final diff = (page - index).abs();
        final opacity = (1.0 - diff * 0.4).clamp(0.0, 1.0);
        final scale = (1.0 - diff * 0.05).clamp(0.9, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}